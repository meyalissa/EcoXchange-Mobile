/// EcoXchange Mobile — compact pickup shape, shaped EXACTLY like
/// `App\Http\Resources\Customer\PickupSummaryResource` (confirmed by
/// inspection). Used by the Dashboard (active_pickup/recent_pickups) and
/// the Pickup List screen — the same real backend shape in both places.
class PickupSummary {
  const PickupSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.pickupDate,
    required this.pickupTime,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
    required this.estimatedReward,
    required this.actualReward,
    required this.centreName,
    required this.itemSummaries,
    required this.assignedRiderName,
    required this.createdAt,
  });

  factory PickupSummary.fromJson(Map<String, dynamic> json) {
    return PickupSummary(
      id: json['id'] as int,
      reference: json['reference'] as String,
      status: json['status'] as String,
      pickupDate: json['pickup_date'] as String?,
      pickupTime: json['pickup_time'] as String?,
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
      estimatedReward: (json['estimated_reward'] as num?)?.toDouble(),
      actualReward: (json['actual_reward'] as num?)?.toDouble(),
      centreName: (json['centre'] as Map<String, dynamic>?)?['name'] as String?,
      itemSummaries: (json['items'] as List<dynamic>?)
              ?.map((e) => PickupItemSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      assignedRiderName: (json['assigned_rider'] as Map<String, dynamic>?)?['name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String reference;
  final String status;
  final String? pickupDate;
  final String? pickupTime;
  final double? estimatedWeightKg;
  final double? actualWeightKg;
  final double? estimatedReward;
  final double? actualReward;
  final String? centreName;
  final List<PickupItemSummary> itemSummaries;
  final String? assignedRiderName;
  final String? createdAt;

  /// The server's own status token, exactly as returned — never
  /// reinterpreted (see AppTheme/status-colour mapping in the pickup
  /// widgets, which only chooses a COLOUR, not a different meaning).
  bool get isActive => status == 'assigned' || status == 'collecting';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

class PickupItemSummary {
  const PickupItemSummary({required this.itemName, required this.quantity});

  factory PickupItemSummary.fromJson(Map<String, dynamic> json) {
    return PickupItemSummary(
      itemName: json['item_name'] as String? ?? '—',
      quantity: json['quantity'] as int? ?? 0,
    );
  }

  final String itemName;
  final int quantity;
}
