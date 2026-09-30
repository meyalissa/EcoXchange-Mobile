import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/eco_app_bar.dart';
import '../../../core/widgets/eco_bottom_nav.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/repositories/customer_catalogue_repository.dart';
import '../data/repositories/customer_dashboard_repository.dart';
import '../data/repositories/customer_pickup_repository.dart';
import '../data/repositories/customer_recycling_centre_repository.dart';
import '../data/repositories/customer_reward_repository.dart';
import 'providers/dashboard_provider.dart';
import 'providers/item_catalogue_provider.dart';
import 'providers/pickup_list_provider.dart';
import 'providers/recycling_centre_list_provider.dart';
import 'providers/reward_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/item_list_screen.dart';
import 'screens/pickup_list_screen.dart';
import 'screens/recycling_centre_list_screen.dart';
import 'screens/reward_screen.dart';

/// EcoXchange Mobile — Customer application shell (Phase 4C.2 §12,
/// bottom-nav restyled Phase 4C.3 §2/§11). Bottom-tab navigation over the
/// 5 real read features: Home (Dashboard), Pickups, Items, Centres,
/// Rewards — the design's Home/Pickup/AI-Scan/Rewards/Profile tabs adapted
/// onto the features that actually exist (approved decision, Phase 4C.3
/// kickoff) rather than fabricating AI Scan/Profile screens. Detail
/// screens (pickup/item/centre) are pushed from their respective list
/// screens, not part of this tab bar.
///
/// The 5 screen-level ChangeNotifierProviders are created ONCE here (each
/// reads its repository from the ancestor MultiProvider registered in
/// main.dart) and kept alive across tab switches via IndexedStack, so
/// switching tabs never re-fetches data that's already loaded.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tabIndex = 0;

  static const _titles = ['Dashboard', 'My Pickups', 'Items Guide', 'Recycling Centres', 'Rewards'];

  /// Dashboard and Rewards render their own full-bleed gradient hero
  /// header — including the screen title — so the shell's own app bar
  /// would just duplicate it. Pickups/Items/Centres still rely on the
  /// shell for their title bar.
  bool _hasOwnHeader(int index) => index == 0 || index == 4;

  void _goToTab(int index) => setState(() => _tabIndex = index);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DashboardProvider(context.read<CustomerDashboardRepository>())),
        ChangeNotifierProvider(create: (context) => PickupListProvider(context.read<CustomerPickupRepository>())),
        ChangeNotifierProvider(create: (context) => ItemCatalogueProvider(context.read<CustomerCatalogueRepository>())),
        ChangeNotifierProvider(create: (context) => RecyclingCentreListProvider(context.read<CustomerRecyclingCentreRepository>())),
        ChangeNotifierProvider(create: (context) => RewardProvider(context.read<CustomerRewardRepository>())),
      ],
      child: Scaffold(
        appBar: _hasOwnHeader(_tabIndex)
            ? null
            : EcoAppBar(
                title: _titles[_tabIndex],
                showBackButton: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    tooltip: 'Log out',
                    onPressed: () => context.read<AuthProvider>().logout(),
                  ),
                ],
              ),
        body: IndexedStack(
          index: _tabIndex,
          children: [
            DashboardScreen(onSeeAllItems: () => _goToTab(2)),
            const PickupListScreen(),
            const ItemListScreen(),
            const RecyclingCentreListScreen(),
            const RewardScreen(),
          ],
        ),
        bottomNavigationBar: EcoBottomNav(
          currentIndex: _tabIndex,
          onTap: _goToTab,
          items: const [
            EcoNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
            EcoNavItem(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Pickups'),
            EcoNavItem(icon: Icons.recycling_outlined, activeIcon: Icons.recycling, label: 'Items'),
            EcoNavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Centres'),
            EcoNavItem(icon: Icons.savings_outlined, activeIcon: Icons.savings, label: 'Rewards'),
          ],
        ),
      ),
    );
  }
}
