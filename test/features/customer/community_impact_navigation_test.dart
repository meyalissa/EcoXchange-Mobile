// EcoXchange Mobile — regression test for the ProviderNotFoundException
// that occurred when opening Community Impact from the real customer
// Home dashboard.
//
// Root cause: `dashboard_screen.dart` built `CommunityImpactProvider` at
// the Dashboard's push call site, reading `CommunityImpactRepository` from
// a context captured from `_HomeContent` instead of letting the pushed
// screen resolve its own dependency the way every other screen in this
// app does (e.g. `RiderPickupDetailScreen`, `CommunityLeaderboardScreen`).
// Fixed by making `CommunityImpactScreen` self-contained: it now wraps
// itself in its own `ChangeNotifierProvider` built from
// `context.read<CommunityImpactRepository>()`, using that `create`
// callback's OWN context. This test drives the REAL navigation path (tap
// "View Community Impact" inside the Home dashboard's impact card) with
// the full provider set `main.dart` registers, to prove it renders
// without throwing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/data/models/user_model.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/community_impact.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/dashboard_data.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pagination.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_summary.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/reward_transaction.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/community_impact_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_reward_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/customer_home_screen.dart';

class _NoOpAuthRepository extends AuthRepository {
  _NoOpAuthRepository({required super.apiClient, required super.tokenStorage});

  @override
  Future<UserModel> login({required String email, required String password}) async {
    return const UserModel(id: 1, name: 'Test Customer', email: 'test@example.com', role: 'customer', phoneNumber: null, profilePhotoUrl: null);
  }
}

/// Monthly fields populated (unlike the zeroed fixtures elsewhere) so the
/// real "Your Impact This Month" card — and its "View Community Impact"
/// link — actually renders on Home, exactly as it would for a real
/// customer with completed pickups this month.
class _DashboardRepositoryWithMonthlyData extends CustomerDashboardRepository {
  _DashboardRepositoryWithMonthlyData() : super(ApiClient());

  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 4, 'completed_pickups': 3, 'pending_pickups': 1,
        'total_weight_kg': 40.0, 'total_rewards_earned': 55.0,
        'monthly_weight_kg': 12.5, 'monthly_completed_pickups': 2,
        'active_pickup': null, 'recent_pickups': [],
      });
}

class _EmptyPickupRepository extends CustomerPickupRepository {
  _EmptyPickupRepository() : super(ApiClient());
  @override
  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({String? status, String? month, int page = 1}) async =>
      (pickups: <PickupSummary>[], pagination: Pagination.fromJson({'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 0}));
}

class _EmptyCatalogueRepository extends CustomerCatalogueRepository {
  _EmptyCatalogueRepository() : super(ApiClient());
  @override
  Future<List<CategoryModel>> getCategories() async => <CategoryModel>[];
  @override
  Future<List<ItemModel>> getItems({String? category}) async => <ItemModel>[];
}

class _EmptyCentreRepository extends CustomerRecyclingCentreRepository {
  _EmptyCentreRepository() : super(ApiClient());
  @override
  Future<List<RecyclingCentreModel>> getCentres() async => <RecyclingCentreModel>[];
}

class _EmptyRewardRepository extends CustomerRewardRepository {
  _EmptyRewardRepository() : super(ApiClient());
  @override
  Future<({double balance, List<RewardTransactionModel> transactions, Pagination pagination})> getRewards({int page = 1}) async =>
      (balance: 0.0, transactions: <RewardTransactionModel>[], pagination: Pagination.fromJson({'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 0}));
}

class _FakeCommunityImpactRepository extends CommunityImpactRepository {
  _FakeCommunityImpactRepository() : super(ApiClient());

  @override
  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async {
    return CommunityImpactSummary.fromJson({
      'period': 'all_time', 'state': null, 'area': null, 'location_label': 'Malaysia-wide',
      'available_states': <String>[], 'available_areas': <String>[],
      'suppressed': false, 'suppression_threshold': 5,
      'completed_pickups': 20, 'total_weight_kg': 100.0, 'participating_customers': 8,
      'trend': {'labels': <String>[], 'data': <double>[]},
      'area_comparison': <Map<String, dynamic>>[],
    });
  }
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

  testWidgets(
    'opening Community Impact from the real Home dashboard renders without ProviderNotFoundException',
    (tester) async {
      final tokenStorage = TokenStorage();
      final authRepository = _NoOpAuthRepository(apiClient: ApiClient(tokenStorage: tokenStorage), tokenStorage: tokenStorage);
      final authProvider = AuthProvider(authRepository: authRepository);
      await authProvider.login(email: 'test@example.com', password: 'password');

      // The exact provider set main.dart registers at the app root —
      // including CommunityImpactRepository, which the original bug
      // report showed missing from the live app's resolved tree.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<CustomerDashboardRepository>.value(value: _DashboardRepositoryWithMonthlyData()),
            Provider<CommunityImpactRepository>.value(value: _FakeCommunityImpactRepository()),
            Provider<CustomerPickupRepository>.value(value: _EmptyPickupRepository()),
            Provider<CustomerCatalogueRepository>.value(value: _EmptyCatalogueRepository()),
            Provider<CustomerRecyclingCentreRepository>.value(value: _EmptyCentreRepository()),
            Provider<CustomerRewardRepository>.value(value: _EmptyRewardRepository()),
          ],
          child: const MaterialApp(home: CustomerHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Real Home dashboard, real impact card, real link — not a probe.
      expect(find.text('YOUR IMPACT THIS MONTH'), findsOneWidget);
      expect(find.byKey(const Key('home-view-community-impact')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('home-view-community-impact')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-view-community-impact')));
      await tester.pumpAndSettle();

      // The actual regression: this threw ProviderNotFoundException before
      // the fix. No exception should have been thrown by the navigation,
      // and the Community Impact screen's real, API-backed content —
      // never a hardcoded fallback — must be on screen.
      expect(tester.takeException(), isNull);
      expect(find.text('Community Impact'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // Returning to Home must not leave Home (or its own providers)
      // broken either. EcoAppBar uses its own custom back button (not a
      // standard Material/Cupertino BackButton type), so it's found by
      // icon rather than via `tester.pageBack()`.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('YOUR IMPACT THIS MONTH'), findsOneWidget);
    },
  );
}
