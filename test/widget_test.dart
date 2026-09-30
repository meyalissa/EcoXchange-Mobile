// EcoXchange Mobile — foundation smoke test.
//
// Verifies the app boots to the login screen (no stored token → no
// network call needed to reach this state) and that the login form's
// client-side validation rejects an empty submission. Deeper auth-flow
// testing (real API calls) is done via live verification against the
// actual Laravel server — see the Phase 4C.1 report.
//
// flutter_secure_storage talks to the platform over a MethodChannel that
// doesn't exist in the widget-test environment — mocked here to always
// report "no token stored", which is what a fresh install genuinely has.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/app/app.dart';
import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';

void main() {
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      null,
    );
  });

  AuthProvider buildAuthProvider() {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authRepository = AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
    return AuthProvider(authRepository: authRepository);
  }

  testWidgets('shows the login form with no accidental role selector', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    // Login's hero restyle (Phase 4C.3) renders the brand mark in caps.
    expect(find.text('ECOXCHANGE'), findsWidgets);
    expect(find.text('Log In'), findsOneWidget);
    // The role must come from the server, never a client-side picker.
    expect(find.text('I am a Customer'), findsNothing);
    expect(find.text('I am a Rider'), findsNothing);
  });

  testWidgets('rejects an empty submission without calling the API', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
