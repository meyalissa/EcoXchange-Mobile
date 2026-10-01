/// EcoXchange Mobile — `GET /api/v1/rider/profile`, shaped like
/// `App\Http\Resources\Rider\RiderProfileResource`.
///
/// Deliberately NOT parsed: `ic_number` and `driving_license_no` (personal
/// identity documents the app has no use for), and the raw current
/// coordinates. The resource still returns them; this model simply never
/// holds them, so no screen can show them by accident.
class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.riderType,
    required this.vehicleType,
    required this.vehiclePlateNo,
    required this.riderStatus,
    required this.coverageZone,
    required this.workingRadiusKm,
    required this.centreName,
    required this.totalCompleted,
    required this.completedThisMonth,
    required this.totalWeightKg,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    final centre = json['center'] as Map<String, dynamic>?;
    final stats = json['stats'] as Map<String, dynamic>;
    return RiderProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String?,
      riderType: json['rider_type'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePlateNo: json['vehicle_plate_no'] as String?,
      riderStatus: json['rider_status'] as String?,
      coverageZone: json['coverage_zone'] as String?,
      workingRadiusKm: (json['working_radius_km'] as num?)?.toDouble(),
      centreName: centre?['name'] as String?,
      totalCompleted: stats['total_completed'] as int,
      completedThisMonth: stats['completed_month'] as int,
      totalWeightKg: (stats['total_weight_kg'] as num).toDouble(),
    );
  }

  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? riderType;
  final String? vehicleType;
  final String? vehiclePlateNo;
  final String? riderStatus;
  final String? coverageZone;
  final double? workingRadiusKm;

  /// A dedicated rider's recycling centre; null for a freelance rider.
  final String? centreName;

  final int totalCompleted;
  final int completedThisMonth;
  final double totalWeightKg;
}
