// EcoXchange Mobile — EditPersonalInfoScreen widget tests. Real widgets
// pumped against a faked ProfileRepository (same convention as every other
// widget test in this project — no HTTP/Dio call ever happens). Pushed via
// a real Navigator (not just pumped as `home`) so the pop-on-success
// behaviour is genuinely exercised, not assumed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/data/models/user_model.dart';
import 'package:ecoxchange_mobile/features/auth/data/profile_repository.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/screens/edit_personal_info_screen.dart';

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository({this.updateResult, this.updateError}) : super(ApiClient());

  final UserModel? updateResult;
  final ApiException? updateError;
  int updateCalls = 0;

  @override
  Future<UserModel> updateProfile({required String name, required String email, String? phoneNumber}) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    return updateResult!;
  }
}

Future<void> _pumpPushed(WidgetTester tester, {required ProfileRepository repository, required AuthProvider auth}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProfileRepository>.value(value: repository),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                child: const Text('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditPersonalInfoScreen(
                      initialName: 'Nurul Aisyah binti Ahmad',
                      initialEmail: 'customer@ecoxchange.com',
                      initialPhoneNumber: '+60129876543',
                      initialPhotoUrl: null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  AuthProvider authProvider() => AuthProvider(authRepository: AuthRepository(apiClient: ApiClient(), tokenStorage: TokenStorage()));

  testWidgets('loads current data into the editable fields', (tester) async {
    await _pumpPushed(tester, repository: _FakeProfileRepository(), auth: authProvider());

    expect(find.widgetWithText(TextFormField, 'Nurul Aisyah binti Ahmad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'customer@ecoxchange.com'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '+60129876543'), findsOneWidget);
  });

  testWidgets('fields can be edited', (tester) async {
    await _pumpPushed(tester, repository: _FakeProfileRepository(), auth: authProvider());

    await tester.enterText(find.byKey(const Key('edit-info-name')), 'New Name');
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'New Name'), findsOneWidget);
  });

  testWidgets('save calls the repository and returns to the previous screen on success', (tester) async {
    final updated = const UserModel(
      id: 20, name: 'New Name', email: 'customer@ecoxchange.com', role: 'customer', phoneNumber: '+60129876543', profilePhotoUrl: null,
    );
    final repo = _FakeProfileRepository(updateResult: updated);
    final auth = authProvider();

    await _pumpPushed(tester, repository: repo, auth: auth);

    await tester.enterText(find.byKey(const Key('edit-info-name')), 'New Name');
    await tester.tap(find.byKey(const Key('edit-info-save')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(auth.user, same(updated));
    // Popped back to the screen that pushed it.
    expect(find.text('open'), findsOneWidget);
    expect(find.byKey(const Key('edit-info-save')), findsNothing);
  });

  testWidgets('a server validation error is shown and the screen stays open', (tester) async {
    const error = ValidationException('The email has already been taken.', {'email': ['The email has already been taken.']});
    final repo = _FakeProfileRepository(updateError: error);

    await _pumpPushed(tester, repository: repo, auth: authProvider());
    await tester.tap(find.byKey(const Key('edit-info-save')));
    await tester.pumpAndSettle();

    expect(find.text('The email has already been taken.'), findsOneWidget);
    // Still on the edit screen -- never popped on failure.
    expect(find.byKey(const Key('edit-info-save')), findsOneWidget);
  });

  testWidgets('an empty name is rejected locally without calling the repository', (tester) async {
    final repo = _FakeProfileRepository();
    await _pumpPushed(tester, repository: repo, auth: authProvider());

    await tester.enterText(find.byKey(const Key('edit-info-name')), '   ');
    await tester.tap(find.byKey(const Key('edit-info-save')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 0);
    expect(find.byKey(const Key('edit-info-save')), findsOneWidget); // still open
  });

  testWidgets('the photo picker option sheet is reachable', (tester) async {
    await _pumpPushed(tester, repository: _FakeProfileRepository(), auth: authProvider());

    await tester.tap(find.byKey(const Key('edit-info-photo-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-info-photo-camera')), findsOneWidget);
    expect(find.byKey(const Key('edit-info-photo-gallery')), findsOneWidget);
  });
}
