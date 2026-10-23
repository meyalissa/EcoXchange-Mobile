import '../../../../core/api/api_client.dart';
import '../models/address.dart';

/// EcoXchange Mobile — Customer's saved pickup addresses (Stage 3; Smart
/// Address Search added later). `/customer/addresses` CRUD, shaped exactly
/// like `Api\Customer\AddressController` (confirmed by inspection).
///
/// Coordinate resolution priority mirrors the controller's own
/// `resolveCoordinates()` exactly: client-supplied `latitude`/`longitude`
/// first (now genuinely sent — once the user selects a real Places search
/// suggestion, its own resolved coordinates go straight through), then the
/// server's `GeocodingService` text-geocoding fallback when none are sent
/// (manual-entry-only path). Never a second provider — [search] calls the
/// same server-side `GooglePlacesService` the website's own address search
/// is conceptually built on, just via this app's own backend endpoint
/// rather than a client-side Google SDK call (the website's API key is
/// HTTP-referrer-restricted and cannot be called directly from a native
/// app at all — see AddAddressScreen's docblock).
class CustomerAddressRepository {
  CustomerAddressRepository(this._api);

  final ApiClient _api;

  Future<List<AddressModel>> getAddresses() async {
    final data = await _api.get('/customer/addresses');
    return (data['addresses'] as List<dynamic>).map((e) => AddressModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AddressModel> getAddress(int id) async {
    final data = await _api.get('/customer/addresses/$id');
    return AddressModel.fromJson(data['address'] as Map<String, dynamic>);
  }

  /// `GET /customer/addresses/search` — real Google Places (New) Text
  /// Search results, server-side. [lat]/[lng] only bias ranking toward a
  /// rough area (never required, never presented as "your location") —
  /// this app has no GPS/map picker, so these are always omitted today;
  /// the endpoint already defaults to a Malaysia-wide bias.
  Future<List<PlaceSuggestion>> search(String query, {double? lat, double? lng}) async {
    final data = await _api.get('/customer/addresses/search', query: {
      'query': query,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return (data['suggestions'] as List<dynamic>).map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AddressModel> createAddress({
    String? label,
    required String houseNo,
    required String streetName,
    required String city,
    required String postcode,
    required String state,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _api.post('/customer/addresses', data: {
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'house_no': houseNo,
      'street_name': streetName,
      'city': city,
      'postcode': postcode,
      'state': state,
      'is_default': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return AddressModel.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<AddressModel> updateAddress(
    int id, {
    String? label,
    required String houseNo,
    required String streetName,
    required String city,
    required String postcode,
    required String state,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _api.put('/customer/addresses/$id', data: {
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'house_no': houseNo,
      'street_name': streetName,
      'city': city,
      'postcode': postcode,
      'state': state,
      'is_default': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return AddressModel.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int id) async {
    await _api.delete('/customer/addresses/$id');
  }
}
