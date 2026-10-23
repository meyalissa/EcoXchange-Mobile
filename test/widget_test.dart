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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ecoxchange_mobile/app/app.dart';
import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/login_screen.dart' show launchUrlImpl;

void main() {
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
    // url_launcher's real Android implementation sends Pigeon-encoded
    // platform messages with no handler registered in this environment,
    // which hangs rather than throwing/returning — see launchUrlImpl's
    // own docblock. Always reports failure here, exactly like a device
    // with no browser available would, so the Forgot-Password/Create-
    // account tests can exercise the real fallback SnackBar deterministically.
    launchUrlImpl = (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async => false;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      null,
    );
    launchUrlImpl = launchUrl;
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

    // Login's hero header renders the official logo asset (transparent PNG
    // with the "EcoXchange" wordmark baked in) rather than a text brand mark.
    expect(find.image(const AssetImage('assets/branding/splash_logo.png')), findsOneWidget);
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

  // ── Redesign pass additions ─────────────────────────────────────────────

  testWidgets('password visibility toggle shows and hides the password', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('Forgot Password link opens the real website page (and reports failure honestly if it cannot)', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    // launchUrlImpl is mocked to always report failure (see setUp) -- this
    // pins that a genuinely failed launch is surfaced to the user, never
    // silently swallowed.
    expect(find.text('Could not open the browser on this device.'), findsOneWidget);
  });

  testWidgets('Create account link opens the real website page (and reports failure honestly if it cannot)', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    // The taller header (full logo artwork) pushes this link below the
    // small 600-logical-pixel-tall test viewport -- scroll it into view
    // first, same as this suite already does elsewhere for off-screen taps.
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the browser on this device.'), findsOneWidget);
  });

  testWidgets('Forgot Password requests the real website forgot-password URL and shows no error on success', (tester) async {
    Uri? requestedUri;
    launchUrlImpl = (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
      requestedUri = url;
      return true;
    };
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(requestedUri?.path, '/forgot-password');
    expect(find.text('Could not open the browser on this device.'), findsNothing);
  });

  testWidgets('no Google sign-in button is present (google_sign_in is not an implemented dependency)', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Google', findRichText: true), findsNothing);
  });

  testWidgets('the form is inside a scrollable so the keyboard never permanently hides the submit button', (tester) async {
    final authProvider = buildAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: authProvider, child: const EcoXchangeApp()),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(of: find.text('Log In'), matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
  });
}
