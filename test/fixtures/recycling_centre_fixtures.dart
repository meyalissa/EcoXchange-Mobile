// EcoXchange Mobile — hand-written, API-SHAPED recycling-centre DISCOVERY
// responses for unit/widget tests only. Mirrors
// `App\Http\Resources\Customer\NearbyRecyclingCentreResource` field for
// field; never recorded production data, never used by production code.

Map<String, dynamic> nearbyCentreJson({
  int id = 1,
  String name = 'EcoGreen Recycling Centre',
  String? address = 'No. 1, Jalan Test, 50450 Kuala Lumpur',
  String? city = 'Kuala Lumpur',
  String? state = 'Kuala Lumpur',
  String? postcode = '50450',
  double? latitude = 3.1390,
  double? longitude = 101.6869,
  String? phone = '+60312345678',
  String? website,
  double? rating,
  String? businessStatus,
  String? googleMapsUrl,
  String source = 'self_registered',
  bool pickupSupported = true,
  double? distanceKm = 1.2,
}) =>
    {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'postcode': postcode,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'website': website,
      'rating': rating,
      'business_status': businessStatus,
      'google_maps_url': googleMapsUrl,
      'source': source,
      'pickup_supported': pickupSupported,
      'distance_km': distanceKm,
    };

/// A real-shaped external (Google-Places-discovered) centre — pending,
/// never pickup-supported by default, with real Google-sourced extras.
Map<String, dynamic> externalCentreJson({
  int id = 2,
  String name = 'Discovered Scrap Metal Yard',
  double? distanceKm = 3.4,
}) =>
    nearbyCentreJson(
      id: id,
      name: name,
      address: 'Jalan Krubong, 75260 Melaka',
      city: 'Melaka',
      state: 'Melaka',
      postcode: '75260',
      latitude: 2.2838,
      longitude: 102.2408,
      phone: '+60612345678',
      website: 'https://example.com',
      rating: 4.3,
      businessStatus: 'OPERATIONAL',
      googleMapsUrl: 'https://maps.google.com/?cid=12345',
      source: 'google_places',
      pickupSupported: false,
      distanceKm: distanceKm,
    );
