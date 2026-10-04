import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/eco_hero_header.dart';
import '../../data/models/pickup_summary.dart';
import '../providers/dashboard_provider.dart';
import '../providers/pickup_list_provider.dart';
import '../widgets/pickup_summary_card.dart';
import 'booking/pickup_booking_screen.dart';
import 'dashboard_screen.dart' show ActivePickupBanner;
import 'pickup_detail_screen.dart';
import 'pickup_list_screen.dart';

/// EcoXchange Mobile — Customer Pickup Hub (02_customer_pickup design): the
/// active pickup, "Request New Pickup" (the existing booking flow) and the
/// three most recent pickups, with "View All" opening the existing full,
/// filterable My Pickups list. Data: `GET /customer/dashboard`
/// (active pickup) and `GET /customer/pickups` (recent).
class PickupHubScreen extends StatefulWidget {
  const PickupHubScreen({super.key});

  @override
  State<PickupHubScreen> createState() => _PickupHubScreenState();
}

class _PickupHubScreenState extends State<PickupHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = context.read<PickupListProvider>();
      if (list.pickups.isEmpty && !list.isLoading) list.load();
      final dashboard = context.read<DashboardProvider>();
      if (dashboard.data == null && !dashboard.isLoading) dashboard.load();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<PickupListProvider>().refresh(), context.read<DashboardProvider>().refresh()]);
  }

  void _requestPickup() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PickupBookingScreen(onBookingComplete: _refresh)));
  }

  /// The full list is pushed as its own route, so it gets the shell's
  /// existing provider explicitly (no second list state).
  void _viewAll() {
    final provider = context.read<PickupListProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const Scaffold(
            backgroundColor: AppColors.n50,
            appBar: EcoAppBar(title: 'My Pickups'),
            body: PickupListScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<PickupListProvider>();
    final active = context.watch<DashboardProvider>().data?.activePickup;
    // Newest first, as the API returns them (the same list View All shows).
    final recent = list.pickups.take(3).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          EcoHeroHeader(
            subtitle: 'Your Pickups',
            title: 'Pickup Hub',
            trailing: HeroIconButton(icon: Icons.history, tooltip: 'All pickups', onTap: _viewAll),
            child: active != null ? ActivePickupBanner(pickup: active, onDark: true) : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: EcoButton(
              key: const Key('request-new-pickup'),
              label: 'Request New Pickup',
              icon: Icons.add,
              fullWidth: true,
              onPressed: _requestPickup,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: SectionTitleRow(title: 'Recent Pickups', actionLabel: 'View All', onAction: _viewAll),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: list.pickups.isEmpty || list.isLoading
                ? ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 120),
                    child: AsyncStateView<List<PickupSummary>>(
                      isLoading: list.isLoading,
                      error: list.error,
                      data: list.pickups,
                      isEmpty: list.pickups.isEmpty,
                      emptyMessage: 'You have no pickups yet.',
                      emptyIcon: Icons.local_shipping_outlined,
                      onRetry: list.load,
                      builder: (_, _) => const SizedBox.shrink(),
                    ),
                  )
                : EcoCard(
                    key: const Key('recent-pickups'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    borderRadius: AppRadii.r20,
                    child: Column(
                      children: [
                        for (final pickup in recent) ...[
                          if (pickup != recent.first) const Divider(height: 1, color: AppColors.n100),
                          PickupSummaryCard(
                            pickup: pickup,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id))),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
