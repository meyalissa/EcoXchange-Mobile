import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/filter_chip_row.dart';
import '../../data/models/community_leaderboard.dart';
import '../../data/repositories/community_impact_repository.dart';
import '../providers/community_leaderboard_provider.dart';

const _viewOptions = {
  'area': 'Area',
  'state': 'State',
  'participation': 'Participation',
};

const _periodOptions = {
  'this_week': 'This Week',
  'this_month': 'This Month',
  'this_year': 'This Year',
  'all_time': 'All Time',
};

String _kg(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

/// EcoXchange Mobile — Community Leaderboard (Phase 2 mobile parity).
///
/// Three distinct, clearly-labelled ranking views — never a blended
/// composite score — each fetched fresh from
/// `GET /customer/community-impact/leaderboard` (same
/// `CommunityImpactService` as the web Leaderboard page): 'area'/'state'
/// rank by verified weight, 'participation' ranks areas by distinct
/// customer count. A location below the suppression threshold is simply
/// absent from [CommunityLeaderboardResult.rankings] — the server already
/// removed it, this screen never re-adds or re-ranks anything client-side.
class CommunityLeaderboardScreen extends StatelessWidget {
  const CommunityLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CommunityLeaderboardProvider(context.read<CommunityImpactRepository>()),
      child: Scaffold(
        backgroundColor: AppColors.n50,
        appBar: const EcoAppBar(title: 'Community Leaderboard'),
        body: const _LeaderboardBody(),
      ),
    );
  }
}

class _LeaderboardBody extends StatefulWidget {
  const _LeaderboardBody();

  @override
  State<_LeaderboardBody> createState() => _LeaderboardBodyState();
}

class _LeaderboardBodyState extends State<_LeaderboardBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CommunityLeaderboardProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityLeaderboardProvider>();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(color: AppColors.n0, border: Border(bottom: BorderSide(color: AppColors.n100))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterChipRow(
                options: _viewOptions,
                selected: provider.view,
                onSelected: (v) => provider.setView(v ?? 'area'),
              ),
              const SizedBox(height: 10),
              FilterChipRow(
                options: _periodOptions,
                selected: provider.period,
                onSelected: (v) => provider.setPeriod(v ?? 'all_time'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: AsyncStateView<CommunityLeaderboardResult>(
              isLoading: provider.isLoading,
              error: provider.error,
              data: provider.data,
              onRetry: provider.load,
              builder: (context, data) => _RankingList(data: data),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({required this.data});

  final CommunityLeaderboardResult data;

  @override
  Widget build(BuildContext context) {
    final rankings = data.rankings;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          data.view == 'state'
              ? 'Leading states, by verified recycling weight for this period.'
              : data.view == 'participation'
                  ? 'Leading areas, by number of distinct participating customers.'
                  : 'Leading areas, by verified recycling weight for this period.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.n500),
        ),
        const SizedBox(height: 4),
        Text(
          'Locations with fewer than ${data.suppressionThreshold} distinct participating customers are not shown.',
          style: const TextStyle(fontSize: 11, color: AppColors.n400),
        ),
        if (data.includesDemoData) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.n500),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This ranking includes demonstration data seeded for development/testing purposes.',
                    style: TextStyle(fontSize: 11, color: AppColors.n500),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (rankings.isEmpty)
          EcoCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 28, color: AppColors.n300),
                const SizedBox(height: 10),
                Text(
                  'Not enough verified activity to rank ${data.view == "state" ? "states" : "areas"} for this period yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.n400),
                ),
              ],
            ),
          )
        else
          EcoCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < rankings.length; i++) ...[
                  _RankingRow(row: rankings[i], metric: data.metric),
                  if (i != rankings.length - 1) const Divider(height: 1, color: AppColors.n100),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.row, required this.metric});

  final CommunityLeaderboardRow row;
  final String metric;

  @override
  Widget build(BuildContext context) {
    final highlightWeight = metric == 'total_weight';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.rFull)),
            child: Text('#${row.rank}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(row.location, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.n800))),
                    if (row.hasDemoData) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.rFull)),
                        child: const Text('demo', style: TextStyle(fontSize: 9, color: AppColors.n500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${row.pickups} pickups · ${row.participants} customers', style: const TextStyle(fontSize: 11, color: AppColors.n400)),
              ],
            ),
          ),
          Text(
            highlightWeight ? '${_kg(row.totalWeightKg)} kg' : '${row.participants}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: highlightWeight ? AppColors.green700 : AppColors.teal),
          ),
        ],
      ),
    );
  }
}
