import '../../../../core/api/api_client.dart';
import '../models/address.dart';

/// EcoXchange Mobile — Customer's saved pickup addresses (Stage 3).
/// `/customer/addresses` CRUD, shaped exactly like
/// `Api\Customer\AddressController` (confirmed by inspection). Coordinates
/// are always resolved server-side (client-supplied `latitude`/`longitude`
/// are an optional override the controller accepts — this app never sends
/// them, since it has no map/GPS picker in this stage; the server's own
/// `GeocodingService` fallback resolves coordinates from the address text).
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

  Future<AddressModel> createAddress({
    String? label,
    required String houseNo,
    required String streetName,
    required String city,
    required String postcode,
    required String state,
    bool isDefault = false,
  }) async {
    final data = await _api.post('/customer/addresses', data: {
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'house_no': houseNo,
      'street_name': streetName,
      'city': city,
      'postcode': postcode,
      'state': state,
      'is_default': isDefault,
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
  }) async {
    final data = await _api.put('/customer/addresses/$id', data: {
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      'house_no': houseNo,
      'street_name': streetName,
      'city': city,
      'postcode': postcode,
      'state': state,
      'is_default': isDefault,
    });
    return AddressModel.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int id) async {
    await _api.delete('/customer/addresses/$id');
  }
}
