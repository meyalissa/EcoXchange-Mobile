// EcoXchange Mobile — Home dashboard compact-layout regression tests
// (Typography/Spacing Compacting pass). Verifies the wallet header and
// "Your Impact This Month" card render without overflow at a narrow
// mobile width, that the bottom navigation's 5 destinations and central
// AI Scan button are unchanged, and that the Community Impact link still
// works after the layout pass.

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
    // A deliberately long name — stresses the greeting row's `Expanded` +
    // avatar layout, which must ellipsize rather than overflow.
    return const UserModel(id: 1, name: 'Muhammad Firdaus bin Abdul Rahman', email: 'test@example.com', role: 'customer', phoneNumber: null, profilePhotoUrl: null);
  }
}

class _DashboardRepositoryWithLargeFigures extends CustomerDashboardRepository {
  _DashboardRepositoryWithLargeFigures() : super(ApiClient());

  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 48, 'completed_pickups': 40, 'pending_pickups': 8,
        // Large figures — stresses the wallet/impact card's FittedBox
        // scaling at narrow widths.
        'total_weight_kg': 12345.67, 'total_rewards_earned': 98765.43,
        'monthly_weight_kg': 1234.5, 'monthly_completed_pickups': 27,
        'active_pickup': {
          'id': 9, 'reference': 'PK-00009', 'status': 'assigned', 'pickup_date': '2026-09-10', 'pickup_time': '09:00 AM',
          'estimated_weight_kg': 5.0, 'actual_weight_kg': null, 'estimated_reward': 10.0, 'actual_reward': null,
          'centre': {'name': 'EcoRecycle Shah Alam'}, 'items': [],
          'assigned_rider': {'name': 'Ahmad Zulkifli bin Hassan'}, 'created_at': '2026-09-01T00:00:00Z',
        },
        'recent_pickups': [],
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
      (balance: 98765.43, transactions: <RewardTransactionModel>[], pagination: Pagination.fromJson({'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': 0}));
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

  Future<void> pumpHome(WidgetTester tester) async {
    final tokenStorage = TokenStorage();
    final authRepository = _NoOpAuthRepository(apiClient: ApiClient(tokenStorage: tokenStorage), tokenStorage: tokenStorage);
    final authProvider = AuthProvider(authRepository: authRepository);
    await authProvider.login(email: 'test@example.com', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          Provider<CustomerDashboardRepository>.value(value: _DashboardRepositoryWithLargeFigures()),
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
  }

  testWidgets('renders the compact wallet header and impact card without overflow at a narrow mobile width', (tester) async {
    // 320 logical px wide — the classic small-phone breakpoint (e.g. iPhone SE).
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpHome(tester);

    // No RenderFlex overflow / layout assertion was thrown while building
    // or laying out the header, impact card, active-pickup banner or
    // bottom nav at this width.
    expect(tester.takeException(), isNull);

    expect(find.text('ECOXCHANGE WALLET'), findsOneWidget);
    expect(find.text('YOUR IMPACT THIS MONTH'), findsOneWidget);
    expect(find.byKey(const Key('home-view-community-impact')), findsOneWidget);
    expect(find.byKey(const Key('active-pickup')), findsOneWidget);
  });

  testWidgets('bottom navigation keeps its 5 destinations and the central AI Scan button after the layout pass', (tester) async {
    await pumpHome(tester);

    for (final label in ['Home', 'Pickup', 'AI Scan', 'Rewards', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('nav-center-AI Scan')), findsOneWidget);
  });

  testWidgets('the Community Impact link inside the impact card still navigates after the layout pass', (tester) async {
    await pumpHome(tester);

    await tester.ensureVisible(find.byKey(const Key('home-view-community-impact')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-view-community-impact')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Community Impact'), findsOneWidget);
  });
}
