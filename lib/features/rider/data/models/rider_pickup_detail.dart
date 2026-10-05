import '../../../../core/models/geo_point.dart';
import '../../../customer/data/models/pickup_detail.dart' show PickupTrackingRoute;

/// EcoXchange Mobile — `GET /api/v1/rider/pickups/{pickup}`, shaped like
/// `App\Http\Resources\Rider\RiderPickupDetailResource`. Read-only in
/// Phase R1: the fields a rider needs to find, contact and collect a
/// pickup. No reward/price exists in the rider response, so none is shown.
/// [trackingRoute] reuses the exact same server-computed route concept the
/// customer tracking screen already uses (see [PickupTrackingRoute]) —
/// never a second route format.
class RiderPickupDetail {
  const RiderPickupDetail({
    required this.id,
    required this.reference,
    required this.status,
    required this.pickupDate,
    required this.pickupTime,
    required this.notes,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.centre,
    required this.items,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
    required this.imageUrl,
    required this.assignment,
    this.locations = const RiderRouteLocations(),
    this.trackingRoute,
  });

  factory RiderPickupDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final address = json['address'] as Map<String, dynamic>?;
    final centre = json['centre'] as Map<String, dynamic>?;
    final assignment = json['assignment'] as Map<String, dynamic>?;
    return RiderPickupDetail(
      id: json['id'] as int,
      reference: json['reference'] as String,
      status: json['status'] as String,
      pickupDate: json['pickup_date'] as String?,
      pickupTime: json['pickup_time'] as String?,
      notes: json['notes'] as String?,
      customerName: customer?['name'] as String?,
      customerPhone: customer?['phone_number'] as String?,
      address: address == null ? null : RiderPickupAddress.fromJson(address),
      centre: centre == null ? null : RiderPickupCentre.fromJson(centre),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => RiderPickupItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      assignment: assignment == null ? null : RiderAssignment.fromJson(assignment),
      locations: json['locations'] is Map<String, dynamic>
          ? RiderRouteLocations.fromJson(json['locations'] as Map<String, dynamic>)
          : const RiderRouteLocations(),
      trackingRoute:
          json['tracking_route'] != null ? PickupTrackingRoute.fromJson(json['tracking_route'] as Map<String, dynamic>) : null,
    );
  }

  final int id;
  final String reference;
  final String status;
  final String? pickupDate;
  final String? pickupTime;
  final String? notes;
  final String? customerName;
  final String? customerPhone;
  final RiderPickupAddress? address;
  final RiderPickupCentre? centre;
  final List<RiderPickupItem> items;
  final double? estimatedWeightKg;
  final double? actualWeightKg;
  final String? imageUrl;
  final RiderAssignment? assignment;

  /// Raw stored coordinates (rider / pickup / recycling centre); any may be
  /// null. No distance or ETA is computed anywhere in the backend.
  final RiderRouteLocations locations;

  /// Road route from the rider's current position to [address], computed
  /// server-side (same PickupTrackingService/GoogleRoutesService the
  /// customer tracking screen uses). Null whenever there's no rider
  /// position to route from, no pickup address coordinate to route to, or
  /// the Routes API call itself failed/is unconfigured — never fabricated
  /// client-side.
  final PickupTrackingRoute? trackingRoute;

  /// The rider-facing status: this rider's assignment state when present.
  String get displayStatus => assignment?.status ?? status;
}

/// `locations` in RiderPickupDetailResource: the rider's last stored
/// position and the pickup / recycling-centre coordinates.
class RiderRouteLocations {
  const RiderRouteLocations({this.rider, this.pickup, this.recyclingCentre});

  factory RiderRouteLocations.fromJson(Map<String, dynamic> json) {
    return RiderRouteLocations(
      rider: GeoPoint.fromJson(json['rider']),
      pickup: GeoPoint.fromJson(json['pickup']),
      recyclingCentre: GeoPoint.fromJson(json['recycling_centre']),
    );
  }

  final GeoPoint? rider;
  final GeoPoint? pickup;
  final GeoPoint? recyclingCentre;
}

class RiderPickupAddress {
  const RiderPickupAddress({required this.formatted, required this.latitude, required this.longitude});

  factory RiderPickupAddress.fromJson(Map<String, dynamic> json) {
    return RiderPickupAddress(
      formatted: json['formatted'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  final String? formatted;
  final double? latitude;
  final double? longitude;
}

class RiderPickupCentre {
  const RiderPickupCentre({required this.name, required this.address, required this.phone});

  factory RiderPickupCentre.fromJson(Map<String, dynamic> json) {
    return RiderPickupCentre(
      name: json['name'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String? name;
  final String? address;
  final String? phone;
}

class RiderPickupItem {
  const RiderPickupItem({
    required this.pickupItemId,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
  });

  factory RiderPickupItem.fromJson(Map<String, dynamic> json) {
    return RiderPickupItem(
      pickupItemId: json['pickup_item_id'] as int?,
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String?,
      category: json['category'] as String?,
      quantity: json['quantity'] as int,
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
    );
  }

  /// `pickup_items.id` — this line's own id, which `complete` expects as
  /// `items[].pickup_item_id` (R2.3). Null only from an older backend that
  /// didn't return it.
  final int? pickupItemId;

  /// The catalogue `items.id`.
  final int itemId;
  final String? itemName;
  final String? category;
  final int quantity;
  final double? estimatedWeightKg;
  final double? actualWeightKg;
}

class RiderAssignment {
  const RiderAssignment({required this.status, required this.assignedAt, required this.acceptedAt, required this.completedAt});

  factory RiderAssignment.fromJson(Map<String, dynamic> json) {
    return RiderAssignment(
      status: json['status'] as String,
      assignedAt: json['assigned_at'] as String?,
      acceptedAt: json['accepted_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }

  final String status;
  final String? assignedAt;
  final String? acceptedAt;
  final String? completedAt;
}
