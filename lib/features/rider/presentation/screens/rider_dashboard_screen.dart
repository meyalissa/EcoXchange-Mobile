import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/models/rider_dashboard.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../providers/rider_dashboard_provider.dart';
import '../widgets/rider_pickup_card.dart';
import 'rider_pickup_detail_screen.dart';

/// EcoXchange Mobile — Rider Home (Phase R1). Greeting + identity from the
/// logged-in user, today's three counters, the current job and the next
/// assigned job — all from `GET /rider/dashboard`. No other metric is
/// shown because no other one exists in the API.
class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key, required this.onSeeAllPickups});

  /// Switches the shell to the Pickups tab (no second navigation route).
  final VoidCallback onSeeAllPickups;

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RiderDashboardProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderDashboardProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: AsyncStateView<RiderDashboard>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.data,
        onRetry: provider.load,
        builder: (context, data) => _DashboardContent(data: data, onSeeAllPickups: widget.onSeeAllPickups),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.onSeeAllPickups});

  final RiderDashboard data;
  final VoidCallback onSeeAllPickups;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _openPickup(BuildContext context, RiderPickupSummary pickup) {
    final provider = context.read<RiderDashboardProvider>();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: pickup.id)))
        .then((_) => provider.refresh());
  }

  @override
  Widget build(BuildContext context) {
    // Nullable: guards the frame between logout() and the router swapping
    // this screen out.
    final user = context.watch<AuthProvider>().user;
    final userName = user?.name ?? '';
    final riderStatus = user?.riderProfile?.riderStatus;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
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
                        if (riderStatus != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 8, color: riderStatus == 'available' ? AppColors.green300 : Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                'Rider · ${_humanise(riderStatus)}',
                                key: const Key('rider-status'),
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  InkResponse(
                    key: const Key('rider-logout'),
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
              Row(
                children: [
                  _StatTile(label: 'Open today', value: '${data.assignedToday}'),
                  const SizedBox(width: 10),
                  _StatTile(label: 'Completed today', value: '${data.completedToday}'),
                  const SizedBox(width: 10),
                  _StatTile(label: 'Collected today', value: '${data.weightTodayKg.toStringAsFixed(1)} kg'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!data.hasUpcomingWork)
                const EcoCard(
                  key: Key('rider-no-work'),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_outlined, color: AppColors.n400),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No active or upcoming pickups assigned to you right now.',
                          style: TextStyle(fontSize: 13, color: AppColors.n600, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              if (data.activeTask != null) ...[
                const _SectionTitle('Current job'),
                EcoCard(
                  key: const Key('rider-active-task'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: RiderPickupCard(pickup: data.activeTask!, onTap: () => _openPickup(context, data.activeTask!)),
                ),
                const SizedBox(height: 16),
              ],
              if (data.nextPickup != null) ...[
                const _SectionTitle('Next pickup'),
                EcoCard(
                  key: const Key('rider-next-pickup'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: RiderPickupCard(pickup: data.nextPickup!, onTap: () => _openPickup(context, data.nextPickup!)),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: onSeeAllPickups,
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text('See all my pickups'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _humanise(String value) {
  final words = value.replaceAll('_', ' ').trim();
  return words.isEmpty ? value : words[0].toUpperCase() + words.substring(1);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.r12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
    );
  }
}
