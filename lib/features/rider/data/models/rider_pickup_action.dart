/// EcoXchange Mobile — the four Rider pickup actions, mirroring
/// `Api\Rider\PickupActionController` / `RiderPickupActionService`.
///
/// Each action is one fixed `pickup_assignments.status` transition:
///   accept   assigned   -> accepted
///   start    accepted   -> en_route
///   collect  en_route   -> collecting   (pickup status also -> collecting)
///   complete collecting -> completed    (with the collected items)
///
/// The SERVER enforces this; an out-of-order action is a 409 with
/// `errors.code = INVALID_TRANSITION`. [nextFor] only tells the app which
/// single action makes sense next, so it never sends one that can't apply.
enum RiderPickupAction {
  accept('accept', 'assigned'),
  start('start', 'accepted'),
  collect('collect', 'en_route'),
  complete('complete', 'collecting');

  const RiderPickupAction(this.path, this.fromStatus);

  /// Last path segment of `POST /rider/pickups/{id}/{path}`.
  final String path;

  /// The assignment status the server requires for this action.
  final String fromStatus;

  /// The one action applicable to an assignment in [assignmentStatus], or
  /// null (completed, cancelled, unknown).
  static RiderPickupAction? nextFor(String? assignmentStatus) {
    for (final action in values) {
      if (action.fromStatus == assignmentStatus) return action;
    }
    return null;
  }
}

/// One existing pickup line as collected, for `complete`'s `items[]`:
/// `{pickup_item_id, quantity, actual_weight_kg}` — exactly the fields
/// `PickupActionController::complete()` validates (`pickup_item_id` is the
/// `pickup_items.id` row, not the catalogue item id).
class RiderCollectedItem {
  const RiderCollectedItem({required this.pickupItemId, required this.quantity, required this.actualWeightKg});

  final int pickupItemId;
  final int quantity;
  final double actualWeightKg;

  Map<String, dynamic> toJson() => {
        'pickup_item_id': pickupItemId,
        'quantity': quantity,
        'actual_weight_kg': actualWeightKg,
      };
}

/// An extra catalogue item found on site, for `complete`'s `new_items[]`:
/// `{item_id, quantity, actual_weight_kg}`. Laravel merges it into an
/// existing line of the same item (adding quantity and weight) or creates a
/// new line.
class RiderExtraItem {
  const RiderExtraItem({required this.itemId, required this.quantity, required this.actualWeightKg});

  final int itemId;
  final int quantity;
  final double actualWeightKg;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'quantity': quantity,
        'actual_weight_kg': actualWeightKg,
      };
}
