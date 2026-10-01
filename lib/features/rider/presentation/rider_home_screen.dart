import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/eco_app_bar.dart';
import '../../../core/widgets/eco_bottom_nav.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/repositories/rider_dashboard_repository.dart';
import '../data/repositories/rider_pickup_repository.dart';
import '../data/repositories/rider_profile_repository.dart';
import 'providers/rider_dashboard_provider.dart';
import 'providers/rider_pickup_list_provider.dart';
import 'providers/rider_profile_provider.dart';
import 'screens/rider_dashboard_screen.dart';
import 'screens/rider_pickup_list_screen.dart';
import 'screens/rider_profile_screen.dart';

/// EcoXchange Mobile — Rider application shell (Phase R1). Same structure
/// as CustomerHomeScreen: bottom-tab navigation over the real Rider read
/// endpoints — Home (`/rider/dashboard`), Pickups (`/rider/pickups`) and
/// Profile (`/rider/profile`). Pickup detail is pushed from Home/Pickups.
///
/// The screen-level ChangeNotifierProviders are created once here (each
/// from a repository registered in main.dart) and kept alive across tab
/// switches by the IndexedStack, so switching tabs never re-fetches.
/// Pickup state-changing actions are a later phase.
class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  int _tabIndex = 0;

  static const _titles = ['Home', 'My Pickups', 'My Profile'];

  /// Home renders its own gradient header (with greeting and logout), so
  /// the shell's app bar is only shown on the other tabs.
  bool _hasOwnHeader(int index) => index == 0;

  void _goToTab(int index) => setState(() => _tabIndex = index);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RiderDashboardProvider(context.read<RiderDashboardRepository>())),
        ChangeNotifierProvider(create: (context) => RiderPickupListProvider(context.read<RiderPickupRepository>())),
        ChangeNotifierProvider(create: (context) => RiderProfileProvider(context.read<RiderProfileRepository>())),
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
            RiderDashboardScreen(onSeeAllPickups: () => _goToTab(1)),
            const RiderPickupListScreen(),
            const RiderProfileScreen(),
          ],
        ),
        bottomNavigationBar: EcoBottomNav(
          currentIndex: _tabIndex,
          onTap: _goToTab,
          items: const [
            EcoNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
            EcoNavItem(icon: Icons.two_wheeler_outlined, activeIcon: Icons.two_wheeler, label: 'Pickups'),
            EcoNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
