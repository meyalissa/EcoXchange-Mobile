import 'address.dart';

/// EcoXchange Mobile — Pickup Booking (Stage 3) response models. Every
/// field here is shaped EXACTLY like the real
/// `Api\Customer\PickupPreparationController` responses (confirmed by
/// inspection — see that controller's docblock, the single source of truth
/// this stage never duplicates). Weight, reward, rate, and feasibility are
/// always the server's own numbers; nothing here is computed client-side.

// ── POST /customer/pickup/estimate ─────────────────────────────────────────

class PickupEstimateLine {
  const PickupEstimateLine({
    required this.itemId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitWeightKg,
    required this.weightKg,
    required this.weightSource,
    required this.preliminaryPricePerKg,
    required this.preliminaryLineReward,
  });

  factory PickupEstimateLine.fromJson(Map<String, dynamic> json) {
    return PickupEstimateLine(
      itemId: json['item_id'] as int,
      name: json['name'] as String?,
      category: json['category'] as String?,
      quantity: json['quantity'] as int,
      unitWeightKg: (json['unit_weight_kg'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num).toDouble(),
      weightSource: json['weight_source'] as String? ?? 'computed',
      preliminaryPricePerKg: (json['preliminary_price_per_kg'] as num?)?.toDouble(),
      preliminaryLineReward: (json['preliminary_line_reward'] as num?)?.toDouble(),
    );
  }

  final int itemId;
  final String? name;
  final String? category;
  final int quantity;
  final double? unitWeightKg;
  final double weightKg;
  final String weightSource;
  final double? preliminaryPricePerKg;
  final double? preliminaryLineReward;
}

class PickupEstimate {
  const PickupEstimate({
    required this.items,
    required this.totalWeightKg,
    required this.preliminaryReward,
    required this.unavailableItemIds,
    required this.note,
  });

  factory PickupEstimate.fromJson(Map<String, dynamic> json) {
    return PickupEstimate(
      items: (json['items'] as List<dynamic>).map((e) => PickupEstimateLine.fromJson(e as Map<String, dynamic>)).toList(),
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
      preliminaryReward: (json['preliminary_reward'] as num).toDouble(),
      unavailableItemIds: (json['unavailable_item_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
      note: json['note'] as String?,
    );
  }

  final List<PickupEstimateLine> items;
  final double totalWeightKg;
  final double preliminaryReward;
  final List<int> unavailableItemIds;
  final String? note;
}

// ── POST /customer/pickup/centres ──────────────────────────────────────────

class CentreItemRate {
  const CentreItemRate({required this.itemId, required this.itemName, required this.pricePerKg});

  factory CentreItemRate.fromJson(Map<String, dynamic> json) {
    return CentreItemRate(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String? ?? '—',
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
    );
  }

  final int itemId;
  final String itemName;
  final double pricePerKg;
}

class EligibleCentre {
  const EligibleCentre({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.distanceLabel,
    required this.eligible,
    required this.missingItems,
    required this.rates,
    required this.estimatedReward,
    required this.recommended,
    required this.rewardDelta,
    required this.rewardChangeNote,
  });

  factory EligibleCentre.fromJson(Map<String, dynamic> json) {
    return EligibleCentre(
      id: json['id'] as int,
      name: json['name'] as String? ?? '—',
      address: json['address'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      distanceLabel: json['distance_label'] as String?,
      eligible: json['eligible'] as bool? ?? false,
      missingItems: (json['missing_items'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      rates: (json['rates'] as List<dynamic>?)?.map((e) => CentreItemRate.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      estimatedReward: (json['estimated_reward'] as num?)?.toDouble() ?? 0.0,
      recommended: json['recommended'] as bool? ?? false,
      rewardDelta: (json['reward_delta'] as num?)?.toDouble(),
      rewardChangeNote: json['reward_change_note'] as String?,
    );
  }

  final int id;
  final String name;
  final String? address;
  final double? distanceKm;
  final String? distanceLabel;
  final bool eligible;
  final List<String> missingItems;
  final List<CentreItemRate> rates;
  final double estimatedReward;

  /// The real nearest-ELIGIBLE flag `PickupFeasibilityService::
  /// findEligibleCentres()` assigns — never a client-computed "nearest".
  final bool recommended;
  final double? rewardDelta;
  final String? rewardChangeNote;
}

class CentresResult {
  const CentresResult({required this.centres, required this.preliminaryReward, required this.unavailableItemIds, required this.message});

  factory CentresResult.fromJson(Map<String, dynamic> json) {
    return CentresResult(
      centres: (json['centres'] as List<dynamic>).map((e) => EligibleCentre.fromJson(e as Map<String, dynamic>)).toList(),
      preliminaryReward: (json['preliminary_reward'] as num).toDouble(),
      unavailableItemIds: (json['unavailable_item_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
      message: json['message'] as String?,
    );
  }

  final List<EligibleCentre> centres;
  final double preliminaryReward;
  final List<int> unavailableItemIds;
  final String? message;
}

// ── Shared — PickupFeasibilityResource (customer-safe only) ────────────────

class CentreRateLine {
  const CentreRateLine({required this.itemId, required this.itemName, required this.weightKg, required this.pricePerKg, required this.lineReward});

  factory CentreRateLine.fromJson(Map<String, dynamic> json) {
    return CentreRateLine(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String? ?? '—',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      pricePerKg: (json['price_per_kg'] as num?)?.toDouble() ?? 0.0,
      lineReward: (json['line_reward'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final int itemId;
  final String itemName;
  final double weightKg;
  final double pricePerKg;
  final double lineReward;
}

/// Wraps `App\Http\Resources\Customer\PickupFeasibilityResource` — already
/// hand-picked to be customer-safe server-side (no fuel cost/net benefit/
/// internal scores — see that Resource's docblock). Nothing here re-derives
/// or re-labels the server's own `decision`/`message`.
class PickupFeasibilityResult {
  const PickupFeasibilityResult({
    required this.decision,
    required this.title,
    required this.message,
    required this.action,
    required this.totalWeightKg,
    required this.estimatedReward,
    required this.rewardSource,
    required this.minimumPickupReward,
    required this.additionalRewardNeeded,
    required this.centreRates,
    required this.centreName,
    required this.distanceLabel,
  });

  factory PickupFeasibilityResult.fromJson(Map<String, dynamic> json) {
    final centre = json['centre'] as Map<String, dynamic>?;
    return PickupFeasibilityResult(
      decision: json['decision'] as String? ?? 'UNKNOWN',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      action: json['action'] as String? ?? 'RETRY',
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      estimatedReward: (json['estimated_reward'] as num?)?.toDouble(),
      rewardSource: json['reward_source'] as String?,
      minimumPickupReward: (json['minimum_pickup_reward'] as num?)?.toDouble(),
      additionalRewardNeeded: (json['additional_reward_needed'] as num?)?.toDouble(),
      centreRates: (json['centre_rates'] as List<dynamic>?)?.map((e) => CentreRateLine.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      centreName: centre?['name'] as String?,
      distanceLabel: centre?['distance_label'] as String?,
    );
  }

  final String decision;
  final String title;
  final String message;
  final String action;
  final double? totalWeightKg;
  final double? estimatedReward;
  final String? rewardSource;
  final double? minimumPickupReward;
  final double? additionalRewardNeeded;
  final List<CentreRateLine> centreRates;
  final String? centreName;
  final String? distanceLabel;

  bool get isProceed => decision == 'PROCEED';
}

// ── POST /customer/pickup/image ─────────────────────────────────────────────

class ScanUploadResult {
  const ScanUploadResult({required this.scanLogId, required this.imageUrl});

  factory ScanUploadResult.fromJson(Map<String, dynamic> json) {
    return ScanUploadResult(scanLogId: json['scan_log_id'] as int, imageUrl: json['image_url'] as String);
  }

  final int scanLogId;
  final String imageUrl;
}

// ── POST /customer/pickup/review ───────────────────────────────────────────

class ReviewReason {
  const ReviewReason({required this.code, required this.message});

  factory ReviewReason.fromJson(Map<String, dynamic> json) {
    return ReviewReason(code: json['code'] as String? ?? 'UNKNOWN', message: json['message'] as String? ?? '');
  }

  final String code;
  final String message;
}

class ReviewItemLine {
  const ReviewItemLine({required this.itemId, required this.name, required this.quantity, required this.weightKg});

  factory ReviewItemLine.fromJson(Map<String, dynamic> json) {
    return ReviewItemLine(
      itemId: json['item_id'] as int,
      name: json['name'] as String?,
      quantity: json['quantity'] as int,
      weightKg: (json['weight_kg'] as num).toDouble(),
    );
  }

  final int itemId;
  final String? name;
  final int quantity;
  final double weightKg;
}

class ReviewImage {
  const ReviewImage({required this.scanLogId, required this.imageUrl});

  factory ReviewImage.fromJson(Map<String, dynamic> json) {
    return ReviewImage(scanLogId: json['scan_log_id'] as int, imageUrl: json['image_url'] as String);
  }

  final int scanLogId;
  final String imageUrl;
}

class ReviewCentreRef {
  const ReviewCentreRef({required this.id, required this.name});

  factory ReviewCentreRef.fromJson(Map<String, dynamic> json) {
    return ReviewCentreRef(id: json['id'] as int, name: json['name'] as String? ?? '—');
  }

  final int id;
  final String name;
}

/// The one, real pre-submission gate — see `PickupPreparationController::
/// review()`. [readyToSubmit]/[reasons] are shown VERBATIM: each
/// [ReviewReason.message] is already a complete, customer-safe sentence the
/// server built (not just a bare code) — this app never rewrites or
/// re-explains it.
class ReviewResult {
  const ReviewResult({
    required this.readyToSubmit,
    required this.reasons,
    required this.address,
    required this.centre,
    required this.items,
    required this.totalWeightKg,
    required this.feasibility,
    required this.image,
  });

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      readyToSubmit: json['ready_to_submit'] as bool? ?? false,
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => ReviewReason.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      address: AddressModel.fromJson(json['address'] as Map<String, dynamic>),
      centre: json['centre'] != null ? ReviewCentreRef.fromJson(json['centre'] as Map<String, dynamic>) : null,
      items: (json['items'] as List<dynamic>).map((e) => ReviewItemLine.fromJson(e as Map<String, dynamic>)).toList(),
      totalWeightKg: (json['total_weight_kg'] as num).toDouble(),
      feasibility: json['feasibility'] != null ? PickupFeasibilityResult.fromJson(json['feasibility'] as Map<String, dynamic>) : null,
      image: json['image'] != null ? ReviewImage.fromJson(json['image'] as Map<String, dynamic>) : null,
    );
  }

  final bool readyToSubmit;
  final List<ReviewReason> reasons;
  final AddressModel address;
  final ReviewCentreRef? centre;
  final List<ReviewItemLine> items;
  final double totalWeightKg;
  final PickupFeasibilityResult? feasibility;
  final ReviewImage? image;
}
