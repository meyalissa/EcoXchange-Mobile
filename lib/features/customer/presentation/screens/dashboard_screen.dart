import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/eco_hero_header.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/models/item.dart';
import '../../data/models/pickup_summary.dart';
import '../providers/dashboard_provider.dart';
import '../providers/item_catalogue_provider.dart';
import '../providers/reward_provider.dart';
import '../widgets/pickup_status_style.dart';
import 'item_detail_screen.dart';
import 'pickup_detail_screen.dart';

/// EcoXchange Mobile — Customer Home, aligned to the 01_customer_home design:
/// greeting hero with the EcoXchange Wallet, "Your Impact This Month",
/// the active pickup and recyclable items.
///
/// Every figure is real:
///   * wallet balance — `GET /customer/rewards` (`reward_balance`);
///   * lifetime earned / weight recycled — `GET /customer/dashboard` totals;
///   * this month — the dashboard's `monthly_weight_kg` /
///     `monthly_completed_pickups` (completions in the current calendar month).
/// Deliberately NOT shown (no backend data or agreed factor): reward points,
/// membership tier, trees saved, CO₂.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onSeeAllItems});

  /// Opens the full Items Guide.
  final VoidCallback onSeeAllItems;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
      final rewards = context.read<RewardProvider>();
      if (rewards.balance == null && !rewards.isLoading) rewards.load();
      final catalogue = context.read<ItemCatalogueProvider>();
      if (catalogue.items.isEmpty && !catalogue.isLoading) catalogue.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        final rewards = context.read<RewardProvider>();
        await Future.wait([provider.refresh(), rewards.refresh()]);
      },
      child: AsyncStateView<DashboardData>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.data,
        onRetry: provider.load,
        builder: (context, data) => _HomeContent(data: data, onSeeAllItems: widget.onSeeAllItems),
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 18) return 'Good Afternoon';
  return 'Good Evening';
}

String _kg(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.onSeeAllItems});

  final DashboardData data;
  final VoidCallback onSeeAllItems;

  @override
  Widget build(BuildContext context) {
    // Nullable: the frame between logout() and the router swapping screens.
    final userName = context.watch<AuthProvider>().user?.name ?? '';
    final rewardBalance = context.watch<RewardProvider>().balance;
    final items = context.watch<ItemCatalogueProvider>().items;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // ── Greeting + wallet ──────────────────────────────────────────────
        GradientHeader(
          gradient: AppColors.homeHeroGradient,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()} 👋', style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(userName, style: AppTheme.displayFont(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                  _Avatar(name: userName),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                key: const Key('home-wallet'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.r24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ECOXCHANGE WALLET', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                    const SizedBox(height: 8),
                    Text(
                      rewardBalance != null ? 'RM ${rewardBalance.toStringAsFixed(2)}' : '—',
                      style: AppTheme.displayFont(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Flexible(child: _WalletStat(label: 'LIFETIME EARNED', value: 'RM ${data.totalRewardsEarned.toStringAsFixed(2)}')),
                        Container(width: 1, height: 34, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 18)),
                        Flexible(child: _WalletStat(label: 'WEIGHT RECYCLED', value: '${_kg(data.totalWeightKg)} kg')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Your impact this month ─────────────────────────────────────────
        if (data.monthlyWeightKg != null && data.monthlyCompletedPickups != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _ImpactCard(weightKg: data.monthlyWeightKg!, pickups: data.monthlyCompletedPickups!),
          ),

        // ── Active pickup ──────────────────────────────────────────────────
        if (data.activePickup != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ActivePickupBanner(pickup: data.activePickup!),
          ),

        // ── Recyclable items ───────────────────────────────────────────────
        if (items.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: SectionTitleRow(title: 'Recyclable Items', actionLabel: 'See All', onAction: onSeeAllItems),
          ),
          SizedBox(
            height: 132,
            child: ListView.separated(
              key: const Key('home-items'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length > 10 ? 10 : items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _ItemCard(item: items[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 3),
          ),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }
}

/// "Your Impact This Month" — only the two real monthly figures.
class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.weightKg, required this.pickups});

  final double weightKg;
  final int pickups;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-impact'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2D4422), AppColors.green700]),
        borderRadius: BorderRadius.circular(AppRadii.r24),
        boxShadow: AppShadows.sh2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('YOUR IMPACT THIS MONTH', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
              const Text('🌱', style: TextStyle(fontSize: 30)),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              children: weightKg > 0
                  ? [
                      const TextSpan(text: 'You recycled '),
                      TextSpan(text: '${_kg(weightKg)} kg', style: const TextStyle(color: AppColors.green200)),
                      const TextSpan(text: ' this month'),
                    ]
                  : [const TextSpan(text: 'No completed pickups yet this month')],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(child: _ImpactStat(value: _kg(weightKg), label: 'kg Recycled')),
              const SizedBox(width: 28),
              Flexible(child: _ImpactStat(value: '$pickups', label: 'Pickups Done')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppTheme.displayFont(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.green200))),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// The amber "Active Pickup" banner (Home and Pickup Hub). Shows the real
/// assigned rider and status; no ETA (none exists in the API).
class ActivePickupBanner extends StatelessWidget {
  const ActivePickupBanner({super.key, required this.pickup, this.onDark = false});

  final PickupSummary pickup;

  /// Pickup Hub shows it inside the green hero (translucent card).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final style = PickupStatusStyle.forStatus(pickup.status);
    final riderName = pickup.assignedRiderName;
    final subtitle = [
      if (onDark) pickup.reference,
      if (riderName != null) 'Rider $riderName',
      style.label,
    ].join(' · ');

    return GestureDetector(
      key: const Key('active-pickup'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: onDark ? null : const LinearGradient(colors: [AppColors.goldLight, Color(0xFFFDE68A)]),
          color: onDark ? Colors.white.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(AppRadii.r20),
          border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF5D080), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(AppRadii.r12)),
              child: const Icon(Icons.access_time, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onDark ? '${pickup.reference} · Active' : 'Active Pickup',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: onDark ? Colors.white : const Color(0xFF7B4F00)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    onDark ? [if (riderName != null) 'Rider $riderName', style.label].join(' · ') : subtitle,
                    style: TextStyle(fontSize: 13, color: onDark ? Colors.white70 : const Color(0xFF9B6800)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: onDark ? Colors.white70 : const Color(0xFF9B6800)),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: EcoCard(
        padding: const EdgeInsets.all(12),
        borderRadius: AppRadii.r20,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.r8),
              child: item.image != null
                  ? AppNetworkImage(
                      url: item.image!,
                      height: 44,
                      width: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.recycling_outlined, color: AppColors.n300, size: 34),
                    )
                  : const Icon(Icons.recycling_outlined, color: AppColors.n300, size: 34),
            ),
            const SizedBox(height: 8),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800)),
            if (item.preliminaryBasePricePerKg != null)
              Text('RM ${item.preliminaryBasePricePerKg!.toStringAsFixed(2)}/kg', style: const TextStyle(fontSize: 11, color: AppColors.green600)),
          ],
        ),
      ),
    );
  }
}
