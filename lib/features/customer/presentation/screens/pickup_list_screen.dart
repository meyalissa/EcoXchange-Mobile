import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/filter_chip_row.dart';
import '../../data/models/pickup_summary.dart';
import '../providers/pickup_list_provider.dart';
import '../widgets/pickup_summary_card.dart';
import 'booking/pickup_booking_screen.dart';
import 'pickup_detail_screen.dart';

/// EcoXchange Mobile — My Pickups (Phase 4C.2 §7, restyled Phase 4C.3 to
/// match `pickup-history.html`). Server-paginated — never fetches the
/// whole dataset. Status filter is the real pickup_requests.status enum
/// PickupController::index() validates against; no unsupported filter
/// (e.g. free-text search — the design's search bar isn't backed by any
/// endpoint, so it's deliberately not reproduced) is offered. The
/// design's 3-stat strip (Total/Recycled/Earned) is likewise omitted here
/// — those real totals only exist on `/customer/dashboard`, and this
/// provider only ever holds one filtered, paginated page of results, so
/// summing it would misrepresent a total (see Dashboard for the real
/// figures, sourced honestly from the endpoint that actually returns them).
class PickupListScreen extends StatefulWidget {
  const PickupListScreen({super.key});

  @override
  State<PickupListScreen> createState() => _PickupListScreenState();
}

class _PickupListScreenState extends State<PickupListScreen> {
  final _scrollController = ScrollController();

  static const _statusOptions = <String?, String>{
    null: 'All',
    'pending': 'Pending',
    'approved': 'Approved',
    'assigned': 'Assigned',
    'collecting': 'Collecting',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PickupListProvider>().load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<PickupListProvider>().loadMore();
    }
  }

  /// The single entry point into the booking flow (Stage 3) — deliberately
  /// not duplicated anywhere else in the Customer app. Refreshes this
  /// already-loaded list on a successful booking via the same cross-tab-
  /// callback pattern the Dashboard's "See All Items" action uses (see
  /// `PickupBookingScreen`'s docblock) — a pushed route can't reach this
  /// provider directly, since it lives inside the tab shell's own
  /// `MultiProvider`, which the pushed route isn't a descendant of.
  void _requestNewPickup() {
    final provider = context.read<PickupListProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PickupBookingScreen(onBookingComplete: provider.refresh)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupListProvider>();

    return Stack(
      children: [
        _buildList(context, provider),
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: _NewPickupFab(onTap: _requestNewPickup),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, PickupListProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: AppColors.n0, border: Border(bottom: BorderSide(color: AppColors.n100))),
          child: FilterChipRow(
            options: _statusOptions,
            selected: provider.statusFilter,
            onSelected: provider.setStatusFilter,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: AsyncStateView<List<PickupSummary>>(
              isLoading: provider.isLoading,
              error: provider.error,
              data: provider.pickups,
              isEmpty: provider.pickups.isEmpty,
              emptyMessage: 'No pickups found for this filter.',
              emptyIcon: Icons.local_shipping_outlined,
              onRetry: provider.load,
              builder: (context, pickups) => Container(
                color: AppColors.n0,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 84),
                  itemCount: pickups.length + (provider.hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => index < pickups.length - 1 ? const Divider(height: 1, color: AppColors.n100) : const SizedBox.shrink(),
                  itemBuilder: (context, index) {
                    if (index >= pickups.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final pickup = pickups[index];
                    return PickupSummaryCard(
                      pickup: pickup,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewPickupFab extends StatelessWidget {
  const _NewPickupFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(gradient: AppColors.fabGradient, borderRadius: BorderRadius.circular(AppRadii.rFull), boxShadow: AppShadows.sh2),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text('Request Pickup', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
