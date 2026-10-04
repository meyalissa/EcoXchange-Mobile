import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../../data/repositories/rider_pickup_repository.dart';

/// EcoXchange Mobile — the rider's OPEN jobs for My Tasks and Home's
/// "Today's Schedule", from the real `GET /rider/pickups` list.
///
/// The API filters by pickup status only, so every page of the two open
/// pickup statuses (`assigned` — which covers assignment assigned/accepted/
/// en_route — and `collecting`) is loaded, then grouped by the rider's
/// finer ASSIGNMENT status:
///   * pending — assigned (waiting for the rider to accept);
///   * ongoing — accepted, en_route, collecting.
/// Completed jobs use the paginated list (RiderPickupListProvider).
class RiderTasksProvider extends ChangeNotifier {
  RiderTasksProvider(this._repository, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final RiderPickupRepository _repository;
  final DateTime Function() _clock;

  /// Safety bound on pages per status (15 per page).
  static const _maxPages = 20;

  bool _isLoading = false;
  ApiException? _error;
  List<RiderPickupSummary> _open = const [];
  bool _loadedOnce = false;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  bool get loadedOnce => _loadedOnce;

  List<RiderPickupSummary> get pending => _open.where((p) => p.displayStatus == 'assigned').toList();

  List<RiderPickupSummary> get ongoing =>
      _open.where((p) => const {'accepted', 'en_route', 'collecting'}.contains(p.displayStatus)).toList();

  /// Open jobs scheduled for today (local date), by time slot.
  List<RiderPickupSummary> get today {
    final now = _clock();
    final key = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _open.where((p) => p.pickupDate == key).toList()..sort((a, b) => (a.pickupTime ?? '').compareTo(b.pickupTime ?? ''));
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final all = <RiderPickupSummary>[];
      for (final status in const ['assigned', 'collecting']) {
        for (var page = 1; page <= _maxPages; page++) {
          final result = await _repository.getPickups(status: status, page: page);
          all.addAll(result.pickups);
          if (!result.pagination.hasNextPage) break;
        }
      }
      _open = all;
      _loadedOnce = true;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
