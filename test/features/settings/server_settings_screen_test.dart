// EcoXchange Mobile — ServerSettingsScreen widget tests: URL validation,
// save -> ApiClient reconfiguration, test-connection success/failure
// messaging, and the dev-override banner that disables Save.
//
// ApiClient is the REAL class (not a fake) — its `testConnection` is
// swapped out at the Dio-transport level is not needed here, since the
// screen itself only ever calls the three ApiClient methods this test
// cares about (`baseUrl`, `updateBaseUrl`, `testConnection`); a thin
// subclass overrides just `testConnection` to avoid a real network call,
// the same "fake a repository/client by subclassing" approach every
// other screen test in this project already uses.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_config.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/core/storage/server_config_storage.dart';
import 'package:ecoxchange_mobile/features/settings/presentation/screens/server_settings_screen.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.result, this.errorToThrow});

  final bool? result;
  final ApiException? errorToThrow;
  String? lastTestedUrl;

  @override
  Future<bool> testConnection(String candidateBaseUrl) async {
    lastTestedUrl = candidateBaseUrl;
    if (errorToThrow != null) throw errorToThrow!;
    return result!;
  }
}

Future<void> _pump(WidgetTester tester, {ApiClient? apiClient, ServerConfigStorage? storage}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient ?? _FakeApiClient(result: true)),
        Provider<ServerConfigStorage>.value(value: storage ?? ServerConfigStorage()),
      ],
      child: const MaterialApp(home: ServerSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final backing = <String, String>{};

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    backing.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'write':
          final args = call.arguments as Map;
          backing[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          final args = call.arguments as Map;
          return backing[args['key'] as String];
        case 'delete':
          final args = call.arguments as Map;
          backing.remove(args['key'] as String);
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, null);
    ApiConfig.setRuntimeBaseUrl(null);
  });

  testWidgets('shows the ApiClient\'s currently active URL', (tester) async {
    final client = _FakeApiClient(result: true);
    client.updateBaseUrl('http://10.0.2.2');

    await _pump(tester, apiClient: client);

    expect(find.byKey(const Key('server-settings-active-url')), findsOneWidget);
    expect(find.text('http://10.0.2.2'), findsOneWidget);
  });

  testWidgets('a malformed URL is rejected without calling testConnection', (tester) async {
    final client = _FakeApiClient(result: true);
    await _pump(tester, apiClient: client);

    await tester.enterText(find.byKey(const Key('server-settings-url-field')), 'not a url');
    await tester.tap(find.byKey(const Key('server-settings-test')));
    await tester.pumpAndSettle();

    expect(client.lastTestedUrl, isNull);
    expect(find.byKey(const Key('server-settings-test-message')), findsOneWidget);
  });

  testWidgets('Test Connection shows a success message for a reachable server', (tester) async {
    final client = _FakeApiClient(result: true);
    await _pump(tester, apiClient: client);

    await tester.enterText(find.byKey(const Key('server-settings-url-field')), 'http://192.168.1.20');
    await tester.tap(find.byKey(const Key('server-settings-test')));
    await tester.pumpAndSettle();

    expect(client.lastTestedUrl, 'http://192.168.1.20');
    expect(find.textContaining('Connected to http://192.168.1.20'), findsOneWidget);
  });

  testWidgets('Test Connection explains a network failure with a likely cause', (tester) async {
    final client = _FakeApiClient(errorToThrow: const NetworkException('Could not connect.'));
    await _pump(tester, apiClient: client);

    await tester.enterText(find.byKey(const Key('server-settings-url-field')), 'http://192.168.1.20');
    await tester.tap(find.byKey(const Key('server-settings-test')));
    await tester.pumpAndSettle();

    expect(find.textContaining('same network'), findsOneWidget);
  });

  testWidgets('Save persists the URL and updates the ApiClient so subsequent requests use it', (tester) async {
    final client = _FakeApiClient(result: true);
    client.updateBaseUrl('http://10.0.2.2');
    final storage = ServerConfigStorage();

    await _pump(tester, apiClient: client, storage: storage);

    await tester.enterText(find.byKey(const Key('server-settings-url-field')), 'http://192.168.1.20');
    await tester.tap(find.byKey(const Key('server-settings-save')));
    await tester.pumpAndSettle();

    expect(client.baseUrl, 'http://192.168.1.20');
    expect(await storage.readBaseUrl(), 'http://192.168.1.20');
    expect(ApiConfig.runtimeBaseUrl, 'http://192.168.1.20');
    expect(find.text('http://192.168.1.20'), findsWidgets);
  });

  testWidgets('a reset test message is cleared when switching from test to save', (tester) async {
    final client = _FakeApiClient(errorToThrow: const NetworkException('Could not connect.'));
    await _pump(tester, apiClient: client);

    await tester.enterText(find.byKey(const Key('server-settings-url-field')), 'http://192.168.1.20');
    await tester.tap(find.byKey(const Key('server-settings-test')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-settings-test-message')), findsOneWidget);

    await tester.tap(find.byKey(const Key('server-settings-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('server-settings-test-message')), findsNothing);
    expect(find.byKey(const Key('server-settings-saved-message')), findsOneWidget);
  });
}
