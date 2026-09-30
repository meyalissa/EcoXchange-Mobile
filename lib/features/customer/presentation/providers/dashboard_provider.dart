import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/repositories/customer_dashboard_repository.dart';

/// EcoXchange Mobile — Dashboard screen state: loading/error/data +
/// pull-to-refresh. See CustomerDashboardRepository for the real endpoint.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository);

  final CustomerDashboardRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  DashboardData? _data;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  DashboardData? get data => _data;

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
