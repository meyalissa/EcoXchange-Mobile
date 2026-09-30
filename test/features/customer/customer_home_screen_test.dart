// EcoXchange Mobile — Customer navigation + logout tests (Phase 4C.2
// §12/§21). flutter_secure_storage's platform channel is mocked (same
// approach as the Phase 4C.1 widget_test.dart) since TokenStorage is on
// the real code path for logout.

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

  // Skips the real HTTP call — logout's LOCAL-clearing behaviour (the
  // thing this test verifies) doesn't depend on the network round trip.
  @override
  Future<void> logout() async {}

  // Dashboard now shows the real logged-in user's name (Phase 4C.3), so
  // the shell needs a genuine AuthProvider.user — skips the real HTTP call
  // the same way logout() above does.
  @override
  Future<UserModel> login({required String email, required String password}) async {
    return const UserModel(id: 1, name: 'Test Customer', email: 'test@example.com', role: 'customer', phoneNumber: null);
  }
}

class _EmptyDashboardRepository extends CustomerDashboardRepository {
  _EmptyDashboardRepository() : super(ApiClient());
  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 0, 'completed_pickups': 0, 'pending_pickups': 0,
        'total_weight_kg': 0.0, 'total_rewards_earned': 0.0,
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

  Future<void> pumpShell(WidgetTester tester, AuthProvider authProvider) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          Provider<CustomerDashboardRepository>.value(value: _EmptyDashboardRepository()),
          Provider<CustomerPickupRepository>.value(value: _EmptyPickupRepository()),
          Provider<CustomerCatalogueRepository>.value(value: _EmptyCatalogueRepository()),
          Provider<CustomerRecyclingCentreRepository>.value(value: _EmptyCentreRepository()),
          Provider<CustomerRewardRepository>.value(value: _EmptyRewardRepository()),
        ],
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bottom navigation shows the 5 real customer sections and switches between them', (tester) async {
    final tokenStorage = TokenStorage();
    final authRepository = _NoOpAuthRepository(apiClient: ApiClient(tokenStorage: tokenStorage), tokenStorage: tokenStorage);
    final authProvider = AuthProvider(authRepository: authRepository);
    await authProvider.login(email: 'test@example.com', password: 'password');

    await pumpShell(tester, authProvider);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Pickups'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Centres'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);

    // Starts on Dashboard — its gradient hero shows the real logged-in
    // user's name and the real wallet card, not a literal "Dashboard" title.
    expect(find.text('Test Customer'), findsOneWidget);
    expect(find.text('ECOXCHANGE WALLET'), findsOneWidget);

    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
    expect(find.text('WALLET BALANCE'), findsOneWidget);

    // No points system anywhere on the rewards tab.
    expect(find.textContaining('points', findRichText: true), findsNothing);
  });

  testWidgets('logout button clears the session and is never missing', (tester) async {
    final tokenStorage = TokenStorage();
    final authRepository = _NoOpAuthRepository(apiClient: ApiClient(tokenStorage: tokenStorage), tokenStorage: tokenStorage);
    final authProvider = AuthProvider(authRepository: authRepository);
    await authProvider.login(email: 'test@example.com', password: 'password');

    await pumpShell(tester, authProvider);

    expect(find.byIcon(Icons.logout), findsOneWidget);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(authProvider.status, AuthStatus.unauthenticated);
    expect(authProvider.user, isNull);
  });
}
