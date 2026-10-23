import '../../../../core/api/api_client.dart';
import '../models/pagination.dart';
import '../models/pickup_detail.dart';
import '../models/pickup_summary.dart';

/// EcoXchange Mobile — GET /api/v1/customer/pickups (+ /{pickup}). Only the
/// two filters the real API validates are ever sent — `status` (one of
/// pending/approved/assigned/collecting/completed/cancelled) and `month`
/// (Y-m) — confirmed via Api\Customer\PickupController::index()'s own
/// validate() call. No other filter (e.g. free-text search) is invented.
class CustomerPickupRepository {
  CustomerPickupRepository(this._api);

  final ApiClient _api;

  Future<({List<PickupSummary> pickups, Pagination pagination})> getPickups({
    String? status,
    String? month,
    int page = 1,
  }) async {
    final data = await _api.get('/customer/pickups', query: {
      if (status != null && status != 'all') 'status': status,
      if (month != null) 'month': month,
      'page': page,
    });

    final pickups = (data['pickups'] as List<dynamic>).map((e) => PickupSummary.fromJson(e as Map<String, dynamic>)).toList();
    final pagination = Pagination.fromJson(data['pagination'] as Map<String, dynamic>);

    return (pickups: pickups, pagination: pagination);
  }

  Future<PickupDetail> getPickupDetail(int id) async {
    final data = await _api.get('/customer/pickups/$id');
    return PickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }

  /// Task 3 — `POST /customer/pickups/{id}/cancel`. [reason] is one of
  /// [pickupCancelReasons]'s keys (e.g. `'wrong_items'`); for
  /// `'other'`, [reasonText] is the customer's own free-text description
  /// (required by the server in that case — see that controller's
  /// validation). Throws the real `ApiException` on any rejection,
  /// including the 409 the server sends when the pickup is no longer
  /// eligible by the time this request reaches it — never silently
  /// swallowed, the caller decides how to show it.
  Future<PickupDetail> cancelPickup(int id, {required String reason, String? reasonText}) async {
    final data = await _api.post('/customer/pickups/$id/cancel', data: {
      'reason': reason,
      if (reasonText != null) 'reason_text': reasonText,
    });
    return PickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }
}
