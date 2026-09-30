import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/pagination.dart';
import '../../data/models/pickup_summary.dart';
import '../../data/repositories/customer_pickup_repository.dart';

/// EcoXchange Mobile — Pickup List screen state: filters (status/month —
/// the only two the real API supports, see CustomerPickupRepository),
/// server-driven pagination (never fetches everything and paginates
/// locally), loading/error, and pull-to-refresh.
class PickupListProvider extends ChangeNotifier {
  PickupListProvider(this._repository);

  final CustomerPickupRepository _repository;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;
  List<PickupSummary> _pickups = const [];
  Pagination? _pagination;
  String? _statusFilter;
  String? _monthFilter;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  ApiException? get error => _error;
  List<PickupSummary> get pickups => _pickups;
  Pagination? get pagination => _pagination;
  String? get statusFilter => _statusFilter;
  String? get monthFilter => _monthFilter;
  bool get hasMore => _pagination?.hasNextPage ?? false;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.getPickups(status: _statusFilter, month: _monthFilter, page: 1);
      _pickups = result.pickups;
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = (_pagination?.currentPage ?? 1) + 1;
      final result = await _repository.getPickups(status: _statusFilter, month: _monthFilter, page: nextPage);
      _pickups = [..._pickups, ...result.pickups];
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e; // surfaced non-fatally — the already-loaded list stays visible
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> setStatusFilter(String? status) {
    _statusFilter = status;
    return load();
  }

  Future<void> setMonthFilter(String? month) {
    _monthFilter = month;
    return load();
  }
}
