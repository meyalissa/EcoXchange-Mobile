import '../../../../core/api/api_client.dart';
import '../../../customer/data/models/pagination.dart';
import '../models/rider_catalogue_item.dart';
import '../models/rider_pickup_action.dart';
import '../models/rider_pickup_detail.dart';
import '../models/rider_pickup_summary.dart';

/// EcoXchange Mobile — the rider's pickups.
///
/// Reads: GET /api/v1/rider/pickups (+ /{pickup}): every pickup assigned to
/// the logged-in rider, newest first, 15 per page. The only filter the real
/// API validates is `status` (the pickup_requests.status enum — see
/// Api\Rider\PickupController::index()); nothing else is sent.
///
/// Actions (Phase R2.1): POST /api/v1/rider/pickups/{pickup}/{accept|start|
/// collect|complete} — Api\Rider\PickupActionController. Each returns the
/// UPDATED pickup (`data.pickup`, the same RiderPickupDetailResource shape),
/// which is returned as-is — no state is invented locally. Failures arrive
/// through the normal ApiException mapping:
///   * 403 ForbiddenException — not this rider's pickup;
///   * 404 ServerException(statusCode 404) — no such pickup;
///   * 409 ServerException(statusCode 409, code INVALID_TRANSITION) —
///     the action doesn't apply to the pickup's current state;
///   * 422 ValidationException — `complete` item data rejected.
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

  /// GET /api/v1/rider/items — the active catalogue (active only, ordered by
  /// category then name, as on the web rider page) for adding extra items
  /// found on site to a completion's `new_items[]`.
  Future<List<RiderCatalogueItem>> getCatalogueItems() async {
    final data = await _api.get('/rider/items');
    return (data['items'] as List<dynamic>)
        .map((e) => RiderCatalogueItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// assigned -> accepted. No request body.
  Future<RiderPickupDetail> acceptPickup(int id) => _transition(id, RiderPickupAction.accept);

  /// accepted -> en_route ("On the way"). No request body.
  Future<RiderPickupDetail> startPickup(int id) => _transition(id, RiderPickupAction.start);

  /// en_route -> collecting (the pickup's own status also becomes
  /// collecting). No request body — collected items/weights are sent with
  /// [completePickup], not here.
  Future<RiderPickupDetail> collectPickup(int id) => _transition(id, RiderPickupAction.collect);

  /// collecting -> completed. Sends only what the rider measured:
  /// `items[]` for existing pickup lines and `new_items[]` for extra items
  /// found on site (both optional in the API). Laravel computes the total
  /// weight and reward and credits the customer; nothing of that is sent.
  Future<RiderPickupDetail> completePickup(
    int id, {
    List<RiderCollectedItem> items = const [],
    List<RiderExtraItem> newItems = const [],
  }) async {
    final data = await _api.post('/rider/pickups/$id/${RiderPickupAction.complete.path}', data: {
      if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
      if (newItems.isNotEmpty) 'new_items': [for (final i in newItems) i.toJson()],
    });
    return RiderPickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }

  Future<RiderPickupDetail> _transition(int id, RiderPickupAction action) async {
    final data = await _api.post('/rider/pickups/$id/${action.path}');
    return RiderPickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }
}
