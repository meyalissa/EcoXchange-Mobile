import '../../../../core/api/api_client.dart';
import '../models/rider_dashboard.dart';

/// EcoXchange Mobile — GET /api/v1/rider/dashboard. Pure fetch + parse;
/// every figure is computed by Api\Rider\DashboardController.
class RiderDashboardRepository {
  RiderDashboardRepository(this._api);

  final ApiClient _api;

  Future<RiderDashboard> getDashboard() async {
    final data = await _api.get('/rider/dashboard');
    return RiderDashboard.fromJson(data);
  }
}
