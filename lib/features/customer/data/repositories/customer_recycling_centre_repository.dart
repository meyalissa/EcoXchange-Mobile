import '../../../../core/api/api_client.dart';
import '../models/recycling_centre.dart';

/// EcoXchange Mobile — GET /api/v1/customer/recycling-centres (+ /{centre}).
class CustomerRecyclingCentreRepository {
  CustomerRecyclingCentreRepository(this._api);

  final ApiClient _api;

  Future<List<RecyclingCentreModel>> getCentres() async {
    final data = await _api.get('/customer/recycling-centres');
    return (data['centres'] as List<dynamic>).map((e) => RecyclingCentreModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RecyclingCentreModel> getCentreDetail(int id) async {
    final data = await _api.get('/customer/recycling-centres/$id');
    return RecyclingCentreModel.fromJson(data['centre'] as Map<String, dynamic>);
  }
}
