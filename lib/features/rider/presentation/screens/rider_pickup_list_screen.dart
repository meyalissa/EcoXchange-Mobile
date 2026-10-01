import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/filter_chip_row.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../providers/rider_pickup_list_provider.dart';
import '../widgets/rider_pickup_card.dart';
import 'rider_pickup_detail_screen.dart';

/// EcoXchange Mobile — Rider "My Pickups": every pickup assigned to this
/// rider, newest first, server-paginated. The status filter is the real
/// pickup_requests.status enum Api\Rider\PickupController::index()
/// validates; `pending`/`approved` are left out because a pickup in those
/// states is not yet assigned to any rider.
class RiderPickupListScreen extends StatefulWidget {
  const RiderPickupListScreen({super.key});

  @override
  State<RiderPickupListScreen> createState() => _RiderPickupListScreenState();
}

class _RiderPickupListScreenState extends State<RiderPickupListScreen> {
  final _scrollController = ScrollController();

  static const _statusOptions = <String?, String>{
    null: 'All',
    'assigned': 'Assigned',
    'collecting': 'Collecting',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RiderPickupListProvider>().load());
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
      context.read<RiderPickupListProvider>().loadMore();
    }
  }

  void _openPickup(RiderPickupSummary pickup) {
    final provider = context.read<RiderPickupListProvider>();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: pickup.id)))
        .then((_) => provider.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderPickupListProvider>();

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
            child: AsyncStateView<List<RiderPickupSummary>>(
              isLoading: provider.isLoading,
              error: provider.error,
              data: provider.pickups,
              isEmpty: provider.pickups.isEmpty,
              emptyMessage: provider.statusFilter == null
                  ? 'No pickups have been assigned to you yet.'
                  : 'No pickups found for this filter.',
              emptyIcon: Icons.two_wheeler_outlined,
              onRetry: provider.load,
              builder: (context, pickups) => Container(
                color: AppColors.n0,
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pickups.length + (provider.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.n100),
                  itemBuilder: (context, i) {
                    if (i >= pickups.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return RiderPickupCard(pickup: pickups[i], onTap: () => _openPickup(pickups[i]));
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
