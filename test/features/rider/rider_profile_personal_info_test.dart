// EcoXchange Mobile — Rider Profile's Personal Information editing entry
// point. Real widgets pumped against faked repositories — no HTTP/Dio call
// ever happens. Critically also proves the NEGATIVE requirement: "Vehicle &
// Assignment" never gets an Edit action, even though it shares the same
// generic info-sheet styling as Personal Information.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/data/models/user_model.dart';
import 'package:ecoxchange_mobile/features/auth/data/profile_repository.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_profile.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_profile_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/providers/rider_profile_provider.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/screens/rider_profile_screen.dart';

RiderProfile _riderProfile({String name = 'Razif Azrul bin Abdullah'}) => RiderProfile(
      id: 7,
      name: name,
      email: 'rider@ecoxchange.com',
      phoneNumber: '+60129876543',
      profilePhotoUrl: null,
      riderType: 'dedicated',
      vehicleType: 'motorcycle',
      vehiclePlateNo: 'WA 1234',
      riderStatus: 'available',
      coverageZone: 'Subang Jaya',
      workingRadiusKm: 15.0,
      centreName: 'EcoGreen Subang Jaya',
      totalCompleted: 3,
      completedThisMonth: 0,
      totalWeightKg: 22.2,
    );

class _FakeRiderProfileRepository extends RiderProfileRepository {
  _FakeRiderProfileRepository(this.profile) : super(ApiClient());

  RiderProfile profile;
  int calls = 0;

  @override
  Future<RiderProfile> getProfile() async {
    calls++;
    return profile;
  }
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository() : super(ApiClient());

  int updateCalls = 0;

  @override
  Future<UserModel> updateProfile({required String name, required String email, String? phoneNumber}) async {
    updateCalls++;
    return UserModel(id: 7, name: name, email: email, role: 'rider', phoneNumber: phoneNumber, profilePhotoUrl: null);
  }
}

Future<void> _pumpRiderProfile(WidgetTester tester, {required _FakeRiderProfileRepository riderRepo, ProfileRepository? profileRepository}) async {
  final auth = AuthProvider(authRepository: AuthRepository(apiClient: ApiClient(), tokenStorage: TokenStorage()));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => RiderProfileProvider(riderRepo)),
        Provider<ProfileRepository>.value(value: profileRepository ?? _FakeProfileRepository()),
      ],
      child: const MaterialApp(home: Scaffold(body: RiderProfileScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Personal Information sheet offers an Edit Profile action', (tester) async {
    await _pumpRiderProfile(tester, riderRepo: _FakeRiderProfileRepository(_riderProfile()));

    await tester.tap(find.byKey(const Key('rider-profile-personal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rider-profile-edit-personal-info')), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  // The explicit negative requirement: rider_type/vehicle/plate/centre/
  // coverage/working-radius/rider_status must stay strictly read-only.
  testWidgets('the Vehicle & Assignment sheet never offers an edit action', (tester) async {
    await _pumpRiderProfile(tester, riderRepo: _FakeRiderProfileRepository(_riderProfile()));

    await tester.tap(find.byKey(const Key('rider-profile-vehicle-info')));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle & Assignment'), findsWidgets); // the menu row + the sheet's own title
    expect(find.text('Edit Profile'), findsNothing);
    expect(find.byKey(const Key('rider-profile-edit-personal-info')), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('Edit Profile opens the edit screen pre-filled with the current rider', (tester) async {
    await _pumpRiderProfile(tester, riderRepo: _FakeRiderProfileRepository(_riderProfile()));

    await tester.tap(find.byKey(const Key('rider-profile-personal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rider-profile-edit-personal-info')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Razif Azrul bin Abdullah'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'rider@ecoxchange.com'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '+60129876543'), findsOneWidget);
  });

  testWidgets('saving refreshes the rider profile from the server', (tester) async {
    final riderRepo = _FakeRiderProfileRepository(_riderProfile());
    final profileRepo = _FakeProfileRepository();
    await _pumpRiderProfile(tester, riderRepo: riderRepo, profileRepository: profileRepo);

    final callsBeforeSave = riderRepo.calls;

    await tester.tap(find.byKey(const Key('rider-profile-personal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rider-profile-edit-personal-info')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit-info-name')), 'Razif Updated');
    await tester.tap(find.byKey(const Key('edit-info-save')));
    await tester.pumpAndSettle();

    expect(profileRepo.updateCalls, 1);
    // refresh() re-fetched GET /rider/profile after the save.
    expect(riderRepo.calls, greaterThan(callsBeforeSave));
    expect(find.text('Profile updated.'), findsOneWidget);
  });
}
