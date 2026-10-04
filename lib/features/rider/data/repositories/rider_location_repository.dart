import '../../../../core/api/api_client.dart';

/// EcoXchange Mobile — the rider's own GPS location (POST /api/v1/rider/location).
///
/// Always writes the authenticated rider's own position; Laravel only
/// actually persists it while that rider has an active assignment
/// (accepted/en_route/collecting) — see LocationController's docblock.
/// Otherwise it's a harmless server-side no-op, never an error here.
class RiderLocationRepository {
  RiderLocationRepository(this._api);

  final ApiClient _api;

  Future<void> updateLocation(double latitude, double longitude) async {
    await _api.post('/rider/location', data: {'latitude': latitude, 'longitude': longitude});
  }
}
