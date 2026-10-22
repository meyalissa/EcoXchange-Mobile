// EcoXchange Mobile — splash screen rendering (logo size + tagline +
// small-screen overflow check).
//
// flutter_secure_storage talks to the platform over a MethodChannel that
// doesn't exist in the widget-test environment — mocked here exactly like
// test/widget_test.dart does, so AuthProvider.bootstrap() (fired from
// SplashScreen.initState) resolves instead of hanging.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/splash_screen.dart';

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

  Widget wrap(AuthProvider auth) => ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: SplashScreen()),
      );

  testWidgets('shows the official logo image, the tagline, and a spinner', (tester) async {
    final auth = buildAuthProvider();

    await tester.pumpWidget(wrap(auth));
    // One pump only -- bootstrap() is still in flight, which is exactly
    // the state this screen exists to cover; pumpAndSettle() here would
    // run past it to whatever AppRouter swaps in next.
    await tester.pump();

    expect(find.image(const AssetImage('assets/branding/splash_logo.png')), findsOneWidget);
    expect(find.text('Recycle Smarter. Earn Rewards.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('does not duplicate the tagline (only one instance)', (tester) async {
    final auth = buildAuthProvider();

    await tester.pumpWidget(wrap(auth));
    await tester.pump();

    expect(find.text('Recycle Smarter. Earn Rewards.'), findsOneWidget);
  });

  testWidgets('renders without overflow on a small phone screen', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // A genuinely small phone — e.g. an older/compact Android device —
    // smaller than this app's usual test/dev targets.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;

    final auth = buildAuthProvider();

    await tester.pumpWidget(wrap(auth));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.image(const AssetImage('assets/branding/splash_logo.png')), findsOneWidget);
  });

  testWidgets('renders without overflow on a large tablet-ish screen', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;

    final auth = buildAuthProvider();

    await tester.pumpWidget(wrap(auth));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
