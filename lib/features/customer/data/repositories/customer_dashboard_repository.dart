import '../../../../core/api/api_client.dart';
import '../models/dashboard_data.dart';

/// EcoXchange Mobile — GET /api/v1/customer/dashboard. Pure fetch + parse;
/// no calculation happens here — every figure is already computed by
/// Api\Customer\DashboardController on the server.
class CustomerDashboardRepository {
  CustomerDashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> getDashboard() async {
    final data = await _api.get('/customer/dashboard');
    return DashboardData.fromJson(data);
  }
}
