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

/// Smart Address Search task — one real suggestion from
/// `GET /customer/addresses/search`, shaped exactly like
/// `AddressController::search()`'s response (confirmed by inspection).
/// Server-side only: the actual Google Places (New) Text Search call and
/// its `GOOGLE_PLACES_API_KEY` never reach this client — Flutter only ever
/// talks to its own backend. [houseNo]/[streetName]/[city]/[postcode]/
/// [state] are Google's own best-effort structured components and are
/// frequently null (e.g. a named building with no street_number
/// component) — never invented here, left for the user to fill in
/// manually, exactly like the website's own autocomplete already does.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.houseNo,
    required this.streetName,
    required this.city,
    required this.state,
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'] as String,
      name: json['name'] as String?,
      formattedAddress: json['formatted_address'] as String? ?? '',
      houseNo: json['house_no'] as String?,
      streetName: json['street_name'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postcode: json['postcode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  final String placeId;
  final String? name;
  final String formattedAddress;
  final String? houseNo;
  final String? streetName;
  final String? city;
  final String? state;
  final String? postcode;

  /// Null on the rare result Google itself returned with no location —
  /// [hasCoordinates] is the only thing that decides whether this
  /// suggestion is selectable, never an assumption that every result has one.
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}
