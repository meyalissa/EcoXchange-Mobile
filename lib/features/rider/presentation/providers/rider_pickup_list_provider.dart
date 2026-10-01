import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../../customer/data/models/pagination.dart';
import '../../data/models/rider_pickup_summary.dart';
import '../../data/repositories/rider_pickup_repository.dart';

/// EcoXchange Mobile — Rider "My Pickups" state: the real `status` filter,
/// server-driven pagination, loading/error and pull-to-refresh. Same shape
/// as the Customer PickupListProvider.
class RiderPickupListProvider extends ChangeNotifier {
  RiderPickupListProvider(this._repository);

  final RiderPickupRepository _repository;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;
  List<RiderPickupSummary> _pickups = const [];
  Pagination? _pagination;
  String? _statusFilter;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  ApiException? get error => _error;
  List<RiderPickupSummary> get pickups => _pickups;
  Pagination? get pagination => _pagination;
  String? get statusFilter => _statusFilter;
  bool get hasMore => _pagination?.hasNextPage ?? false;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.getPickups(status: _statusFilter, page: 1);
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
      final result = await _repository.getPickups(status: _statusFilter, page: nextPage);
      _pickups = [..._pickups, ...result.pickups];
      _pagination = result.pagination;
    } on ApiException catch (e) {
      _error = e; // non-fatal — the already-loaded list stays visible
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
}
