/// EcoXchange Mobile — one pickup as the RIDER sees it in lists and on the
/// dashboard, shaped exactly like `App\Http\Resources\Rider\RiderPickupSummaryResource`.
///
/// Two statuses, both real:
///   * [status] — `pickup_requests.status` (coarse: pending/approved/assigned/
///     collecting/completed/cancelled).
///   * [assignmentStatus] — `pickup_assignments.status` for THIS rider
///     (finer: assigned/accepted/en_route/collecting/completed/cancelled);
///     this is what tells a rider where they are in the job.
/// Rider responses carry no reward/price fields — none are shown.
class RiderPickupSummary {
  const RiderPickupSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.assignmentStatus,
    required this.pickupDate,
    required this.pickupTime,
    required this.customerName,
    required this.customerPhone,
    required this.addressSummary,
    required this.centreName,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
  });

  factory RiderPickupSummary.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final centre = json['centre'] as Map<String, dynamic>?;
    return RiderPickupSummary(
      id: json['id'] as int,
      reference: json['reference'] as String,
      status: json['status'] as String,
      assignmentStatus: json['assignment_status'] as String?,
      pickupDate: json['pickup_date'] as String?,
      pickupTime: json['pickup_time'] as String?,
      customerName: customer?['name'] as String?,
      customerPhone: customer?['phone_number'] as String?,
      addressSummary: json['address_summary'] as String?,
      centreName: centre?['name'] as String?,
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
    );
  }

  final int id;
  final String reference;
  final String status;
  final String? assignmentStatus;
  final String? pickupDate;
  final String? pickupTime;
  final String? customerName;
  final String? customerPhone;
  final String? addressSummary;
  final String? centreName;
  final double? estimatedWeightKg;
  final double? actualWeightKg;

  /// The rider-facing status: the assignment's own state when present,
  /// otherwise the pickup's.
  String get displayStatus => assignmentStatus ?? status;
}
