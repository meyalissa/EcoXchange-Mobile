import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../data/models/pickup_summary.dart';
import '../../data/repositories/customer_pickup_repository.dart';
import '../providers/pickup_list_provider.dart';
import '../widgets/pickup_summary_card.dart';
import 'pickup_detail_screen.dart';

/// EcoXchange Mobile — "My Recycling History", reached from the Community
/// Impact screen's personal section.
///
/// Reuses the existing `PickupListProvider`/`CustomerPickupRepository`
/// (GET /customer/pickups?status=completed) and `PickupSummaryCard` —
/// exactly the same data this app already uses for Pickup Hub/My Pickups —
/// rather than a new endpoint or a new list widget. Fixed to
/// status=completed with no filter chips: unlike the general My Pickups
/// screen, this view's whole purpose is "what have I actually recycled",
/// so pending/cancelled pickups are deliberately never shown here.
class PersonalRecyclingHistoryScreen extends StatelessWidget {
  const PersonalRecyclingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PickupListProvider(context.read<CustomerPickupRepository>())..setStatusFilter('completed'),
      child: const Scaffold(
        backgroundColor: AppColors.n50,
        appBar: EcoAppBar(title: 'My Recycling History'),
        body: _HistoryBody(),
      ),
    );
  }
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody();

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickupListProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: AsyncStateView<List<PickupSummary>>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.pickups,
        isEmpty: provider.pickups.isEmpty,
        emptyMessage: 'No completed pickups yet. Once a pickup is collected and verified, it will appear here.',
        emptyIcon: Icons.recycling_outlined,
        onRetry: provider.load,
        builder: (context, pickups) => ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id))),
            );
          },
        ),
      ),
    );
  }
}
