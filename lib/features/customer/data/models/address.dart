/// EcoXchange Mobile — a customer's saved pickup address, shaped EXACTLY
/// like `App\Http\Resources\Customer\AddressResource` (confirmed by
/// inspection). Used by the pickup booking flow (Stage 3) and available for
/// standalone address management. `formatted`/`short_address` are the
/// server's own presentation strings — never rebuilt client-side from the
/// individual fields, so they can never drift from what the server means.
class AddressModel {
  const AddressModel({
    required this.id,
    required this.label,
    required this.houseNo,
    required this.streetName,
    required this.city,
    required this.postcode,
    required this.state,
    required this.formatted,
    required this.shortAddress,
    required this.latitude,
    required this.longitude,
    required this.hasCoordinates,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as int,
      label: json['label'] as String?,
      houseNo: json['house_no'] as String? ?? '',
      streetName: json['street_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postcode: json['postcode'] as String? ?? '',
      state: json['state'] as String? ?? '',
      formatted: json['formatted'] as String? ?? '',
      shortAddress: json['short_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      hasCoordinates: json['has_coordinates'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  final int id;
  final String? label;
  final String houseNo;
  final String streetName;
  final String city;
  final String postcode;
  final String state;
  final String formatted;
  final String? shortAddress;
  final double? latitude;
  final double? longitude;
  final bool hasCoordinates;
  final bool isDefault;

  /// Real label if the customer set one, else a generic fallback — never
  /// invented per-address icons/names the server never returned.
  String get displayLabel => (label != null && label!.trim().isNotEmpty) ? label! : 'Address';
}
