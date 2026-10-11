// EcoXchange Mobile — Customer Profile's Personal Information editing
// entry point. Real widgets pumped against faked repositories — no HTTP/
// Dio call ever happens, and `image_picker`'s platform channel is never
// touched (only the Edit button + navigation + pre-fill are exercised
// here; the save/photo-upload logic itself is covered by
// edit_personal_info_provider_test.dart / edit_personal_info_screen_test.dart).

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
import 'package:ecoxchange_mobile/features/customer/data/models/dashboard_data.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/dashboard_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/customer_profile_screen.dart';

class _FailingDashboardRepository extends CustomerDashboardRepository {
  _FailingDashboardRepository() : super(ApiClient());

  @override
  Future<DashboardData> getDashboard() async => throw const NetworkException('offline');
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository() : super(ApiClient());

  int updateCalls = 0;

  @override
  Future<UserModel> updateProfile({required String name, required String email, String? phoneNumber}) async {
    updateCalls++;
    return UserModel(id: 20, name: name, email: email, role: 'customer', phoneNumber: phoneNumber, profilePhotoUrl: null);
  }
}

Future<AuthProvider> _pumpProfile(WidgetTester tester, {ProfileRepository? profileRepository}) async {
  final auth = AuthProvider(authRepository: AuthRepository(apiClient: ApiClient(), tokenStorage: TokenStorage()));
  auth.applyUpdatedUser(const UserModel(
    id: 20, name: 'Nurul Aisyah binti Ahmad', email: 'customer@ecoxchange.com', role: 'customer', phoneNumber: '+60129876543', profilePhotoUrl: null,
  ));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => DashboardProvider(_FailingDashboardRepository())),
        Provider<ProfileRepository>.value(value: profileRepository ?? _FakeProfileRepository()),
      ],
      child: const MaterialApp(home: Scaffold(body: CustomerProfileScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('the Personal Information sheet offers an Edit Profile action', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-edit-personal-info')), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  testWidgets('Edit Profile opens the edit screen pre-filled with the current user', (tester) async {
    await _pumpProfile(tester);

    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-edit-personal-info')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Nurul Aisyah binti Ahmad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'customer@ecoxchange.com'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '+60129876543'), findsOneWidget);
  });

  testWidgets('saving a change updates the header name immediately', (tester) async {
    final repo = _FakeProfileRepository();
    final auth = await _pumpProfile(tester, profileRepository: repo);

    expect(find.text('Nurul Aisyah binti Ahmad'), findsOneWidget);

    await tester.tap(find.text('Personal Information'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-edit-personal-info')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit-info-name')), 'Aisyah Updated');
    await tester.tap(find.byKey(const Key('edit-info-save')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(auth.user?.name, 'Aisyah Updated');
    // Back on the profile screen, header reflects the change immediately.
    expect(find.text('Aisyah Updated'), findsOneWidget);
    expect(find.text('Profile updated.'), findsOneWidget);
  });
}
