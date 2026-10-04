/// EcoXchange Mobile — full pickup detail, shaped EXACTLY like
/// `App\Http\Resources\Customer\PickupDetailResource` (confirmed by
/// inspection — every field below has a real counterpart there, nothing
/// invented). `image_url` is the real, existing `PickupRequest::
/// uploadedImageUrl()` value — null when no photo was ever attached.
class PickupDetail {
  const PickupDetail({
    required this.id,
    required this.reference,
    required this.status,
    required this.notes,
    required this.pickupDate,
    required this.pickupTime,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
    required this.estimatedReward,
    required this.actualReward,
    required this.createdAt,
    required this.address,
    required this.items,
    required this.centre,
    required this.assignedRider,
    required this.trackingRoute,
    required this.imageUrl,
  });

  factory PickupDetail.fromJson(Map<String, dynamic> json) {
    return PickupDetail(
      id: json['id'] as int,
      reference: json['reference'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      pickupDate: json['pickup_date'] as String?,
      pickupTime: json['pickup_time'] as String?,
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
      estimatedReward: (json['estimated_reward'] as num?)?.toDouble(),
      actualReward: (json['actual_reward'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
      address: json['address'] != null ? PickupAddress.fromJson(json['address'] as Map<String, dynamic>) : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PickupDetailItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      centre: json['centre'] != null ? PickupCentreRef.fromJson(json['centre'] as Map<String, dynamic>) : null,
      assignedRider:
          json['assigned_rider'] != null ? AssignedRider.fromJson(json['assigned_rider'] as Map<String, dynamic>) : null,
      // Server key is "tracking_route" (not "route") -- see
      // PickupDetailResource's docblock: a pre-existing test forbids the
      // literal key "route" anywhere in a Customer API response, guarding
      // against internal dispatch/ACO data leaking.
      trackingRoute:
          json['tracking_route'] != null ? PickupTrackingRoute.fromJson(json['tracking_route'] as Map<String, dynamic>) : null,
      imageUrl: json['image_url'] as String?,
    );
  }

  final int id;
  final String reference;
  final String status;
  final String? notes;
  final String? pickupDate;
  final String? pickupTime;
  final double? estimatedWeightKg;
  final double? actualWeightKg;
  final double? estimatedReward;
  final double? actualReward;
  final String? createdAt;
  final PickupAddress? address;
  final List<PickupDetailItem> items;
  final PickupCentreRef? centre;
  final AssignedRider? assignedRider;

  /// Road route from the rider's current position to [address], computed
  /// server-side. Null whenever there's no rider position to route from,
  /// no pickup address coordinate to route to, or the Routes API call
  /// itself failed/is unconfigured — never fabricated client-side.
  final PickupTrackingRoute? trackingRoute;
  final String? imageUrl;
}

/// `tracking_route` in PickupDetailResource — a real Google Routes API
/// result, never a straight-line/Haversine substitute computed on-device.
class PickupTrackingRoute {
  const PickupTrackingRoute({required this.distanceMeters, required this.durationSeconds, required this.polyline});

  factory PickupTrackingRoute.fromJson(Map<String, dynamic> json) {
    return PickupTrackingRoute(
      distanceMeters: json['distance_meters'] as int,
      durationSeconds: json['duration_seconds'] as int,
      polyline: json['polyline'] as String,
    );
  }

  final int distanceMeters;
  final int durationSeconds;
  final String polyline;
}

class PickupAddress {
  const PickupAddress({required this.formatted, required this.latitude, required this.longitude});

  factory PickupAddress.fromJson(Map<String, dynamic> json) {
    return PickupAddress(
      formatted: json['formatted'] as String? ?? '—',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  final String formatted;
  final double? latitude;
  final double? longitude;
}

class PickupDetailItem {
  const PickupDetailItem({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.itemImage,
    required this.quantity,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
    required this.pricePerKgSnapshot,
  });

  factory PickupDetailItem.fromJson(Map<String, dynamic> json) {
    return PickupDetailItem(
      itemId: json['item_id'] as int?,
      itemName: json['item_name'] as String? ?? '—',
      category: json['category'] as String?,
      itemImage: json['item_image'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
      pricePerKgSnapshot: (json['price_per_kg_snapshot'] as num?)?.toDouble(),
    );
  }

  final int? itemId;
  final String itemName;
  final String? category;
  final String? itemImage;
  final int quantity;
  final double? estimatedWeightKg;
  final double? actualWeightKg;
  final double? pricePerKgSnapshot;
}

class PickupCentreRef {
  const PickupCentreRef({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
  });

  factory PickupCentreRef.fromJson(Map<String, dynamic> json) {
    return PickupCentreRef(
      name: json['name'] as String? ?? '—',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
    );
  }

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
}

class AssignedRider {
  const AssignedRider({
    required this.name,
    required this.phoneNumber,
    required this.vehicleType,
    required this.vehiclePlateNo,
    required this.assignmentStatus,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.locationUpdatedAt,
  });

  factory AssignedRider.fromJson(Map<String, dynamic> json) {
    return AssignedRider(
      name: json['name'] as String? ?? '—',
      phoneNumber: json['phone_number'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePlateNo: json['vehicle_plate_no'] as String?,
      assignmentStatus: json['assignment_status'] as String? ?? '',
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      locationUpdatedAt: json['location_updated_at'] != null ? DateTime.tryParse(json['location_updated_at'] as String) : null,
    );
  }

  final String name;
  final String? phoneNumber;
  final String? vehicleType;
  final String? vehiclePlateNo;
  final String assignmentStatus;
  final double? currentLatitude;
  final double? currentLongitude;

  /// When the rider's GPS was last actually written server-side — lets the
  /// UI say "updated just now" vs. a stale position honestly, instead of
  /// claiming the marker is live when the rider's device stopped sending.
  final DateTime? locationUpdatedAt;
}
