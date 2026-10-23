/// EcoXchange Mobile — shaped EXACTLY like
/// `Api\Customer\CommunityController::personal()`'s response (confirmed by
/// inspection — backed by `CommunityImpactService::personalImpactSummary()`
/// and `EnvironmentalImpactService::personalSummary()`). This is always
/// ONE customer's own data (`$request->user()->id` server-side) — never a
/// community aggregate, and never suppressed.
class PersonalImpactSummary {
  const PersonalImpactSummary({
    required this.period,
    required this.completedPickups,
    required this.totalWeightKg,
    required this.trendLabels,
    required this.trendData,
    required this.environmental,
  });

  factory PersonalImpactSummary.fromJson(Map<String, dynamic> json) {
    final trend = (json['trend'] as Map<String, dynamic>?) ?? const {};

    return PersonalImpactSummary(
      period: json['period'] as String,
      completedPickups: json['completed_pickups'] as int,
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
      trendLabels: (trend['labels'] as List<dynamic>? ?? const []).cast<String>(),
      trendData: (trend['data'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList(),
      environmental: PersonalEnvironmentalImpact.fromJson(json['environmental'] as Map<String, dynamic>),
    );
  }

  final String period;
  final int completedPickups;
  final double totalWeightKg;
  final List<String> trendLabels;
  final List<double> trendData;
  final PersonalEnvironmentalImpact environmental;
}

/// Always a model ESTIMATE ([isEstimate] is always true today) — never a
/// measured value. [breakdown] only covers material categories with a
/// documented conversion factor; [unsupportedCategories] lists any other
/// recorded weight (e.g. Electronic, Oil) so it is never silently dropped
/// or implied to be zero-impact.
class PersonalEnvironmentalImpact {
  const PersonalEnvironmentalImpact({
    required this.totalCo2eKg,
    required this.isEstimate,
    required this.source,
    required this.sourceUrl,
    required this.factorVersion,
    required this.breakdown,
    required this.unsupportedCategories,
  });

  factory PersonalEnvironmentalImpact.fromJson(Map<String, dynamic> json) {
    return PersonalEnvironmentalImpact(
      totalCo2eKg: (json['total_co2e_kg'] as num).toDouble(),
      isEstimate: json['is_estimate'] as bool,
      source: json['source'] as String,
      sourceUrl: json['source_url'] as String,
      factorVersion: json['factor_version'] as String,
      breakdown: (json['breakdown'] as List<dynamic>? ?? const [])
          .map((e) => MaterialCo2eRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      unsupportedCategories: (json['unsupported_categories'] as List<dynamic>? ?? const [])
          .map((e) => UnsupportedMaterialRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final double totalCo2eKg;
  final bool isEstimate;
  final String source;
  final String sourceUrl;
  final String factorVersion;
  final List<MaterialCo2eRow> breakdown;
  final List<UnsupportedMaterialRow> unsupportedCategories;
}

class MaterialCo2eRow {
  const MaterialCo2eRow({required this.category, required this.weightKg, required this.co2eKg, required this.factorKgCo2ePerKg});

  factory MaterialCo2eRow.fromJson(Map<String, dynamic> json) {
    return MaterialCo2eRow(
      category: json['category'] as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      co2eKg: (json['co2e_kg'] as num).toDouble(),
      factorKgCo2ePerKg: (json['factor_kg_co2e_per_kg'] as num).toDouble(),
    );
  }

  final String category;
  final double weightKg;
  final double co2eKg;
  final double factorKgCo2ePerKg;
}

class UnsupportedMaterialRow {
  const UnsupportedMaterialRow({required this.category, required this.weightKg});

  factory UnsupportedMaterialRow.fromJson(Map<String, dynamic> json) {
    return UnsupportedMaterialRow(category: json['category'] as String, weightKg: (json['weight_kg'] as num).toDouble());
  }

  final String category;
  final double weightKg;
}
