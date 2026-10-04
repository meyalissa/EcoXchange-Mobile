import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_hero_header.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../providers/rider_dashboard_provider.dart';
import '../providers/rider_pickup_list_provider.dart';
import '../providers/rider_profile_provider.dart';
import '../widgets/rider_task_card.dart';
import 'rider_pickup_detail_screen.dart';

enum _Range { all, today, month }

/// EcoXchange Mobile — Rider Job History (04_rider_history design).
///   * headline totals — `GET /rider/profile` stats (lifetime collections
///     and kg, this month) and `GET /rider/dashboard` (today);
///   * the list — completed pickups from `GET /rider/pickups?status=completed`
///     (server-paginated, "Load more");
///   * search and the Today / This Month chips filter the LOADED list by
///     reference / customer and by the pickup's scheduled date.
/// No ratings, average time or rankings: the backend records none.
class RiderJobHistoryScreen extends StatefulWidget {
  const RiderJobHistoryScreen({super.key, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  State<RiderJobHistoryScreen> createState() => _RiderJobHistoryScreenState();
}

class _RiderJobHistoryScreenState extends State<RiderJobHistoryScreen> {
  final _search = TextEditingController();
  _Range _range = _Range.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<RiderProfileProvider>();
      if (profile.profile == null && !profile.isLoading) profile.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<RiderPickupListProvider>().refresh(),
      context.read<RiderProfileProvider>().refresh(),
      context.read<RiderDashboardProvider>().refresh(),
    ]);
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<RiderPickupSummary> _filter(List<RiderPickupSummary> all) {
    final now = widget._clock();
    final today = _dateKey(now);
    final month = today.substring(0, 7);
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (_range == _Range.today && p.pickupDate != today) return false;
      if (_range == _Range.month && !(p.pickupDate ?? '').startsWith(month)) return false;
      if (q.isEmpty) return true;
      return p.reference.toLowerCase().contains(q) || (p.customerName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<RiderPickupListProvider>();
    final profile = context.watch<RiderProfileProvider>().profile;
    final dashboard = context.watch<RiderDashboardProvider>().data;
    final shown = _filter(list.pickups);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: EcoHeroHeader(
              subtitle: 'Collection History',
              title: profile == null ? 'Job History' : '${profile.totalCompleted} Collection${profile.totalCompleted == 1 ? '' : 's'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile != null)
                    Text('All time · ${profile.totalWeightKg.toStringAsFixed(1)} kg total', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 14),
                  Row(
                    key: const Key('history-summary'),
                    children: [
                      _Summary(value: dashboard == null ? '—' : '${dashboard.completedToday}', label: 'Today'),
                      const SizedBox(width: 10),
                      _Summary(value: profile == null ? '—' : '${profile.completedThisMonth}', label: 'This Month'),
                      const SizedBox(width: 10),
                      _Summary(value: dashboard == null ? '—' : '${dashboard.weightTodayKg.toStringAsFixed(1)} kg', label: 'Collected Today'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                key: const Key('history-search'),
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search by reference or customer',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.n0,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.rFull), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final r in _Range.values)
                    ChoiceChip(
                      key: Key('history-filter-${r.name}'),
                      label: Text(switch (r) { _Range.all => 'All', _Range.today => 'Today', _Range.month => 'This Month' }),
                      selected: _range == r,
                      onSelected: (_) => setState(() => _range = r),
                    ),
                ],
              ),
            ),
          ),
          if (list.pagination == null || (list.error != null && list.pickups.isEmpty))
            SliverFillRemaining(
              hasScrollBody: false,
              child: AsyncStateView<bool>(isLoading: list.isLoading, error: list.error, data: null, onRetry: list.load, builder: (_, _) => const SizedBox()),
            )
          else if (shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  list.pickups.isEmpty ? 'No completed collections yet.' : 'No collections match this filter.',
                  key: const Key('history-empty'),
                  style: const TextStyle(color: AppColors.n600),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => RiderTaskCard(
                  key: Key('history-${shown[i].id}'),
                  pickup: shown[i],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: shown[i].id))),
                ),
              ),
            ),
          if (list.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: OutlinedButton(
                  key: const Key('history-load-more'),
                  onPressed: list.isLoadingMore ? null : list.loadMore,
                  child: Text(list.isLoadingMore ? 'Loading…' : 'Load more'),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadii.r16)),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
