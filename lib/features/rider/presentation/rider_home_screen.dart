import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/eco_bottom_nav.dart';
import '../data/repositories/rider_dashboard_repository.dart';
import '../data/repositories/rider_location_repository.dart';
import '../data/repositories/rider_pickup_repository.dart';
import '../data/repositories/rider_profile_repository.dart';
import 'providers/rider_dashboard_provider.dart';
import 'providers/rider_pickup_list_provider.dart';
import 'providers/rider_profile_provider.dart';
import 'providers/rider_tasks_provider.dart';
import 'rider_location_sender.dart';
import 'screens/rider_dashboard_screen.dart';
import 'screens/rider_job_history_screen.dart';
import 'screens/rider_profile_screen.dart';
import 'screens/rider_route_screen.dart';
import 'screens/rider_tasks_screen.dart';

/// EcoXchange Mobile — Rider application shell, aligned to the approved
/// design: Home | My Tasks | Route (raised centre button) | Job History |
/// Profile. Every tab draws its own green hero (or map), so there is no
/// shell app bar.
///
/// The screen-level ChangeNotifierProviders are created ONCE here and kept
/// alive across tab switches by the IndexedStack:
///   * RiderDashboardProvider — Home counters and current job;
///   * RiderTasksProvider — open jobs (My Tasks, Today's Schedule);
///   * RiderPickupListProvider — completed jobs, server-paginated (My Tasks
///     "Completed" and Job History);
///   * RiderProfileProvider — Profile and the history totals.
/// The Route tab is built only once it is first opened (it hosts a native
/// map view), and follows the current job unless Home's "View Route" picked
/// one.
class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key, this.routeMapBuilder = defaultRouteMapBuilder, this.locationSender});

  /// Injectable so widget tests never create the native map view.
  final RouteMapBuilder routeMapBuilder;

  /// Injectable so widget tests never touch real GPS/HTTP — defaults to a
  /// real [RiderLocationSender] built from the shared [RiderLocationRepository].
  final RiderLocationSender? locationSender;

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;
  int? _routePickupId;
  bool _routeOpened = false;
  late final RiderLocationSender _locationSender;

  /// The last-seen "does an active assignment exist" flag, from
  /// RiderDashboardProvider.activeTask — the exact same accepted/en_route/
  /// collecting states the server itself treats as "active" (see
  /// RiderDashboardRepository's docblock). Used to resume sending
  /// correctly after the app returns to the foreground.
  bool _hasActiveAssignment = false;

  static const routeTab = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationSender = widget.locationSender ?? RiderLocationSender(context.read<RiderLocationRepository>());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSender.dispose();
    super.dispose();
  }

  /// Foreground-only, per the task's scope: stop sending the moment the
  /// app leaves the foreground, resume only once it's actually resumed AND
  /// there's still an active assignment. Never attempts to keep sending
  /// from the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_hasActiveAssignment) _locationSender.start();
    } else {
      _locationSender.stop();
    }
  }

  void _goToTab(int index) => setState(() {
        if (index == routeTab) {
          _routePickupId = null; // the Route tab follows the current job
          _routeOpened = true;
        }
        _tabIndex = index;
      });

  void _viewRoute(int pickupId) => setState(() {
        _routePickupId = pickupId;
        _routeOpened = true;
        _tabIndex = routeTab;
      });

  /// After any confirmed action, every list that shows job state re-reads.
  void _refreshAll(BuildContext context) {
    context.read<RiderDashboardProvider>().refresh();
    context.read<RiderTasksProvider>().refresh();
    context.read<RiderPickupListProvider>().refresh();
    context.read<RiderProfileProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RiderDashboardProvider(context.read<RiderDashboardRepository>())),
        ChangeNotifierProvider(create: (context) => RiderTasksProvider(context.read<RiderPickupRepository>())),
        ChangeNotifierProvider(
          create: (context) => RiderPickupListProvider(context.read<RiderPickupRepository>())..setStatusFilter('completed'),
        ),
        ChangeNotifierProvider(create: (context) => RiderProfileProvider(context.read<RiderProfileRepository>())),
      ],
      child: Builder(
        builder: (context) {
          final dashboard = context.watch<RiderDashboardProvider>().data;
          final routeId = _routePickupId ?? dashboard?.activeTask?.id ?? dashboard?.nextPickup?.id;

          // Sync the GPS sender to whether an active assignment currently
          // exists -- start()/stop() are both idempotent, so this is safe
          // to re-evaluate on every rebuild rather than needing its own
          // didUpdateWidget-style plumbing.
          _hasActiveAssignment = dashboard?.activeTask != null;
          if (_hasActiveAssignment) {
            _locationSender.start();
          } else {
            _locationSender.stop();
          }

          return Scaffold(
            backgroundColor: AppColors.n50,
            body: IndexedStack(
              index: _tabIndex,
              children: [
                RiderDashboardScreen(onSeeAllPickups: () => _goToTab(1), onViewRoute: _viewRoute),
                RiderTasksScreen(onChanged: () => _refreshAll(context)),
                _routeOpened
                    ? RiderRouteScreen(
                        pickupId: routeId,
                        mapBuilder: widget.routeMapBuilder,
                        onChanged: () => _refreshAll(context),
                      )
                    : const SizedBox.shrink(),
                const RiderJobHistoryScreen(),
                const RiderProfileScreen(),
              ],
            ),
            bottomNavigationBar: EcoBottomNav(
              currentIndex: _tabIndex,
              onTap: _goToTab,
              centerIndex: routeTab,
              items: const [
                EcoNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
                EcoNavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: 'My Tasks'),
                EcoNavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Route'),
                EcoNavItem(icon: Icons.history, activeIcon: Icons.history, label: 'Job History'),
                EcoNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
              ],
            ),
          );
        },
      ),
    );
  }
}
