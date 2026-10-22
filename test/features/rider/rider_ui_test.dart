// EcoXchange Mobile — Rider Phase R1 widget tests: role routing through the
// real EcoXchangeApp, and the Rider shell's dashboard/pickups/detail/profile
// states (loading, error, empty, data). Repositories are faked by
// subclassing the real ones (test-only); flutter_secure_storage's channel is
// mocked because logout goes through the real TokenStorage.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/app/app.dart';
import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/data/models/user_model.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/dashboard_data.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_summary.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/reward_transaction.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_reward_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/customer_home_screen.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/login_screen.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_dashboard.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_detail.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_pickup_summary.dart';
import 'package:ecoxchange_mobile/features/rider/data/models/rider_profile.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_location_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/rider/data/repositories/rider_profile_repository.dart';
import 'package:ecoxchange_mobile/features/rider/presentation/rider_home_screen.dart';

import '../../fixtures/rider_fixtures.dart';

// ── auth ────────────────────────────────────────────────────────────────────

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.user, TokenStorage storage) : super(apiClient: ApiClient(tokenStorage: storage), tokenStorage: storage);

  final UserModel user;

  @override
  Future<UserModel> login({required String email, required String password}) async => user;

  @override
  Future<void> logout() async {}
}

UserModel _user(String role) => UserModel(
      id: 7,
      name: role == 'rider' ? 'Ahmad Farhan' : 'Test $role',
      email: '$role@example.com',
      role: role,
      phoneNumber: null,
      profilePhotoUrl: null,
      riderProfile: role == 'rider'
          ? const RiderProfileSummary(riderType: 'dedicated', vehicleType: 'motorcycle', riderStatus: 'available')
          : null,
    );

Future<AuthProvider> _signedIn(String role) async {
  final storage = TokenStorage();
  final auth = AuthProvider(authRepository: _FakeAuthRepository(_user(role), storage));
  await auth.login(email: '$role@example.com', password: 'irrelevant-in-tests');
  return auth;
}

// ── rider repositories (test-only fakes) ────────────────────────────────────

class _DashboardRepo extends RiderDashboardRepository {
  _DashboardRepo({this.json, this.error, this.pending}) : super(ApiClient());
  Map<String, dynamic>? json;
  ApiException? error;
  final Completer<RiderDashboard>? pending;
  int calls = 0;
  @override
  Future<RiderDashboard> getDashboard() async {
    calls++;
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return RiderDashboard.fromJson(json!);
  }
}

class _PickupRepo extends RiderPickupRepository {
  _PickupRepo({this.list = const [], this.detailError}) : super(ApiClient());
  final List<Map<String, dynamic>> list;
  final ApiException? detailError;
  final List<int> detailCalls = [];
  @override
  Future<({List<RiderPickupSummary> pickups, Pagination pagination})> getPickups({String? status, int page = 1}) async {
    // Like the API: filtered by the PICKUP status.
    final matching = list.where((p) => status == null || p['status'] == status).toList();
    return (
      pickups: matching.map(RiderPickupSummary.fromJson).toList(),
      pagination: Pagination.fromJson(paginationJson(total: matching.length)),
    );
  }
  @override
  Future<RiderPickupDetail> getPickupDetail(int id) async {
    detailCalls.add(id);
    if (detailError != null) throw detailError!;
    return RiderPickupDetail.fromJson(riderPickupDetailJson(id: id));
  }
}

class _ProfileRepo extends RiderProfileRepository {
  _ProfileRepo() : super(ApiClient());
  @override
  Future<RiderProfile> getProfile() async => RiderProfile.fromJson(riderProfileJson());
}

// ── customer repositories (only for the routing test) ───────────────────────

class _CustomerDashboardRepo extends CustomerDashboardRepository {
  _CustomerDashboardRepo() : super(ApiClient());
  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 0, 'completed_pickups': 0, 'pending_pickups': 0,
        'total_weight_kg': 0.0, 'total_rewards_earned': 0.0, 'active_pickup': null, 'recent_pickups': [],
      });
}

class _CustomerPickupRepo extends CustomerPickupRepository {
  _CustomerPickupRepo() : super(ApiClient());
  @override
  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({String? status, String? month, int page = 1}) async =>
      (pickups: <PickupSummary>[], pagination: Pagination.fromJson(paginationJson(total: 0)));
}

class _CatalogueRepo extends CustomerCatalogueRepository {
  _CatalogueRepo() : super(ApiClient());
  @override
  Future<List<CategoryModel>> getCategories() async => <CategoryModel>[];
  @override
  Future<List<ItemModel>> getItems({String? category}) async => <ItemModel>[];
}

class _CentreRepo extends CustomerRecyclingCentreRepository {
  _CentreRepo() : super(ApiClient());
  @override
  Future<List<RecyclingCentreModel>> getCentres() async => <RecyclingCentreModel>[];
}

class _RewardRepo extends CustomerRewardRepository {
  _RewardRepo() : super(ApiClient());
  @override
  Future<({double balance, List<RewardTransactionModel> transactions, Pagination pagination})> getRewards({int page = 1}) async =>
      (balance: 0.0, transactions: <RewardTransactionModel>[], pagination: Pagination.fromJson(paginationJson(total: 0)));
}

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, null);
  });

  Widget withRepos(
    AuthProvider auth,
    Widget child, {
    _DashboardRepo? dashboard,
    _PickupRepo? pickups,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<RiderDashboardRepository>.value(value: dashboard ?? _DashboardRepo(json: riderDashboardJson())),
        Provider<RiderPickupRepository>.value(value: pickups ?? _PickupRepo()),
        Provider<RiderProfileRepository>.value(value: _ProfileRepo()),
        Provider<RiderLocationRepository>.value(value: RiderLocationRepository(ApiClient())),
        Provider<CustomerDashboardRepository>.value(value: _CustomerDashboardRepo()),
        Provider<CustomerPickupRepository>.value(value: _CustomerPickupRepo()),
        Provider<CustomerCatalogueRepository>.value(value: _CatalogueRepo()),
        Provider<CustomerRecyclingCentreRepository>.value(value: _CentreRepo()),
        Provider<CustomerRewardRepository>.value(value: _RewardRepo()),
      ],
      child: child,
    );
  }

  group('role routing (EcoXchangeApp)', () {
    testWidgets('a rider is routed to the Rider app, not the Customer app', (tester) async {
      await tester.pumpWidget(withRepos(await _signedIn('rider'), const EcoXchangeApp()));
      await tester.pumpAndSettle();

      expect(find.byType(RiderHomeScreen), findsOneWidget);
      expect(find.byType(CustomerHomeScreen), findsNothing);
    });

    testWidgets('a customer still gets the existing Customer app', (tester) async {
      await tester.pumpWidget(withRepos(await _signedIn('customer'), const EcoXchangeApp()));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerHomeScreen), findsOneWidget);
      expect(find.byType(RiderHomeScreen), findsNothing);
    });

    testWidgets('any other role gets neither app, only a message and logout', (tester) async {
      await tester.pumpWidget(withRepos(await _signedIn('staff'), const EcoXchangeApp()));
      await tester.pumpAndSettle();

      expect(find.byType(UnsupportedRoleScreen), findsOneWidget);
      expect(find.byType(RiderHomeScreen), findsNothing);
      expect(find.byType(CustomerHomeScreen), findsNothing);
    });

    testWidgets('rider logout returns to the login screen', (tester) async {
      await tester.pumpWidget(withRepos(await _signedIn('rider'), const EcoXchangeApp()));
      await tester.pumpAndSettle();

      // Log Out lives on the Profile tab.
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('rider-logout')), 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const Key('rider-logout')));
      await tester.pumpAndSettle();

      expect(find.byType(RiderHomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('rider shell', () {
    Future<void> pumpShell(WidgetTester tester, {_DashboardRepo? dashboard, _PickupRepo? pickups}) async {
      await tester.pumpWidget(withRepos(
        await _signedIn('rider'),
        const MaterialApp(home: RiderHomeScreen()),
        dashboard: dashboard,
        pickups: pickups,
      ));
    }

    testWidgets('dashboard: loading spinner, then real counters and jobs with identity', (tester) async {
      final pending = Completer<RiderDashboard>();
      await pumpShell(tester, dashboard: _DashboardRepo(pending: pending));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(RiderDashboard.fromJson(riderDashboardJson(
        activeTask: riderPickupSummaryJson(id: 5, assignmentStatus: 'en_route'),
        nextPickup: riderPickupSummaryJson(id: 6),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Ahmad Farhan'), findsOneWidget);
      expect(find.text('Rider · Available'), findsOneWidget);
      expect(find.text('AF'), findsOneWidget); // initials avatar
      // The three white stat cards: assigned / completed / collected today.
      final stats = find.byKey(const Key('rider-today-stats'));
      expect(find.descendant(of: stats, matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('3.4 kg')), findsOneWidget);
      // One job card: the CURRENT job wins over the next assigned one.
      expect(find.byKey(const Key('rider-active-task')), findsOneWidget);
      expect(find.text('On the Way'), findsOneWidget);
      expect(find.text('PK-5'), findsOneWidget);
      expect(find.byKey(const Key('rider-next-pickup')), findsNothing);
      expect(find.byKey(const Key('rider-view-route')), findsOneWidget);
      expect(find.text('▶ Collect Pickup'), findsOneWidget); // en_route → collect
      // No invented ETA / distance.
      expect(find.textContaining('ETA'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
    });

    testWidgets('dashboard: nothing assigned shows the empty message, no invented job', (tester) async {
      await pumpShell(tester, dashboard: _DashboardRepo(json: riderDashboardJson(assignedToday: 0, completedToday: 0, weightToday: 0)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rider-no-work')), findsOneWidget);
      expect(find.byKey(const Key('rider-active-task')), findsNothing);
      expect(find.byKey(const Key('rider-next-pickup')), findsNothing);
    });

    testWidgets('dashboard: an API error shows the error state and retry re-fetches', (tester) async {
      final repo = _DashboardRepo(error: const NetworkException('Could not connect.'));
      await pumpShell(tester, dashboard: repo);
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect. Check your internet connection.'), findsOneWidget);
      expect(repo.calls, 1);

      repo
        ..error = null
        ..json = riderDashboardJson();
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(repo.calls, 2);
      expect(find.text('3.4 kg'), findsOneWidget);
    });

    testWidgets('my tasks tab: empty states when nothing is assigned', (tester) async {
      await pumpShell(tester, pickups: _PickupRepo());
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Pending (0)'), findsOneWidget);
      expect(find.text('No tasks waiting for you to accept.'), findsOneWidget);
    });

    testWidgets('my tasks tab: tapping a job opens its real detail', (tester) async {
      final repo = _PickupRepo(list: [riderPickupSummaryJson(id: 12, assignmentStatus: 'accepted')]);
      await pumpShell(tester, pickups: repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tasks-tab-1'))); // Ongoing
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-12')));
      await tester.pumpAndSettle();

      expect(repo.detailCalls, [12]);
      expect(find.text('PK-12'), findsWidgets);
      expect(find.text('Nurul Aisyah'), findsOneWidget);
      expect(find.textContaining('47620 Subang Jaya'), findsOneWidget);
      // Items and notes sit below the fold of the (lazily built) detail list,
      // above the action area.
      await tester.scrollUntilVisible(find.byKey(const Key('rider-item-10')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const Key('rider-item-10')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Please call on arrival.'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('Please call on arrival.'), findsOneWidget);
    });

    testWidgets('pickup detail: a 403 (not this rider\'s pickup) shows the server message', (tester) async {
      final repo = _PickupRepo(
        list: [riderPickupSummaryJson(id: 99)],
        detailError: const ForbiddenException('This pickup is not assigned to you.'),
      );
      await pumpShell(tester, pickups: repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-99')));
      await tester.pumpAndSettle();

      expect(find.text('This pickup is not assigned to you.'), findsOneWidget);
    });

    testWidgets('profile tab: real profile and totals, never identity-document numbers', (tester) async {
      await pumpShell(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Ahmad Farhan bin Razak'), findsOneWidget);
      expect(find.text('Motorcycle · WXY1234'), findsOneWidget);
      final stats = find.byKey(const Key('rider-profile-stats'));
      expect(find.descendant(of: stats, matching: find.text('14')), findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('3')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('rider-logout')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const Key('rider-logout')), findsOneWidget);
      expect(find.textContaining('900101'), findsNothing);
      expect(find.textContaining('D1234567'), findsNothing);
    });
  });
}
