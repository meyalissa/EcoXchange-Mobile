import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/rider_pickup_action.dart';
import '../../data/models/rider_pickup_detail.dart';
import '../../data/repositories/rider_pickup_repository.dart';

/// EcoXchange Mobile — one rider pickup: its detail plus the four real
/// actions (Phase R2.1; the buttons come in R2.2).
///
/// The SERVER is the source of truth:
///   * after a successful action, [pickup] becomes the pickup Laravel
///     returned — never a locally edited copy, and never optimistically
///     "completed" before Laravel confirms it;
///   * a rejected action keeps the real [ApiException] in [actionError]
///     (409 INVALID_TRANSITION, 403, 404, 422 …), and a 409 also re-reads
///     the pickup so the screen shows its actual current state.
/// Only [nextAction] — the one action the current assignment status allows
/// — can be submitted, and only one action at a time.
class RiderPickupDetailProvider extends ChangeNotifier {
  RiderPickupDetailProvider(this._repository, this.pickupId, {this.onPickupChanged});

  final RiderPickupRepository _repository;
  final int pickupId;

  /// Called after a confirmed successful action, so lists/dashboard that
  /// show this pickup can refresh.
  final VoidCallback? onPickupChanged;

  bool _isLoading = false;
  ApiException? _loadError;
  RiderPickupDetail? _pickup;

  RiderPickupAction? _submitting;
  ApiException? _actionError;
  RiderPickupAction? _lastCompletedAction;

  bool get isLoading => _isLoading;
  ApiException? get loadError => _loadError;
  RiderPickupDetail? get pickup => _pickup;

  /// The action in flight, if any.
  RiderPickupAction? get submittingAction => _submitting;
  bool get isSubmitting => _submitting != null;
  ApiException? get actionError => _actionError;

  /// The last action Laravel confirmed (for a success message).
  RiderPickupAction? get lastCompletedAction => _lastCompletedAction;

  /// The single action the pickup's current assignment status allows, or
  /// null (not loaded, completed, cancelled).
  RiderPickupAction? get nextAction => _pickup == null ? null : RiderPickupAction.nextFor(_pickup!.assignment?.status);

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _pickup = await _repository.getPickupDetail(pickupId);
    } on ApiException catch (e) {
      _loadError = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> accept() => _perform(RiderPickupAction.accept, () => _repository.acceptPickup(pickupId));

  Future<bool> start() => _perform(RiderPickupAction.start, () => _repository.startPickup(pickupId));

  Future<bool> collect() => _perform(RiderPickupAction.collect, () => _repository.collectPickup(pickupId));

  /// [items]/[newItems] are the rider's measured quantities and weights,
  /// sent exactly as `complete` expects; reward and totals stay server-side.
  Future<bool> complete({List<RiderCollectedItem> items = const [], List<RiderExtraItem> newItems = const []}) =>
      _perform(RiderPickupAction.complete, () => _repository.completePickup(pickupId, items: items, newItems: newItems));

  /// Returns true only when Laravel confirmed the action. Returns false
  /// without any request when another action is in flight or [action] is
  /// not the pickup's [nextAction].
  Future<bool> _perform(RiderPickupAction action, Future<RiderPickupDetail> Function() call) async {
    if (_submitting != null || action != nextAction) return false;

    _submitting = action;
    _actionError = null;
    _lastCompletedAction = null;
    notifyListeners();

    try {
      _pickup = await call();
      _lastCompletedAction = action;
      onPickupChanged?.call();
      return true;
    } on ApiException catch (e) {
      _actionError = e;
      if (e is ServerException && e.statusCode == 409) {
        await _refreshAfterConflict();
      }
      return false;
    } finally {
      _submitting = null;
      notifyListeners();
    }
  }

  /// The pickup changed underneath us — show its real current state. A
  /// failure here keeps the 409 as the error to show.
  Future<void> _refreshAfterConflict() async {
    try {
      _pickup = await _repository.getPickupDetail(pickupId);
    } on ApiException {
      // keep the action error; the existing pickup stays displayed
    }
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }
}
