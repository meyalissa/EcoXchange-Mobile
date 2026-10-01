/// EcoXchange Mobile — `GET /api/v1/rider/pickups/{pickup}`, shaped like
/// `App\Http\Resources\Rider\RiderPickupDetailResource`. Read-only in
/// Phase R1: the fields a rider needs to find, contact and collect a
/// pickup. No reward/price exists in the rider response, so none is shown;
/// raw coordinates are kept for a later navigation phase and no distance
/// or ETA is computed.
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

  /// The rider-facing status: this rider's assignment state when present.
  String get displayStatus => assignment?.status ?? status;
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
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.estimatedWeightKg,
    required this.actualWeightKg,
  });

  factory RiderPickupItem.fromJson(Map<String, dynamic> json) {
    return RiderPickupItem(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String?,
      category: json['category'] as String?,
      quantity: json['quantity'] as int,
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
    );
  }

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
