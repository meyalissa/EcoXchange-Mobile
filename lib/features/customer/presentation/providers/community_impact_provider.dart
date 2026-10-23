import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/community_impact.dart';
import '../../data/repositories/community_impact_repository.dart';

/// EcoXchange Mobile — Community Impact screen state: loading/error/data +
/// the active period/state/area filters + pull-to-refresh. Changing a
/// filter re-fetches from the server (GET /customer/community-impact) —
/// never recomputed client-side, so the figures can never drift from what
/// the web Community Impact page shows for the same scope.
class CommunityImpactProvider extends ChangeNotifier {
  CommunityImpactProvider(this._repository);

  final CommunityImpactRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  CommunityImpactSummary? _data;
  String _period = 'all_time';
  String? _state;
  String? _area;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  CommunityImpactSummary? get data => _data;
  String get period => _period;
  String? get state => _state;
  String? get area => _area;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _repository.getImpact(period: _period, state: _state, area: _area);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> setPeriod(String period) {
    if (_period == period) return Future.value();
    _period = period;
    return load();
  }

  /// Setting a new state clears any previously-selected area — the server
  /// only recognises an area within the currently-selected state (or
  /// Malaysia-wide), and a stale area from a different state would just be
  /// dropped server-side anyway (same whitelisting as the web page).
  Future<void> setState(String? state) {
    if (_state == state) return Future.value();
    _state = state;
    _area = null;
    return load();
  }

  Future<void> setArea(String? area) {
    if (_area == area) return Future.value();
    _area = area;
    return load();
  }
}
