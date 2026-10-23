import 'pickup_booking.dart' show ReviewImage;

/// Task 3 — mirrors `PickupCancellationController::REASONS` exactly (server
/// key -> label), the one reason catalogue in the system (inspection
/// confirmed no pre-existing one to reuse). `'other'` is handled specially
/// by the UI (shows a free-text field instead of just sending this label).
const pickupCancelReasons = <String, String>{
  'wrong_items': 'I selected the wrong items.',
  'wrong_address': 'I entered the wrong address.',
  'unavailable': 'I am no longer available.',
  'change_schedule': 'I want to change the pickup schedule.',
  'other': 'Other',
};

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
    required this.bookingMode,
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
    required this.images,
    required this.cancellationReason,
  });

  factory PickupDetail.fromJson(Map<String, dynamic> json) {
    return PickupDetail(
      id: json['id'] as int,
      reference: json['reference'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      bookingMode: json['booking_mode'] as String? ?? 'scheduled',
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
      // Display All Uploaded Photos task — every photo from this pickup's
      // scan session, not just the first (see PickupDetailResource's
      // 'images' field / PickupRequest::uploadedImages()'s docblock for
      // the backend side of this). Same shape ReviewResult.images already
      // uses, so this reuses that exact model — never a second, parallel
      // image-list type.
      images: (json['images'] as List<dynamic>?)?.map((e) => ReviewImage.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      // Task 3 — only ever non-null once status is 'cancelled' (see
      // PickupDetailResource's own gating).
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }

  final int id;
  final String reference;
  final String status;
  final String? notes;

  /// `'now'` or `'scheduled'` — see `PickupTimeService::BOOKING_MODES`.
  /// Defaults to `'scheduled'` for any older server response that predates
  /// this field, matching the column's own DB default.
  final String bookingMode;
  bool get isPickupNow => bookingMode == 'now';
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

  /// Every photo from this pickup's scan session, in upload order — never
  /// just the representative/first one. Empty when the pickup has no
  /// attached photos at all (same condition [imageUrl] being null reflects).
  final List<ReviewImage> images;
  final String? cancellationReason;

  /// Client-side mirror of `PickupRequest::isCancellableByCustomer()` —
  /// used only to decide whether to SHOW the Cancel Pickup button at all;
  /// the server re-checks this for real (and can reject with 409
  /// INVALID_TRANSITION) immediately before actually cancelling, since
  /// this snapshot can go stale between opening the screen and tapping
  /// Confirm. Never used to silently hide a genuine server-side rejection.
  bool get isCancellableByCustomer => (status == 'pending' || status == 'approved') && assignedRider == null;
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
