import 'rider_pickup_summary.dart';

/// EcoXchange Mobile — `GET /api/v1/rider/dashboard`, shaped exactly like
/// `Api\Rider\DashboardController::index()`: today's three counters, the
/// rider's current in-progress job (collecting > en_route > accepted) and
/// the next assigned-but-not-started job. Every figure is computed by the
/// server; nothing is derived here.
class RiderDashboard {
  const RiderDashboard({
    required this.assignedToday,
    required this.completedToday,
    required this.weightTodayKg,
    required this.activeTask,
    required this.nextPickup,
  });

  factory RiderDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    final active = json['active_task'] as Map<String, dynamic>?;
    final next = json['next_pickup'] as Map<String, dynamic>?;
    return RiderDashboard(
      assignedToday: stats['assigned_today'] as int,
      completedToday: stats['completed_today'] as int,
      weightTodayKg: (stats['weight_today'] as num).toDouble(),
      activeTask: active == null ? null : RiderPickupSummary.fromJson(active),
      nextPickup: next == null ? null : RiderPickupSummary.fromJson(next),
    );
  }

  /// Open jobs (assigned/accepted/en_route/collecting) dated today.
  final int assignedToday;
  final int completedToday;

  /// Sum of actual weight collected on jobs completed today.
  final double weightTodayKg;

  final RiderPickupSummary? activeTask;
  final RiderPickupSummary? nextPickup;

  bool get hasUpcomingWork => activeTask != null || nextPickup != null;
}
