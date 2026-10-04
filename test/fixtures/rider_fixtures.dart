// ============================================================================
// TEST FIXTURES — hand-written, API-SHAPED Rider responses for unit/widget
// tests only. They mirror the real Laravel resources field for field
// (Api\Rider\DashboardController, RiderPickupSummaryResource,
// RiderPickupDetailResource, RiderProfileResource); they are not recorded
// production data and are never used by production code.
// ============================================================================

Map<String, dynamic> riderPickupSummaryJson({
  int id = 12,
  String status = 'assigned',
  String? assignmentStatus = 'assigned',
  bool withCustomer = true,
  String pickupDate = '2026-10-02',
  List<String>? itemNames,
}) =>
    {
      'id': id,
      'reference': 'PK-$id',
      'status': status,
      // RiderPickupSummaryResource uses when(): absent, not null, if missing.
      'assignment_status': ?assignmentStatus,
      'pickup_date': pickupDate,
      'pickup_time': '10:00-12:00',
      if (withCustomer) 'customer': {'name': 'Nurul Aisyah', 'phone_number': '+60123456780'},
      'address_summary': 'No. 12, Jalan USJ 9/5P, Subang Jaya',
      'centre': {'name': 'EcoGreen Subang Jaya'},
      'estimated_weight_kg': 2.5,
      'actual_weight_kg': null,
      'created_at': '2026-09-30T10:00:00+08:00',
      'item_names': ?itemNames,
    };

Map<String, dynamic> riderDashboardJson({
  int assignedToday = 2,
  int completedToday = 1,
  num weightToday = 3.4,
  Map<String, dynamic>? activeTask,
  Map<String, dynamic>? nextPickup,
}) =>
    {
      'stats': {'assigned_today': assignedToday, 'completed_today': completedToday, 'weight_today': weightToday},
      'active_task': activeTask,
      'next_pickup': nextPickup,
    };

Map<String, dynamic> riderPickupDetailJson({
  int id = 12,
  String assignmentStatus = 'accepted',
  Map<String, dynamic>? locations,
  bool addressHasCoordinates = true,
}) =>
    {
      'id': id,
      'reference': 'PK-$id',
      'status': 'assigned',
      'pickup_date': '2026-10-02',
      'pickup_time': '10:00-12:00',
      'notes': 'Please call on arrival.',
      'created_at': '2026-09-30T10:00:00+08:00',
      'customer': {'name': 'Nurul Aisyah', 'phone_number': '+60123456780'},
      'address': {
        'house_no': 'No. 12',
        'street_name': 'Jalan USJ 9/5P',
        'city': 'Subang Jaya',
        'postcode': '47620',
        'state': 'Selangor',
        'formatted': 'No. 12, Jalan USJ 9/5P, 47620 Subang Jaya, Selangor',
        'latitude': addressHasCoordinates ? 3.0428 : null,
        'longitude': addressHasCoordinates ? 101.5838 : null,
      },
      'centre': {
        'name': 'EcoGreen Subang Jaya',
        'address': 'No. 5, Jalan USJ 21/1, 47630 Subang Jaya',
        'latitude': 3.03,
        'longitude': 101.58,
        'phone': '+60355551234',
      },
      'items': [
        {
          'pickup_item_id': 31,
          'item_id': 10,
          'item_name': 'Glass Bottle',
          'category': 'Glass',
          'item_image': null,
          'quantity': 2,
          'estimated_weight_kg': 0.5,
          'actual_weight_kg': null,
        },
        {
          'pickup_item_id': 32,
          'item_id': 1,
          'item_name': 'Plastic Bottle',
          'category': 'Plastic',
          'item_image': null,
          'quantity': 2,
          'estimated_weight_kg': 0.06,
          'actual_weight_kg': null,
        },
      ],
      'estimated_weight_kg': 0.56,
      'actual_weight_kg': null,
      'image_url': null,
      'assignment': {
        'status': assignmentStatus,
        'assigned_at': '2026-09-30T11:00:00+08:00',
        'accepted_at': '2026-09-30T11:05:00+08:00',
        'completed_at': null,
      },
      'locations': locations ?? {'rider': null, 'pickup': {'latitude': 3.0428, 'longitude': 101.5838}, 'recycling_centre': null},
    };

Map<String, dynamic> riderProfileJson({bool withCentre = true}) => {
      'id': 7,
      'name': 'Ahmad Farhan bin Razak',
      'email': 'rider@example.com',
      'phone_number': '+60129876543',
      'rider_type': 'dedicated',
      'vehicle_type': 'motorcycle',
      'vehicle_plate_no': 'WXY1234',
      'rider_status': 'available',
      'coverage_zone': 'Subang Jaya',
      'ic_number': '900101-10-1234',
      'driving_license_no': 'D1234567',
      'working_radius_km': 10,
      if (withCentre) 'center': {'id': 3, 'name': 'EcoGreen Subang Jaya'},
      'current_latitude': 3.04,
      'current_longitude': 101.58,
      'last_location_update': null,
      'stats': {'total_completed': 14, 'completed_month': 3, 'total_weight_kg': 42.75},
    };

Map<String, dynamic> paginationJson({int current = 1, int last = 1, int total = 1}) =>
    {'current_page': current, 'last_page': last, 'per_page': 15, 'total': total};
