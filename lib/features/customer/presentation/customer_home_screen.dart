import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/eco_app_bar.dart';
import '../../../core/widgets/eco_bottom_nav.dart';
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
import 'screens/customer_profile_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/item_list_screen.dart';
import 'screens/pickup_hub_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/scan/ai_scan_hub_screen.dart';

/// EcoXchange Mobile — Customer application shell, aligned to the approved
/// design: Home | Pickup | AI Scan (raised centre button) | Rewards |
/// Profile. Every tab draws its own green hero, so there is no shell app
/// bar. Items Guide and Recycling Centres are reached from Home ("See All")
/// and Profile.
///
/// The screen-level ChangeNotifierProviders are created ONCE here (each
/// from a repository registered in main.dart) and kept alive across tab
/// switches via IndexedStack, so switching tabs never re-fetches data that
/// is already loaded. Pushed routes that need one of them receive it via
/// ChangeNotifierProvider.value.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tabIndex = 0;

  static const aiScanTab = 2;

  void _goToTab(int index) => setState(() => _tabIndex = index);

  void _openItemsGuide(BuildContext context) {
    final provider = context.read<ItemCatalogueProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const Scaffold(backgroundColor: AppColors.n50, appBar: EcoAppBar(title: 'Items Guide'), body: ItemListScreen()),
        ),
      ),
    );
  }

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
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.n50,
          body: IndexedStack(
            index: _tabIndex,
            children: [
              DashboardScreen(onSeeAllItems: () => _openItemsGuide(context)),
              const PickupHubScreen(),
              const AiScanHubScreen(),
              const RewardScreen(),
              const CustomerProfileScreen(),
            ],
          ),
          bottomNavigationBar: EcoBottomNav(
            currentIndex: _tabIndex,
            onTap: _goToTab,
            centerIndex: aiScanTab,
            items: const [
              EcoNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
              EcoNavItem(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Pickup'),
              EcoNavItem(icon: Icons.center_focus_strong_outlined, activeIcon: Icons.center_focus_strong, label: 'AI Scan'),
              EcoNavItem(icon: Icons.star_border, activeIcon: Icons.star, label: 'Rewards'),
              EcoNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
