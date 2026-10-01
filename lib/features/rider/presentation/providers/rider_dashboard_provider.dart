import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/rider_dashboard.dart';
import '../../data/repositories/rider_dashboard_repository.dart';

/// EcoXchange Mobile — Rider Dashboard state: loading/error/data +
/// pull-to-refresh. See RiderDashboardRepository for the real endpoint.
class RiderDashboardProvider extends ChangeNotifier {
  RiderDashboardProvider(this._repository);

  final RiderDashboardRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  RiderDashboard? _data;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  RiderDashboard? get data => _data;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _repository.getDashboard();
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
