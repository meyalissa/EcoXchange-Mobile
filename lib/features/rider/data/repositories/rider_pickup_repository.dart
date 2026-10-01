import '../../../../core/api/api_client.dart';
import '../../../customer/data/models/pagination.dart';
import '../models/rider_pickup_detail.dart';
import '../models/rider_pickup_summary.dart';

/// EcoXchange Mobile — GET /api/v1/rider/pickups (+ /{pickup}): every pickup
/// assigned to the logged-in rider, newest first, 15 per page. The only
/// filter the real API validates is `status` (the pickup_requests.status
/// enum — see Api\Rider\PickupController::index()); nothing else is sent.
/// A pickup assigned to another rider is a 403 (ForbiddenException).
///
/// READ-ONLY in Phase R1 — accept/start/collect/complete are a later phase.
class RiderPickupRepository {
  RiderPickupRepository(this._api);

  final ApiClient _api;

  Future<({List<RiderPickupSummary> pickups, Pagination pagination})> getPickups({String? status, int page = 1}) async {
    final data = await _api.get('/rider/pickups', query: {
      if (status != null && status != 'all') 'status': status,
      'page': page,
    });

    final pickups = (data['pickups'] as List<dynamic>)
        .map((e) => RiderPickupSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = Pagination.fromJson(data['pagination'] as Map<String, dynamic>);

    return (pickups: pickups, pagination: pagination);
  }

  Future<RiderPickupDetail> getPickupDetail(int id) async {
    final data = await _api.get('/rider/pickups/$id');
    return RiderPickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }
}
