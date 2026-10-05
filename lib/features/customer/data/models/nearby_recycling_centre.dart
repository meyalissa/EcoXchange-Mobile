/// EcoXchange Mobile — recycling centre DISCOVERY, shaped EXACTLY like
/// `App\Http\Resources\Customer\NearbyRecyclingCentreResource` (confirmed
/// by inspection).
///
/// Deliberately separate from [RecyclingCentreModel] (the ELIGIBILITY
/// list's shape — `/customer/recycling-centres`, scoped server-side to
/// `acceptingPickups()` only). This model answers "can the customer find
/// this real centre nearby?", a different question from "can EcoXchange
/// pick up from it?" (that's [pickupSupported] here, and the entirely
/// separate `EligibleCentre`/`PickupBookingProvider` flow for an actual
/// booking). Never computed client-side — every field, including
/// [pickupSupported] and [distanceKm], is the server's own value.
class NearbyRecyclingCentre {
  const NearbyRecyclingCentre({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.website,
    required this.rating,
    required this.businessStatus,
    required this.googleMapsUrl,
    required this.source,
    required this.pickupSupported,
    required this.distanceKm,
  });

  factory NearbyRecyclingCentre.fromJson(Map<String, dynamic> json) {
    return NearbyRecyclingCentre(
      id: json['id'] as int,
      name: json['name'] as String? ?? '—',
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postcode: json['postcode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      businessStatus: json['business_status'] as String?,
      googleMapsUrl: json['google_maps_url'] as String?,
      source: json['source'] as String? ?? 'self_registered',
      pickupSupported: json['pickup_supported'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? postcode;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? website;
  final double? rating;
  final String? businessStatus;
  final String? googleMapsUrl;

  /// `self_registered` | `admin_created` | `google_places`.
  final String source;

  /// The ONLY thing that determines whether this centre can be selected
  /// for an actual EcoXchange pickup — server-computed from the real
  /// `acceptingPickups()` (verified + active) check, never inferred from
  /// [source] on the client (a `google_places` centre CAN become true once
  /// an admin verifies it; a `self_registered` one can be false while
  /// still pending review).
  final bool pickupSupported;

  final double? distanceKm;

  bool get isGooglePlaces => source == 'google_places';

  String get distanceLabel {
    final km = distanceKm;
    if (km == null) return '';
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
