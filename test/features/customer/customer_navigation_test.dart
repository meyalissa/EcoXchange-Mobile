// EcoXchange Mobile — Customer full navigation (UI refinement): Home's
// "Your Impact This Month" from the real monthly dashboard fields, Pickup
// Hub, AI Scan hub → Manual Calculator (server estimate by weight), Rewards
// filters over the real transaction types, and Profile (no points, tier,
// bank details or account deletion). Repositories are test-only fakes.

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
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_summary.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/reward_transaction.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_dashboard_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_reward_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/customer_home_screen.dart';

import '../../fixtures/ai_scan_fixtures.dart';

Map<String, dynamic> _page(int total) => {'current_page': 1, 'last_page': 1, 'per_page': 15, 'total': total};

class _AuthRepo extends AuthRepository {
  _AuthRepo(TokenStorage s) : super(apiClient: ApiClient(tokenStorage: s), tokenStorage: s);
  @override
  Future<UserModel> login({required String email, required String password}) async =>
      const UserModel(id: 1, name: 'Test Customer', email: 'customer@example.com', role: 'customer', phoneNumber: '+60120000000', profilePhotoUrl: null);
  @override
  Future<void> logout() async {}
}

class _Dashboard extends CustomerDashboardRepository {
  _Dashboard({this.monthly = true}) : super(ApiClient());
  final bool monthly;
  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 5, 'completed_pickups': 3, 'pending_pickups': 1,
        'total_weight_kg': 9.75, 'total_rewards_earned': 12.5,
        'active_pickup': null, 'recent_pickups': [],
        if (monthly) 'monthly_weight_kg': 6.5,
        if (monthly) 'monthly_completed_pickups': 2,
      });
}

class _Pickups extends CustomerPickupRepository {
  _Pickups() : super(ApiClient());
  @override
  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({String? status, String? month, int page = 1}) async =>
      (pickups: <PickupSummary>[], pagination: Pagination.fromJson(_page(0)));
}

class _Catalogue extends CustomerCatalogueRepository {
  _Catalogue() : super(ApiClient());
  @override
  Future<List<CategoryModel>> getCategories() async => <CategoryModel>[];
  @override
  Future<List<ItemModel>> getItems({String? category}) async => [ItemModel.fromJson(plasticBottleJson), ItemModel.fromJson(glassBottleJson)];
}

class _Centres extends CustomerRecyclingCentreRepository {
  _Centres() : super(ApiClient());
  @override
  Future<List<RecyclingCentreModel>> getCentres() async => <RecyclingCentreModel>[];
}

class _Rewards extends CustomerRewardRepository {
  _Rewards() : super(ApiClient());
  @override
  Future<({double balance, List<RewardTransactionModel> transactions, Pagination pagination})> getRewards({int page = 1}) async => (
        balance: 6.0,
        transactions: [
          RewardTransactionModel.fromJson({'id': 1, 'type': 'earn', 'amount': 5.0, 'balance_after': 5.0, 'status': 'completed', 'note': null, 'pickup_id': 3, 'transacted_at': '2026-09-20T10:00:00+08:00'}),
          RewardTransactionModel.fromJson({'id': 2, 'type': 'bonus', 'amount': 1.0, 'balance_after': 6.0, 'status': 'completed', 'note': null, 'pickup_id': null, 'transacted_at': '2026-09-21T10:00:00+08:00'}),
        ],
        pagination: Pagination.fromJson(_page(2)),
      );
}

/// Records the calculator request; answers with a server-shaped estimate.
class _Booking extends CustomerPickupBookingRepository {
  _Booking() : super(ApiClient());
  Map<int, double>? sent;
  @override
  Future<PickupEstimate> estimateByWeight(Map<int, double> weightsKg) async {
    sent = weightsKg;
    return PickupEstimate.fromJson({
      'items': [
        {'item_id': 1, 'name': 'Plastic Bottle', 'category': 'Plastic', 'quantity': 1, 'unit_weight_kg': null, 'weight_kg': 1.5, 'weight_source': 'provided', 'preliminary_price_per_kg': 0.4, 'preliminary_line_reward': 0.6},
      ],
      'total_weight_kg': 1.5,
      'preliminary_reward': 0.6,
      'unavailable_item_ids': [],
      'note': 'Preliminary estimate only.',
    });
  }
}

void main() {
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secureStorageChannel, null);
  });

  Future<_Booking> pumpShell(WidgetTester tester, {bool monthly = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final storage = TokenStorage();
    final auth = AuthProvider(authRepository: _AuthRepo(storage));
    await auth.login(email: 'customer@example.com', password: 'x');
    final booking = _Booking();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<CustomerDashboardRepository>.value(value: _Dashboard(monthly: monthly)),
        Provider<CustomerPickupRepository>.value(value: _Pickups()),
        Provider<CustomerCatalogueRepository>.value(value: _Catalogue()),
        Provider<CustomerRecyclingCentreRepository>.value(value: _Centres()),
        Provider<CustomerRewardRepository>.value(value: _Rewards()),
        Provider<CustomerPickupBookingRepository>.value(value: booking),
      ],
      child: const MaterialApp(home: CustomerHomeScreen()),
    ));
    await tester.pumpAndSettle();
    return booking;
  }

  testWidgets('Home: wallet and this month\'s real impact (kg + pickups only)', (tester) async {
    await pumpShell(tester);

    expect(find.byKey(const Key('home-wallet')), findsOneWidget);
    expect(find.text('RM 6.00'), findsWidgets); // RewardProvider balance
    final impact = find.byKey(const Key('home-impact'));
    expect(impact, findsOneWidget);
    expect(find.descendant(of: impact, matching: find.text('6.5')), findsOneWidget);
    expect(find.descendant(of: impact, matching: find.text('2')), findsOneWidget);
    for (final fake in ['CO₂', 'CO2', 'trees', 'Trees', 'points', 'Points', 'Tier']) {
      expect(find.textContaining(fake), findsNothing);
    }
  });

  testWidgets('Home: no impact card when the backend sends no monthly fields', (tester) async {
    await pumpShell(tester, monthly: false);
    expect(find.byKey(const Key('home-impact')), findsNothing);
  });

  testWidgets('Pickup tab: request button and recent pickups section', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup Hub'), findsOneWidget);
    expect(find.byKey(const Key('request-new-pickup')), findsOneWidget);
  });

  testWidgets('Part A: "Request New Pickup" opens the scan-first flow, not manual item selection', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('request-new-pickup')));
    await tester.pumpAndSettle();

    // Scan-first, the same flow the AI Scan tab uses — and, per the "fix
    // AI Scan / Request Pickup navigation" task, it lands straight on
    // Scan & Classify with no photo chosen yet, not on an intermediate
    // empty "Scan Multiple Items" screen the user would have to tap
    // through first (MultiImageScanScreen still owns the session
    // underneath — see that screen's auto-open in initState()).
    expect(find.text('Scan & Classify'), findsOneWidget);
    expect(find.text('Select Items'), findsNothing, reason: 'manual item selection is no longer the first screen');
  });

  testWidgets('Part A: "Request New Pickup" from the My Pickups list also opens the scan-first flow', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Pickup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('request-new-pickup')));
    await tester.pumpAndSettle();

    expect(find.text('Scan & Classify'), findsOneWidget);
  });

  testWidgets('Part 1: "AI Scan" tab → "Scan Item" opens Scan & Classify directly, with no photo selected yet', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('AI Scan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-open-camera')));
    await tester.pumpAndSettle();

    // Lands straight on Scan & Classify's empty picker (no auto-restored
    // image, no intermediate empty "Scan Multiple Items" screen to tap
    // through first).
    expect(find.text('Scan & Classify'), findsOneWidget);
    expect(find.text('Scan a Recyclable Item'), findsOneWidget);
    expect(find.text('Scan Multiple Items'), findsNothing);
  });

  testWidgets('AI Scan → Manual Calculator sends the entered weight and shows the server estimate', (tester) async {
    final booking = await pumpShell(tester);
    await tester.tap(find.text('AI Scan'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-open-camera')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-open-calculator')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calc-item-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('calc-weight-1')), '1.5');
    await tester.tap(find.byKey(const Key('calc-submit')));
    await tester.pumpAndSettle();

    expect(booking.sent, {1: 1.5});
    final result = find.byKey(const Key('calc-result'));
    expect(find.descendant(of: result, matching: find.text('RM 0.60')), findsWidgets);
  });

  testWidgets('Manual Calculator rejects a missing weight without calling the API', (tester) async {
    final booking = await pumpShell(tester);
    await tester.tap(find.text('AI Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-open-calculator')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calc-item-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calc-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calc-form-error')), findsOneWidget);
    expect(booking.sent, isNull);
  });

  testWidgets('Rewards: All / Earned / Bonus filter the real transactions', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rewards-wallet')), findsOneWidget);
    expect(find.text('Pickup Completed'), findsOneWidget);
    expect(find.text('Bonus'), findsWidgets);

    await tester.tap(find.byKey(const Key('rewards-filter-bonus')));
    await tester.pumpAndSettle();
    expect(find.text('Pickup Completed'), findsNothing);

    await tester.tap(find.byKey(const Key('rewards-filter-earn')));
    await tester.pumpAndSettle();
    expect(find.text('Pickup Completed'), findsOneWidget);
  });

  testWidgets('Profile: real identity and totals; no points, tier, bank or delete account', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Test Customer'), findsWidgets);
    final stats = find.byKey(const Key('profile-stats'));
    expect(find.descendant(of: stats, matching: find.text('5')), findsOneWidget);
    expect(find.descendant(of: stats, matching: find.text('RM 12.50')), findsOneWidget);
    expect(find.byKey(const Key('profile-logout')), findsOneWidget);
    for (final fake in ['Bank', 'Delete Account', 'Points', 'Tier', 'Gold']) {
      expect(find.textContaining(fake), findsNothing);
    }
  });
}
