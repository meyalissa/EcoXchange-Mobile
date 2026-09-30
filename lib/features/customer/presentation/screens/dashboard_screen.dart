import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/models/item.dart';
import '../../data/models/pickup_summary.dart';
import '../providers/dashboard_provider.dart';
import '../providers/item_catalogue_provider.dart';
import '../providers/reward_provider.dart';
import '../widgets/pickup_status_style.dart';
import '../widgets/pickup_summary_card.dart';
import 'item_detail_screen.dart';
import 'pickup_detail_screen.dart';
import 'scan/scan_classify_screen.dart';

/// EcoXchange Mobile — Customer Dashboard (Phase 4C.2 §6, restyled Phase
/// 4C.3 to match `mobile-customer/home.html`). Every figure on this screen
/// is a real field from an existing endpoint — no environmental-points/
/// CO₂/streak/Gold-Member metric is shown because none exists in any API
/// response (see class docblocks on the models for what was deliberately
/// left out and why).
///
/// The wallet card intentionally reads TWO real endpoints, both already
/// part of the existing architecture and already loaded by sibling tabs
/// in the same `CustomerHomeScreen` provider scope: `RewardProvider`
/// (`GET /customer/rewards` → `reward_balance`, the genuine redeemable
/// balance) and this screen's own `DashboardProvider` (`total_rewards_earned`,
/// the lifetime sum of completed pickups). These are two different real
/// numbers — never conflated into one, never relabelled as "points".
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onSeeAllItems});

  /// Switches the shell to the Items tab — reuses the existing bottom-nav
  /// state rather than pushing a second, parallel navigation route.
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
      // Reused, not re-implemented — RewardProvider/ItemCatalogueProvider
      // already exist for their own tabs; only fetched here if genuinely
      // not already loaded (e.g. the customer opens Dashboard first).
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
      onRefresh: provider.refresh,
      child: AsyncStateView<DashboardData>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.data,
        onRetry: provider.load,
        builder: (context, data) => _DashboardContent(data: data, onSeeAllItems: widget.onSeeAllItems),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.onSeeAllItems});

  final DashboardData data;
  final VoidCallback onSeeAllItems;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    // Nullable, not force-unwrapped: guards the one-frame window where
    // logout() has cleared AuthProvider.user but the router hasn't yet
    // swapped this screen out for LoginScreen.
    final userName = context.watch<AuthProvider>().user?.name ?? '';
    final rewardBalance = context.watch<RewardProvider>().balance;
    final catalogueItems = context.watch<ItemCatalogueProvider>().items;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Hero header + wallet card ──────────────────────────────────────
        GradientHeader(
          gradient: AppColors.homeHeroGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_greeting 👋', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(userName, style: AppTheme.displayFont(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                  // Dashboard is the only tab with no shared shell app bar
                  // (see CustomerHomeScreen), so logout lives here instead.
                  InkResponse(
                    onTap: () => context.read<AuthProvider>().logout(),
                    radius: 22,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.logout, color: Colors.white70, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: AppColors.walletCardGradient, borderRadius: BorderRadius.circular(AppRadii.r20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ECOXCHANGE WALLET', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(
                      rewardBalance != null ? 'RM ${rewardBalance.toStringAsFixed(2)}' : '—',
                      style: AppTheme.displayFont(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _WalletStat(label: 'LIFETIME EARNED', value: 'RM ${data.totalRewardsEarned.toStringAsFixed(2)}'),
                        Container(width: 1, height: 26, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
                        _WalletStat(label: 'WEIGHT RECYCLED', value: '${data.totalWeightKg.toStringAsFixed(1)} kg'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── AI Scan & Classify entry point (Stage 4.6) ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: EcoCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanClassifyScreen())),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
                  child: const Icon(Icons.document_scanner_outlined, color: AppColors.green600, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan & Classify', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800)),
                      SizedBox(height: 2),
                      Text('Let AI suggest what item you\'re recycling', style: TextStyle(fontSize: 12, color: AppColors.n500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.n400),
              ],
            ),
          ),
        ),

        // ── Active pickup ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: data.activePickup != null ? _ActivePickupBanner(pickup: data.activePickup!) : _EmptyRow(message: 'No active pickup right now.'),
        ),

        // ── Pickup statistics ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Pickups', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'Total', value: '${data.totalPickups}', icon: Icons.local_shipping_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(label: 'Completed', value: '${data.completedPickups}', icon: Icons.check_circle_outline)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatTile(label: 'Pending', value: '${data.pendingPickups}', icon: Icons.pending_outlined)),
                ],
              ),
            ],
          ),
        ),

        // ── Recyclable items teaser ─────────────────────────────────────────
        if (catalogueItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Recyclable Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800))),
                    GestureDetector(
                      onTap: onSeeAllItems,
                      child: const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
                  itemCount: catalogueItems.length > 6 ? 6 : catalogueItems.length,
                  itemBuilder: (context, index) => _ItemTeaserCard(item: catalogueItems[index]),
                ),
              ],
            ),
          ),

        // ── Recent pickups ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent Pickups', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
              const SizedBox(height: 6),
              if (data.recentPickups.isEmpty)
                _EmptyRow(message: 'You have no pickups yet.')
              else
                EcoCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (final pickup in data.recentPickups) ...[
                        if (pickup != data.recentPickups.first) const Divider(height: 1),
                        PickupSummaryCard(
                          pickup: pickup,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id))),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
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
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ActivePickupBanner extends StatelessWidget {
  const _ActivePickupBanner({required this.pickup});

  final PickupSummary pickup;

  @override
  Widget build(BuildContext context) {
    final style = PickupStatusStyle.forStatus(pickup.status);
    final riderName = pickup.assignedRiderName;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.goldLight, Color(0xFFFDE68A)]),
          borderRadius: BorderRadius.circular(AppRadii.r16),
          border: Border.all(color: const Color(0xFFF5D080), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(AppRadii.r12)),
              child: const Icon(Icons.access_time_filled, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Pickup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF7B4F00))),
                  const SizedBox(height: 2),
                  Text(
                    riderName != null ? '$riderName · ${style.label}' : style.label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9B6800)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9B6800)),
          ],
        ),
      ),
    );
  }
}

class _ItemTeaserCard extends StatelessWidget {
  const _ItemTeaserCard({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r8),
            child: item.image != null
                ? AppNetworkImage(url: item.image!, height: 40, width: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.recycling_outlined, color: AppColors.n300, size: 32))
                : const Icon(Icons.recycling_outlined, color: AppColors.n300, size: 32),
          ),
          const SizedBox(height: 6),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n800)),
          if (item.preliminaryBasePricePerKg != null)
            Text('RM ${item.preliminaryBasePricePerKg!.toStringAsFixed(2)}/kg', style: const TextStyle(fontSize: 10, color: AppColors.green600)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: AppColors.green600, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.n800)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.n500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Text(message, style: const TextStyle(color: AppColors.n500, fontSize: 13)),
    );
  }
}
