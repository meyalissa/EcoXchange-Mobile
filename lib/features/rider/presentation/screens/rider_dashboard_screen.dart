import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../../../core/widgets/eco_hero_header.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../data/models/rider_dashboard.dart';
import '../../data/models/rider_pickup_action.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../providers/rider_dashboard_provider.dart';
import '../providers/rider_tasks_provider.dart';
import '../widgets/rider_action_runner.dart';
import '../widgets/rider_status_chip.dart';
import 'rider_pickup_detail_screen.dart';

/// EcoXchange Mobile — Rider Home (01_rider_home design). All values are
/// real:
///   * today's counters — `GET /rider/dashboard` (`assigned_today`,
///     `completed_today`, `weight_today`);
///   * the job card — the dashboard's current job (collecting > en_route >
///     accepted), else the next assigned one, with its item types;
///   * Today's Schedule — the rider's open jobs dated today (RiderTasksProvider).
/// The card's action button runs the job's single next action through the
/// shared rider action flow. No ETA is shown: the backend computes none.
class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key, required this.onSeeAllPickups, required this.onViewRoute});

  /// Switches the shell to My Tasks.
  final VoidCallback onSeeAllPickups;

  /// Opens the Route page for a pickup.
  final ValueChanged<int> onViewRoute;

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiderDashboardProvider>().load();
      final tasks = context.read<RiderTasksProvider>();
      if (!tasks.loadedOnce && !tasks.isLoading) tasks.load();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<RiderDashboardProvider>().refresh(), context.read<RiderTasksProvider>().refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderDashboardProvider>();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: AsyncStateView<RiderDashboard>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.data,
        onRetry: provider.load,
        builder: (context, data) => _HomeContent(
          data: data,
          onRefresh: _refresh,
          onSeeAllPickups: widget.onSeeAllPickups,
          onViewRoute: widget.onViewRoute,
        ),
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

String _humanise(String value) {
  final words = value.replaceAll('_', ' ').trim();
  return words.isEmpty ? value : words[0].toUpperCase() + words.substring(1);
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data, required this.onRefresh, required this.onSeeAllPickups, required this.onViewRoute});

  final RiderDashboard data;
  final Future<void> Function() onRefresh;
  final VoidCallback onSeeAllPickups;
  final ValueChanged<int> onViewRoute;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final userName = user?.name ?? '';
    final riderStatus = user?.riderProfile?.riderStatus;
    final job = data.activeTask ?? data.nextPickup;
    final schedule = context.watch<RiderTasksProvider>().today.where((p) => p.id != job?.id).toList();
    final pendingCount = schedule.where((p) => p.displayStatus == 'assigned').length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        GradientHeader(
          gradient: AppColors.homeHeroGradient,
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()} 👋', style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(userName, style: AppTheme.headerIdentityName()),
                    if (riderStatus != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: riderStatus == 'available' ? AppColors.green300 : Colors.white54),
                          const SizedBox(width: 6),
                          Text('Rider · ${_humanise(riderStatus)}', key: const Key('rider-status'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _InitialsAvatar(initials: initialsOf(userName)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            key: const Key('rider-today-stats'),
            children: [
              _StatCard(value: '${data.assignedToday}', label: 'Assigned'),
              const SizedBox(width: 10),
              _StatCard(value: '${data.completedToday}', label: 'Completed'),
              const SizedBox(width: 10),
              _StatCard(value: '${data.weightTodayKg.toStringAsFixed(1)} kg', label: 'Collected'),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text('Today', style: TextStyle(fontSize: 11, color: AppColors.n500)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: job == null
              ? const EcoCard(
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
                )
              : _JobCard(
                  key: Key(data.activeTask != null ? 'rider-active-task' : 'rider-next-pickup'),
                  pickup: job,
                  isActive: data.activeTask != null,
                  onViewRoute: () => onViewRoute(job.id),
                  onChanged: onRefresh,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
          child: SectionTitleRow(
            title: "Today's Schedule",
            trailing: pendingCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.rFull), border: Border.all(color: AppColors.green300)),
                    child: Text('$pendingCount pending', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green700)),
                  )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: schedule.isEmpty
              ? Text(
                  job == null ? 'Nothing scheduled for today.' : 'No other pickups scheduled for today.',
                  style: const TextStyle(fontSize: 13, color: AppColors.n500),
                )
              : EcoCard(
                  key: const Key('rider-today-schedule'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  borderRadius: AppRadii.r20,
                  child: Column(
                    children: [
                      for (final p in schedule) ...[
                        if (p != schedule.first) const Divider(height: 1, color: AppColors.n100),
                        _ScheduleRow(pickup: p, onChanged: onRefresh),
                      ],
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: OutlinedButton.icon(
            onPressed: onSeeAllPickups,
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: const Text('See all my tasks'),
          ),
        ),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 3),
      ),
      child: Text(initials, style: AppTheme.displayFont(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: EcoCard(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
        borderRadius: AppRadii.r20,
        child: Column(
          children: [
            FittedBox(child: Text(value, style: AppTheme.displayFont(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.green600))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.n500, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// The green job card: current job (or next assigned one) with its real
/// fields and its single next action.
class _JobCard extends StatelessWidget {
  const _JobCard({super.key, required this.pickup, required this.isActive, required this.onViewRoute, required this.onChanged});

  final RiderPickupSummary pickup;
  final bool isActive;
  final VoidCallback onViewRoute;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final next = RiderPickupAction.nextFor(pickup.displayStatus);
    final weight = pickup.actualWeightKg ?? pickup.estimatedWeightKg;

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: pickup.id)))
          .then((_) => onChanged()),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: AppColors.walletCardGradient, borderRadius: BorderRadius.circular(AppRadii.r24), boxShadow: AppShadows.sh2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.rFull)),
                  child: Text(isActive ? '● ACTIVE JOB' : '● NEXT PICKUP', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                Text(pickup.reference, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            // Same size as the identical "customer name as a card title"
            // role elsewhere (rider_task_card.dart, rider_route_screen.dart)
            // -- this one was the odd one out at 21px (Typography Polish pass).
            Text(pickup.customerName ?? '—', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            if (pickup.addressSummary != null) _CardLine(icon: Icons.location_on_outlined, text: pickup.addressSummary!),
            if (pickup.pickupDate != null)
              _CardLine(icon: Icons.schedule, text: [pickup.pickupDate, pickup.pickupTime].whereType<String>().join(' · ')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 22,
              runSpacing: 8,
              children: [
                _CardFigure(label: 'STATUS', value: RiderStatusChip.styleFor(pickup.displayStatus).label),
                if (weight != null)
                  _CardFigure(label: pickup.actualWeightKg != null ? 'WEIGHT' : 'EST. WEIGHT', value: '~${weight.toStringAsFixed(1)} kg'),
                if (pickup.itemNames.isNotEmpty)
                  _CardFigure(label: 'ITEMS', value: '${pickup.itemNames.length} type${pickup.itemNames.length == 1 ? '' : 's'}'),
              ],
            ),
            if (pickup.itemNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(pickup.itemNames.join(', '), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CardButton(key: const Key('rider-view-route'), label: '🗺 View Route', light: false, onTap: onViewRoute),
                ),
                if (next != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardButton(
                      key: const Key('rider-home-action'),
                      label: '▶ ${riderActionCopy(next).button}',
                      light: true,
                      onTap: () async {
                        if (await runNextActionForPickup(context, pickup.id, expected: next)) await onChanged();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }
}

class _CardFigure extends StatelessWidget {
  const _CardFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
        Text(value, style: AppTheme.displayFont(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({super.key, required this.label, required this.light, required this.onTap});

  final String label;
  final bool light;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: light ? Colors.white : Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(AppRadii.rFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.rFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: light ? AppColors.green700 : Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.pickup, required this.onChanged});

  final RiderPickupSummary pickup;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final weight = pickup.actualWeightKg ?? pickup.estimatedWeightKg;
    return InkWell(
      key: Key('rider-schedule-${pickup.id}'),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: pickup.id)))
          .then((_) => onChanged()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
              child: const Icon(Icons.calendar_today_outlined, color: AppColors.n800),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pickup.reference, style: AppTheme.displayFont(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800)),
                  Text(
                    [pickup.addressSummary, pickup.pickupTime].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.n600),
                  ),
                  Text(
                    [if (pickup.itemNames.isNotEmpty) pickup.itemNames.join(', '), if (weight != null) '~${weight.toStringAsFixed(1)} kg'].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.n500),
                  ),
                ],
              ),
            ),
            RiderStatusChip(status: pickup.displayStatus),
          ],
        ),
      ),
    );
  }
}
