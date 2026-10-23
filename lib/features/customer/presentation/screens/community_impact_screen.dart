import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/trend_line_chart.dart';
import '../../data/models/community_impact.dart';
import '../../data/models/personal_impact.dart';
import '../../data/repositories/community_impact_repository.dart';
import '../providers/community_impact_provider.dart';
import '../providers/personal_impact_provider.dart';
import 'community_leaderboard_screen.dart';
import 'personal_recycling_history_screen.dart';

const _periodOptions = {
  'this_week': 'This Week',
  'this_month': 'This Month',
  'this_year': 'This Year',
  'all_time': 'All Time',
};

String _kg(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

/// EcoXchange Mobile — Community Recycling Impact (Phase 2 mobile parity).
///
/// Every figure comes from `GET /customer/community-impact`
/// (`CommunityImpactProvider` → `CommunityImpactRepository`), the exact
/// same `CommunityImpactService` the web Community Impact page uses —
/// never recalculated or hardcoded here. Aggregate-only: no other
/// customer's identity, address or pickup history is ever shown, and a
/// scope with fewer than [CommunityImpactSummary.suppressionThreshold]
/// distinct participants is shown as suppressed rather than with an exact
/// figure (server-enforced — this screen just reflects it honestly).
///
/// Self-contained, exactly like [CommunityLeaderboardScreen]: builds its
/// own [CommunityImpactProvider] from `context.read<CommunityImpactRepository>()`
/// using the `create` callback's OWN context (never one captured from the
/// caller's widget) — the same pattern every other pushed screen in this
/// app uses (e.g. `RiderPickupDetailScreen`). A caller just pushes the
/// plain widget; it never needs to know what this screen depends on or
/// wrap it in any provider itself. Fixes a `ProviderNotFoundException`
/// that occurred when the previous version instead built this provider at
/// the Dashboard's push call site.
class CommunityImpactScreen extends StatelessWidget {
  const CommunityImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CommunityImpactProvider(context.read<CommunityImpactRepository>())),
        // Deliberately a separate provider/request from the community one
        // above — this is always the logged-in customer's own data, never
        // mixed into or derived from the community aggregates.
        ChangeNotifierProvider(create: (context) => PersonalImpactProvider(context.read<CommunityImpactRepository>())),
      ],
      child: Scaffold(
        backgroundColor: AppColors.n50,
        appBar: const EcoAppBar(title: 'Community Impact'),
        body: const _CommunityImpactBody(),
      ),
    );
  }
}

class _CommunityImpactBody extends StatefulWidget {
  const _CommunityImpactBody();

  @override
  State<_CommunityImpactBody> createState() => _CommunityImpactBodyState();
}

class _CommunityImpactBodyState extends State<_CommunityImpactBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityImpactProvider>().load();
      context.read<PersonalImpactProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityImpactProvider>();
    final personal = context.watch<PersonalImpactProvider>();

    return RefreshIndicator(
      onRefresh: () => Future.wait([provider.refresh(), personal.refresh()]),
      child: AsyncStateView<CommunityImpactSummary>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.data,
        onRetry: provider.load,
        builder: (context, data) => _Content(data: data, provider: provider, personal: personal),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.provider, required this.personal});

  final CommunityImpactSummary data;
  final CommunityImpactProvider provider;
  final PersonalImpactProvider personal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('community-impact-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _PersonalImpactSection(provider: personal),
        const SizedBox(height: 16),

        // Short section heading in place of the former explanatory
        // paragraph ("Aggregate recycling activity across ... — a shared
        // community total, not your personal dashboard.") — "Community
        // Totals" rather than the page's own AppBar title ("Community
        // Impact"), so the two aren't the same text repeated twice in a
        // row. The location/period already shown in the filters right
        // below make a subtitle unnecessary.
        const Text('Community Totals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
        const SizedBox(height: 10),

        // ── Geographical + period filters ──────────────────────────────
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _LocationDropdown(
                    hint: 'Malaysia-wide',
                    value: data.state,
                    options: data.availableStates,
                    onChanged: provider.setState,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _LocationDropdown(
                    hint: 'All areas',
                    value: data.area,
                    options: data.availableAreas,
                    onChanged: provider.setArea,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              const Text('PERIOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
              const SizedBox(height: 6),
              // A Wrap, not the shared horizontal-scrolling FilterChipRow
              // (used elsewhere for longer option lists): with only 4
              // period options, a single row when the width allows it,
              // wrapping cleanly to a second row otherwise, means every
              // option is always fully visible without relying on a
              // horizontal swipe that a vertically scrolling page can
              // swallow.
              _PeriodChips(
                selected: data.period,
                onSelected: (period) {
                  provider.setPeriod(period);
                  // Keeps the personal section in step with the one period
                  // selector on this screen, instead of adding a second one.
                  personal.setPeriod(period);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (data.suppressed)
          _SuppressedCard(threshold: data.suppressionThreshold, locationLabel: data.locationLabel)
        else if (data.completedPickups == null || data.completedPickups == 0)
          _EmptyCard(locationLabel: data.locationLabel)
        else
          ..._buildStats(data),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommunityLeaderboardScreen()),
            ),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Community Leaderboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green700,
              side: const BorderSide(color: AppColors.green300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r16)),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStats(CommunityImpactSummary data) {
    return [
      Row(
        children: [
          Expanded(child: _StatCard(label: 'Weight (kg)', value: _kg(data.totalWeightKg!), color: AppColors.green700)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Pickups', value: '${data.completedPickups}', color: AppColors.teal)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Customers', value: '${data.participatingCustomers}', color: AppColors.gold)),
        ],
      ),
      const SizedBox(height: 12),
      EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MONTHLY TREND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            // Location dropped here — it's already shown just above, in
            // the LOCATION filter, so repeating it in every section's
            // subtitle added length without adding information.
            const Text(
              'Last 6 months (kg)',
              style: TextStyle(fontSize: 11, color: AppColors.n400),
            ),
            const SizedBox(height: 14),
            TrendLineChart(labels: data.trendLabels, values: data.trendData),
          ],
        ),
      ),
      const SizedBox(height: 12),
      EcoCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LEADING AREAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            const Text('Areas with too few participating customers are not shown', style: TextStyle(fontSize: 11, color: AppColors.n400)),
            const SizedBox(height: 8),
            if (data.areaComparison.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Not enough areas with sufficient activity to compare yet.', style: TextStyle(fontSize: 12.5, color: AppColors.n400)),
              )
            else
              ...data.areaComparison.map((row) => _AreaRow(row: row)),
          ],
        ),
      ),
    ];
  }
}

/// "My Environmental Impact" — the logged-in customer's own figures only.
/// Clearly, visually separated (its own tinted card, own heading) from the
/// community content below it, and never shares a loading/error state with
/// it — a failure to load the community aggregate must not hide this
/// section, and vice versa.
class _PersonalImpactSection extends StatelessWidget {
  const _PersonalImpactSection({required this.provider});

  final PersonalImpactProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('personal-impact-section'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.pickupHeaderGradient,
        borderRadius: BorderRadius.circular(AppRadii.r16),
      ),
      child: AsyncStateView<PersonalImpactSummary>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.data,
        onRetry: provider.load,
        builder: (context, data) => _PersonalImpactContent(data: data),
      ),
    );
  }
}

class _PersonalImpactContent extends StatelessWidget {
  const _PersonalImpactContent({required this.data});

  final PersonalImpactSummary data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.eco_outlined, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'MY ENVIRONMENTAL IMPACT',
                      maxLines: 2,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (data.completedPickups == 0)
                const Text('You have no completed pickups for this period yet.', style: TextStyle(fontSize: 12.5, color: Colors.white70))
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PersonalStat(label: 'Recycled', value: '${_kg(data.totalWeightKg)} kg')),
                    const SizedBox(width: 8),
                    Expanded(child: _PersonalStat(label: 'Pickups', value: '${data.completedPickups}')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PersonalStat(
                        label: 'CO₂e Avoided',
                        badge: 'est.',
                        value: '${_kg(data.environmental.totalCo2eKg)} kg',
                      ),
                    ),
                  ],
                ),
                // The WARM-version breakdown and unsupported-material note
                // used to always render here as two paragraphs of running
                // text. Moved into a tap-to-open sheet (_CalculationInfoSheet)
                // so the card itself stays a glance-able set of 3 numbers —
                // the same underlying data (factor version, per-material
                // breakdown, unsupported categories, source) is preserved
                // there in full, never dropped.
                const SizedBox(height: 10),
                _CalculationInfoLink(environmental: data.environmental),
              ],
            ],
          ),
        ),
        // ── Footer — its own slim, clearly-tappable row, not the whole card ──
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalRecyclingHistoryScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.25)))),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('View My Recycling History', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonalStat extends StatelessWidget {
  const _PersonalStat({required this.label, required this.value, this.badge});

  final String label;
  final String value;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white))),
        const SizedBox(height: 3),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70)),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.r4)),
                child: Text(badge!, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The small "How is this calculated?" entry point that replaced the two
/// always-visible explanatory paragraphs. Opens [_CalculationInfoSheet] —
/// nothing about the underlying figures changes, only where their
/// explanation lives.
class _CalculationInfoLink extends StatelessWidget {
  const _CalculationInfoLink({required this.environmental});

  final PersonalEnvironmentalImpact environmental;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('calculation-info-link'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CalculationInfoSheet(environmental: environmental),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: const [
            Icon(Icons.info_outline, size: 13, color: Colors.white70),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'How is this calculated?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The CO₂e method explanation — moved here, in full, from the two
/// paragraphs that used to always render on the card: the factor version,
/// the per-material breakdown, the estimate disclaimer, the source, and —
/// just as importantly — the materials with no documented conversion
/// factor, named explicitly so excluded weight is never implied to be
/// zero-impact (same data as before, [PersonalEnvironmentalImpact], never
/// recalculated here).
class _CalculationInfoSheet extends StatelessWidget {
  const _CalculationInfoSheet({required this.environmental});

  final PersonalEnvironmentalImpact environmental;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Container(
            key: const Key('calculation-info-sheet'),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r20)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How is this calculated?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800)),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated using ${environmental.factorVersion} recycling factors. Estimates, not measured values.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.n500),
                  ),
                  if (environmental.breakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('SUPPORTED MATERIALS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
                    const SizedBox(height: 8),
                    ...environmental.breakdown.map(
                      (r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(r.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.n800))),
                            Text('${_kg(r.weightKg)} kg', style: const TextStyle(fontSize: 12.5, color: AppColors.n500)),
                            const SizedBox(width: 10),
                            Text('${_kg(r.co2eKg)} kg CO₂e', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.green700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (environmental.unsupportedCategories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('NOT YET SUPPORTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4)),
                    const SizedBox(height: 4),
                    const Text(
                      'Not counted in CO₂e above (no documented conversion factor yet). This does NOT mean these '
                      'materials have zero environmental impact.',
                      style: TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.n400),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      environmental.unsupportedCategories.map((r) => '${r.category} ${_kg(r.weightKg)}kg').join(', '),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.n700),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Source: ${environmental.source}', style: const TextStyle(fontSize: 11, color: AppColors.n400)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.green700,
                        side: const BorderSide(color: AppColors.green300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r16)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 4 period options, laid out with [Wrap] rather than the shared
/// horizontal-scrolling `FilterChipRow` used elsewhere in the app. Inside a
/// vertically-scrolling page, a horizontal list's swipe gesture competes
/// with the page's own scroll and the last chip can end up effectively
/// unreachable on a narrow phone; wrapping to a second row instead means
/// every option is always fully visible, with no scroll gesture needed at
/// all for just 4 short labels. Same pill visual treatment as
/// `FilterChipRow` so it still matches the rest of the app.
class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _periodOptions.entries.map((entry) {
        final isActive = entry.key == selected;
        return GestureDetector(
          onTap: () => onSelected(entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? AppColors.green500 : AppColors.n0,
              borderRadius: BorderRadius.circular(AppRadii.rFull),
              border: Border.all(color: isActive ? AppColors.green500 : AppColors.n200, width: 1.5),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.n600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({required this.hint, required this.value, required this.options, required this.onChanged});

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n200),
        borderRadius: BorderRadius.circular(AppRadii.r12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.n500)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.n500),
          style: const TextStyle(fontSize: 13, color: AppColors.n800, fontWeight: FontWeight.w600),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(hint)),
            ...options.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color))),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.n500),
          ),
        ],
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.row});

  final CommunityAreaRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(row.city, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800))),
          Text('${row.pickups} pickups', style: const TextStyle(fontSize: 12, color: AppColors.n400)),
          const SizedBox(width: 10),
          Text('${_kg(row.totalWeightKg)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green700)),
        ],
      ),
    );
  }
}

class _SuppressedCard extends StatelessWidget {
  const _SuppressedCard({required this.threshold, required this.locationLabel});

  final int threshold;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.shield_outlined, size: 28, color: AppColors.n300),
          const SizedBox(height: 10),
          const Text('Not enough activity to show yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n700)),
          const SizedBox(height: 6),
          Text(
            '$locationLabel currently has fewer than $threshold distinct participating customers for this period — '
            'figures are hidden to protect individual privacy. Try a wider area, a longer period, or Malaysia-wide.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.n400),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.locationLabel});

  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.recycling_outlined, size: 28, color: AppColors.n300),
          const SizedBox(height: 10),
          const Text('No completed recycling activity yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n700)),
          const SizedBox(height: 6),
          Text('$locationLabel has no completed pickups recorded for this period.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.n400)),
        ],
      ),
    );
  }
}
