// EcoXchange Mobile — Rewards Hub compact-layout regression tests
// (Typography/Spacing Compacting pass, matching the Home dashboard's own
// pass). Verifies the gold wallet header and Transactions heading/filter
// chips render without overflow at a narrow mobile width, with a very
// large balance, and with a long transaction description — and that the
// All/Earned/Bonus filtering behaviour and bottom navigation are
// unchanged.

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

class _NoOpAuthRepository extends AuthRepository {
  _NoOpAuthRepository({required super.apiClient, required super.tokenStorage});

  @override
  Future<UserModel> login({required String email, required String password}) async {
    return const UserModel(id: 1, name: 'Test Customer', email: 'test@example.com', role: 'customer', phoneNumber: null, profilePhotoUrl: null);
  }
}

class _DashboardRepositoryWithLargeLifetime extends CustomerDashboardRepository {
  _DashboardRepositoryWithLargeLifetime() : super(ApiClient());

  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 0, 'completed_pickups': 0, 'pending_pickups': 0,
        'total_weight_kg': 0.0, 'total_rewards_earned': 123456.78,
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

/// A very large balance (stresses the gold header's FittedBox/ellipsis
/// guards) and one transaction with a long note + long pickup reference
/// (stresses the transaction tile's maxLines/ellipsis guards).
class _RewardRepositoryWithLargeAndLongData extends CustomerRewardRepository {
  _RewardRepositoryWithLargeAndLongData() : super(ApiClient());

  @override
  Future<({double balance, List<RewardTransactionModel> transactions, Pagination pagination})> getRewards({int page = 1}) async => (
        balance: 987654.32,
        transactions: [
          RewardTransactionModel.fromJson({
            'id': 1, 'type': 'earn', 'amount': 12345.67, 'balance_after': 12345.67, 'status': 'completed',
            'note': 'Collected a very large mixed batch of plastics, glass, paper and electronics from the Shah Alam industrial drop-off point',
            'pickup_id': 99999, 'transacted_at': '2026-09-20T10:00:00+08:00',
          }),
          RewardTransactionModel.fromJson({
            'id': 2, 'type': 'bonus', 'amount': 1.0, 'balance_after': 12346.67, 'status': 'completed',
            'note': null, 'pickup_id': null, 'transacted_at': '2026-09-21T10:00:00+08:00',
          }),
        ],
        pagination: Pagination.fromJson({'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 2}),
      );
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

  Future<void> pumpRewardsTab(WidgetTester tester) async {
    final tokenStorage = TokenStorage();
    final authRepository = _NoOpAuthRepository(apiClient: ApiClient(tokenStorage: tokenStorage), tokenStorage: tokenStorage);
    final authProvider = AuthProvider(authRepository: authRepository);
    await authProvider.login(email: 'test@example.com', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          Provider<CustomerDashboardRepository>.value(value: _DashboardRepositoryWithLargeLifetime()),
          Provider<CustomerPickupRepository>.value(value: _EmptyPickupRepository()),
          Provider<CustomerCatalogueRepository>.value(value: _EmptyCatalogueRepository()),
          Provider<CustomerRecyclingCentreRepository>.value(value: _EmptyCentreRepository()),
          Provider<CustomerRewardRepository>.value(value: _RewardRepositoryWithLargeAndLongData()),
        ],
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the compact gold wallet header without overflow at a narrow mobile width', (tester) async {
    // 320 logical px wide — the classic small-phone breakpoint.
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpRewardsTab(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('rewards-wallet')), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
  });

  testWidgets('a very large wallet balance and lifetime figure never overflow', (tester) async {
    await pumpRewardsTab(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('987,654.32'), findsNothing); // no thousands separator is applied — raw server figure only
    expect(find.text('RM 987654.32'), findsOneWidget);
    expect(find.text('RM 123456.78'), findsOneWidget);
  });

  testWidgets('a long transaction note and pickup reference wrap/truncate instead of overflowing', (tester) async {
    await pumpRewardsTab(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Pickup Completed'), findsOneWidget);
    expect(find.textContaining('Pickup #PK-99999'), findsOneWidget);
  });

  testWidgets('filter chips remain tappable and wrap correctly at a narrow width', (tester) async {
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpRewardsTab(tester);

    expect(find.text('Pickup Completed'), findsOneWidget);
    expect(find.text('Bonus'), findsWidgets);

    await tester.tap(find.byKey(const Key('rewards-filter-bonus')));
    await tester.pumpAndSettle();
    expect(find.text('Pickup Completed'), findsNothing);

    await tester.tap(find.byKey(const Key('rewards-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Pickup Completed'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation keeps its 5 destinations and the central AI Scan button', (tester) async {
    await pumpRewardsTab(tester);

    for (final label in ['Home', 'Pickup', 'AI Scan', 'Rewards', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('nav-center-AI Scan')), findsOneWidget);
  });
}
