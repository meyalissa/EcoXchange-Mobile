/// EcoXchange Mobile — shaped EXACTLY like the real
/// `Api\Customer\CommunityController::index()` response (confirmed by
/// inspection — same `CommunityImpactService` the web Community Impact
/// page uses). `completedPickups`/`totalWeightKg`/`participatingCustomers`
/// are null when [suppressed] is true: the server itself withholds the
/// exact figures for a scope with too few distinct contributing customers,
/// this model never fills in a guessed value.
class CommunityImpactSummary {
  const CommunityImpactSummary({
    required this.period,
    required this.state,
    required this.area,
    required this.locationLabel,
    required this.availableStates,
    required this.availableAreas,
    required this.suppressed,
    required this.suppressionThreshold,
    required this.completedPickups,
    required this.totalWeightKg,
    required this.participatingCustomers,
    required this.trendLabels,
    required this.trendData,
    required this.areaComparison,
  });

  factory CommunityImpactSummary.fromJson(Map<String, dynamic> json) {
    final trend = (json['trend'] as Map<String, dynamic>?) ?? const {};

    return CommunityImpactSummary(
      period: json['period'] as String,
      state: json['state'] as String?,
      area: json['area'] as String?,
      locationLabel: json['location_label'] as String,
      availableStates: (json['available_states'] as List<dynamic>? ?? const []).cast<String>(),
      availableAreas: (json['available_areas'] as List<dynamic>? ?? const []).cast<String>(),
      suppressed: json['suppressed'] as bool,
      suppressionThreshold: json['suppression_threshold'] as int,
      completedPickups: json['completed_pickups'] as int?,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      participatingCustomers: json['participating_customers'] as int?,
      trendLabels: (trend['labels'] as List<dynamic>? ?? const []).cast<String>(),
      trendData: (trend['data'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList(),
      areaComparison: (json['area_comparison'] as List<dynamic>? ?? const [])
          .map((e) => CommunityAreaRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String period;
  final String? state;
  final String? area;
  final String locationLabel;
  final List<String> availableStates;
  final List<String> availableAreas;
  final bool suppressed;
  final int suppressionThreshold;

  /// Null when [suppressed] is true.
  final int? completedPickups;
  final double? totalWeightKg;
  final int? participatingCustomers;

  final List<String> trendLabels;
  final List<double> trendData;
  final List<CommunityAreaRow> areaComparison;
}

class CommunityAreaRow {
  const CommunityAreaRow({required this.city, required this.pickups, required this.totalWeightKg});

  factory CommunityAreaRow.fromJson(Map<String, dynamic> json) {
    return CommunityAreaRow(
      city: json['city'] as String,
      pickups: json['pickups'] as int,
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
    );
  }

  final String city;
  final int pickups;
  final double totalWeightKg;
}
