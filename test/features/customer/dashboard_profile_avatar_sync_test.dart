// EcoXchange Mobile — Home avatar / Profile photo synchronization
// (Profile Photo Sync & Map Gestures fix).
//
// Root cause this guards against regressing: `AuthProvider.user` was
// already the single, always-fresh source for the profile photo (every
// save -- photo or otherwise -- reaches it via `applyUpdatedUser()`); Home's
// own avatar widget simply never read `.profilePhotoUrl` at all. These
// tests pump the real `CustomerHomeScreen` (not a stub) so a regression
// that reintroduces a second, stale avatar implementation on Home would
// fail here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';
import 'package:ecoxchange_mobile/core/widgets/app_network_image.dart';
import 'package:ecoxchange_mobile/core/widgets/profile_avatar.dart';
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

const _initialPhoto = 'https://ecoxchange.test/storage/profile-photos/before.jpg';
const _updatedPhoto = 'https://ecoxchange.test/storage/profile-photos/after.jpg';

class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository({required super.apiClient, required super.tokenStorage, required this.initialUser});

  final UserModel initialUser;

  @override
  Future<UserModel> login({required String email, required String password}) async => initialUser;
}

class _EmptyDashboardRepository extends CustomerDashboardRepository {
  _EmptyDashboardRepository() : super(ApiClient());
  @override
  Future<DashboardData> getDashboard() async => DashboardData.fromJson({
        'total_pickups': 0, 'completed_pickups': 0, 'pending_pickups': 0,
        'total_weight_kg': 0.0, 'total_rewards_earned': 0.0,
        'monthly_weight_kg': 0.0, 'monthly_completed_pickups': 0,
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

class _EmptyCommunityImpactRepository extends CommunityImpactRepository {
  _EmptyCommunityImpactRepository() : super(ApiClient());
  @override
  Future<CommunityImpactSummary> getImpact({String period = 'all_time', String? state, String? area}) async {
    return CommunityImpactSummary.fromJson({
      'period': 'all_time', 'state': null, 'area': null, 'location_label': 'Malaysia-wide',
      'available_states': <String>[], 'available_areas': <String>[],
      'suppressed': false, 'suppression_threshold': 5,
      'completed_pickups': 0, 'total_weight_kg': 0.0, 'participating_customers': 0,
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

  Future<AuthProvider> pumpHome(WidgetTester tester, UserModel user) async {
    final tokenStorage = TokenStorage();
    final authRepository = _StubAuthRepository(apiClient: ApiClient(tokenStorage: tokenStorage), tokenStorage: tokenStorage, initialUser: user);
    final authProvider = AuthProvider(authRepository: authRepository);
    await authProvider.login(email: 'test@example.com', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          Provider<CustomerDashboardRepository>.value(value: _EmptyDashboardRepository()),
          Provider<CommunityImpactRepository>.value(value: _EmptyCommunityImpactRepository()),
          Provider<CustomerPickupRepository>.value(value: _EmptyPickupRepository()),
          Provider<CustomerCatalogueRepository>.value(value: _EmptyCatalogueRepository()),
          Provider<CustomerRecyclingCentreRepository>.value(value: _EmptyCentreRepository()),
          Provider<CustomerRewardRepository>.value(value: _EmptyRewardRepository()),
        ],
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return authProvider;
  }

  const userWithPhoto = UserModel(id: 1, name: 'Nadia', email: 'nadia@example.com', role: 'customer', phoneNumber: null, profilePhotoUrl: _initialPhoto);
  const userWithoutPhoto = UserModel(id: 1, name: 'Nadia', email: 'nadia@example.com', role: 'customer', phoneNumber: null, profilePhotoUrl: null);

  testWidgets('Home shows the same photo URL Profile would read from AuthProvider.user', (tester) async {
    await pumpHome(tester, userWithPhoto);

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photoUrl, _initialPhoto);
    final image = tester.widget<AppNetworkImage>(find.descendant(of: find.byType(ProfileAvatar), matching: find.byType(AppNetworkImage)));
    expect(image.url, _initialPhoto);
  });

  testWidgets('Home falls back to the initial avatar when the user has no photo', (tester) async {
    await pumpHome(tester, userWithoutPhoto);

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photoUrl, isNull);
    expect(find.descendant(of: find.byType(ProfileAvatar), matching: find.byType(AppNetworkImage)), findsNothing);
    expect(find.descendant(of: find.byType(ProfileAvatar), matching: find.text('N')), findsOneWidget);
  });

  testWidgets('updating the profile photo refreshes the Home avatar without logout/login', (tester) async {
    final authProvider = await pumpHome(tester, userWithoutPhoto);
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).photoUrl, isNull);

    // Mirrors exactly what EditPersonalInfoProvider does on a successful
    // photo upload/save -- no new sync mechanism invented for this test.
    authProvider.applyUpdatedUser(const UserModel(id: 1, name: 'Nadia', email: 'nadia@example.com', role: 'customer', phoneNumber: null, profilePhotoUrl: _updatedPhoto));
    await tester.pumpAndSettle();

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photoUrl, _updatedPhoto);
    final image = tester.widget<AppNetworkImage>(find.descendant(of: find.byType(ProfileAvatar), matching: find.byType(AppNetworkImage)));
    expect(image.url, _updatedPhoto);
  });
}
