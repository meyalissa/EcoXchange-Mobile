/// EcoXchange Mobile — JSON fixtures shaped exactly like
/// `App\Http\Resources\Customer\PickupDetailResource`, for customer-side
/// tracking tests. Mirrors the style of `rider_fixtures.dart`.
Map<String, dynamic> customerPickupDetailJson({
  int id = 36,
  String status = 'assigned',
  Map<String, dynamic>? address = const {
    'formatted': 'No. 12, Jalan USJ 9/5P, USJ 9, Subang Jaya',
    'latitude': 3.0428,
    'longitude': 101.5838,
  },
  Map<String, dynamic>? assignedRider,
  Map<String, dynamic>? trackingRoute,
}) {
  return {
    'id': id,
    'reference': 'PK-$id',
    'status': status,
    'notes': null,
    'pickup_date': '2026-10-04',
    'pickup_time': '08:00-10:00',
    'estimated_weight_kg': 2.6,
    'actual_weight_kg': null,
    'estimated_reward': 5.32,
    'actual_reward': null,
    'deposit_paid': false,
    'deposit_returned': false,
    'created_at': '2026-10-01T00:00:00+08:00',
    'address': address,
    'items': const [],
    'centre': null,
    'assigned_rider': assignedRider,
    'tracking_route': trackingRoute,
    'image_url': null,
  };
}

Map<String, dynamic> assignedRiderJson({
  String name = 'Azmi bin Noor',
  String assignmentStatus = 'en_route',
  double? currentLatitude = 3.12,
  double? currentLongitude = 101.62,
  String? locationUpdatedAt,
}) {
  return {
    'name': name,
    'phone_number': '+60111234567',
    'vehicle_type': 'Motorcycle',
    'vehicle_plate_no': 'BCK 3344',
    'assignment_status': assignmentStatus,
    'current_latitude': currentLatitude,
    'current_longitude': currentLongitude,
    'location_updated_at': locationUpdatedAt,
  };
}

Map<String, dynamic> trackingRouteJson({
  int distanceMeters = 2600,
  int durationSeconds = 420,
  String polyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
}) {
  return {
    'distance_meters': distanceMeters,
    'duration_seconds': durationSeconds,
    'polyline': polyline,
  };
}
