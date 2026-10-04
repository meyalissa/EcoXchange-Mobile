import 'pickup_summary.dart';

/// EcoXchange Mobile — shaped EXACTLY like the real
/// `Api\Customer\DashboardController::index()` response (confirmed by
/// inspection). No field here exists that the API doesn't genuinely
/// return — in particular there is no environmental-points/CO₂/streak
/// concept anywhere in the backend, so none is modelled here either.
class DashboardData {
  const DashboardData({
    required this.totalPickups,
    required this.completedPickups,
    required this.pendingPickups,
    required this.totalWeightKg,
    required this.totalRewardsEarned,
    required this.activePickup,
    required this.recentPickups,
    this.monthlyWeightKg,
    this.monthlyCompletedPickups,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalPickups: json['total_pickups'] as int,
      completedPickups: json['completed_pickups'] as int,
      pendingPickups: json['pending_pickups'] as int,
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
      totalRewardsEarned: (json['total_rewards_earned'] as num).toDouble(),
      activePickup: json['active_pickup'] != null ? PickupSummary.fromJson(json['active_pickup'] as Map<String, dynamic>) : null,
      recentPickups: (json['recent_pickups'] as List<dynamic>? ?? const [])
          .map((e) => PickupSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      monthlyWeightKg: (json['monthly_weight_kg'] as num?)?.toDouble(),
      monthlyCompletedPickups: json['monthly_completed_pickups'] as int?,
    );
  }

  final int totalPickups;
  final int completedPickups;
  final int pendingPickups;
  final double totalWeightKg;
  final double totalRewardsEarned;
  final PickupSummary? activePickup;
  final List<PickupSummary> recentPickups;

  /// This calendar month: kg collected and pickups completed (by completion
  /// time). Null from an older backend that doesn't return them.
  final double? monthlyWeightKg;
  final int? monthlyCompletedPickups;
}
