/// EcoXchange Mobile — shaped EXACTLY like the real
/// `Api\Customer\CommunityController::leaderboard()` response (the same
/// `CommunityImpactService` the web Community Leaderboard page uses).
/// Three distinct ranking views — 'area'/'state' by verified weight,
/// 'participation' by distinct customer count — never a blended score.
class CommunityLeaderboardResult {
  const CommunityLeaderboardResult({
    required this.view,
    required this.period,
    required this.metric,
    required this.suppressionThreshold,
    required this.includesDemoData,
    required this.rankings,
  });

  factory CommunityLeaderboardResult.fromJson(Map<String, dynamic> json) {
    return CommunityLeaderboardResult(
      view: json['view'] as String,
      period: json['period'] as String,
      metric: json['metric'] as String,
      suppressionThreshold: json['suppression_threshold'] as int,
      includesDemoData: json['includes_demo_data'] as bool,
      rankings: (json['rankings'] as List<dynamic>? ?? const [])
          .map((e) => CommunityLeaderboardRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String view;
  final String period;

  /// 'total_weight' or 'participants' — which column [rankings] is sorted by.
  final String metric;
  final int suppressionThreshold;
  final bool includesDemoData;
  final List<CommunityLeaderboardRow> rankings;
}

class CommunityLeaderboardRow {
  const CommunityLeaderboardRow({
    required this.rank,
    required this.location,
    required this.totalWeightKg,
    required this.pickups,
    required this.participants,
    required this.hasDemoData,
  });

  factory CommunityLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return CommunityLeaderboardRow(
      rank: json['rank'] as int,
      location: json['location'] as String,
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
      pickups: json['pickups'] as int,
      participants: json['participants'] as int,
      hasDemoData: json['has_demo_data'] as bool,
    );
  }

  final int rank;
  final String location;
  final double totalWeightKg;
  final int pickups;
  final int participants;
  final bool hasDemoData;
}
