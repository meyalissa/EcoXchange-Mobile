import '../../../../core/api/api_client.dart';
import '../models/nearby_recycling_centre.dart';
import '../models/recycling_centre.dart';

/// EcoXchange Mobile — GET /api/v1/customer/recycling-centres (+ /{centre},
/// + /nearby).
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

  /// DISCOVERY — every real nearby centre (EcoXchange partners AND
  /// Google-Places-discovered businesses), never scoped to eligibility.
  /// `search` filters server-side against the same stored
  /// `recycling_center_profiles` row (name/address/city/state) — never a
  /// live Google Places API call. See
  /// `RecyclingCentreController::nearby()`'s docblock.
  Future<List<NearbyRecyclingCentre>> getNearby({
    required double lat,
    required double lng,
    String? search,
    double? radiusKm,
  }) async {
    final data = await _api.get('/customer/recycling-centres/nearby', query: {
      'lat': lat,
      'lng': lng,
      if (search != null && search.isNotEmpty) 'search': search,
      if (radiusKm != null) 'radius_km': radiusKm,
    });

    return (data['centres'] as List<dynamic>).map((e) => NearbyRecyclingCentre.fromJson(e as Map<String, dynamic>)).toList();
  }
}
