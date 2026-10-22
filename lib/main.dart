import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/api/api_client.dart';
import 'core/api/api_config.dart';
import 'core/storage/server_config_storage.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/profile_repository.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/customer/data/repositories/community_impact_repository.dart';
import 'features/customer/data/repositories/customer_address_repository.dart';
import 'features/customer/data/repositories/customer_catalogue_repository.dart';
import 'features/customer/data/repositories/customer_dashboard_repository.dart';
import 'features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'features/customer/data/repositories/customer_pickup_repository.dart';
import 'features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'features/customer/data/repositories/customer_reward_repository.dart';
import 'features/rider/data/repositories/rider_dashboard_repository.dart';
import 'features/rider/data/repositories/rider_location_repository.dart';
import 'features/rider/data/repositories/rider_pickup_repository.dart';
import 'features/rider/data/repositories/rider_profile_repository.dart';

/// EcoXchange Mobile — composition root. Wires the layers explained in the
/// Phase 4C.1/4C.2 reports:
///   ApiClient (HTTP + envelope/error mapping)
///     → Repositories (real endpoints, typed parsing — one per Customer
///       API domain, registered here as plain `Provider`s so any screen/
///       screen-level provider can read them via context)
///       → Provider/ChangeNotifier (screen state — created lazily inside
///         CustomerHomeScreen's own MultiProvider, not here, so a
///         repository's provider exists before anything tries to build a
///         ChangeNotifier from it)
///         → UI
///
/// Repositories are plain `Provider.value`s (no state of their own) built
/// once from the single shared ApiClient — never a second HTTP client, per
/// Phase 4C.2 §2.
///
/// `async` only for one reason: a user-saved runtime server URL (Settings
/// → Server Connection, see ServerSettingsScreen) must be loaded from
/// [ServerConfigStorage] and applied to [ApiConfig] BEFORE [ApiClient] is
/// constructed below, so the very first Dio instance already points at
/// it — never the platform default for one frame and then a second,
/// rebuilt client. [ApiConfig.baseUrl]'s own precedence (a compile-time
/// `--dart-define=API_BASE_URL` always wins) means this load is a safe
/// no-op whenever that flag was supplied; see that getter for the
/// authoritative precedence order.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final serverConfigStorage = ServerConfigStorage();
  ApiConfig.setRuntimeBaseUrl(await serverConfigStorage.readBaseUrl());

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authRepository = AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
  final authProvider = AuthProvider(authRepository: authRepository);

  // A 401 on any authenticated request (expired/revoked token) clears
  // local session state through the SAME path a manual logout uses — see
  // AuthProvider.forceLogout()'s docblock for why this can't loop.
  apiClient.onUnauthorized = () => authProvider.forceLogout();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        // Exposed directly (not just via the repositories below) so
        // ServerSettingsScreen can read/test/update the live connection —
        // the one shared instance every repository already uses.
        Provider<ApiClient>.value(value: apiClient),
        Provider<ServerConfigStorage>.value(value: serverConfigStorage),
        Provider<ProfileRepository>.value(value: ProfileRepository(apiClient)),
        Provider<CustomerDashboardRepository>.value(value: CustomerDashboardRepository(apiClient)),
        Provider<CommunityImpactRepository>.value(value: CommunityImpactRepository(apiClient)),
        Provider<CustomerPickupRepository>.value(value: CustomerPickupRepository(apiClient)),
        Provider<CustomerCatalogueRepository>.value(value: CustomerCatalogueRepository(apiClient)),
        Provider<CustomerRecyclingCentreRepository>.value(value: CustomerRecyclingCentreRepository(apiClient)),
        Provider<CustomerRewardRepository>.value(value: CustomerRewardRepository(apiClient)),
        Provider<CustomerAddressRepository>.value(value: CustomerAddressRepository(apiClient)),
        Provider<CustomerPickupBookingRepository>.value(value: CustomerPickupBookingRepository(apiClient)),
        // Rider (Phase R1, read-only) — same shared ApiClient.
        Provider<RiderDashboardRepository>.value(value: RiderDashboardRepository(apiClient)),
        Provider<RiderPickupRepository>.value(value: RiderPickupRepository(apiClient)),
        Provider<RiderProfileRepository>.value(value: RiderProfileRepository(apiClient)),
        Provider<RiderLocationRepository>.value(value: RiderLocationRepository(apiClient)),
      ],
      child: const EcoXchangeApp(),
    ),
  );
}
