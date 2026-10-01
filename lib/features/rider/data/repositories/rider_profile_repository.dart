import '../../../../core/api/api_client.dart';
import '../models/rider_profile.dart';

/// EcoXchange Mobile — GET /api/v1/rider/profile (the rider's own profile
/// plus lifetime/this-month totals computed by Api\Rider\ProfileController).
class RiderProfileRepository {
  RiderProfileRepository(this._api);

  final ApiClient _api;

  Future<RiderProfile> getProfile() async {
    final data = await _api.get('/rider/profile');
    return RiderProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }
}
