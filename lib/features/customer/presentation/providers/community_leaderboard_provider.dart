import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/community_leaderboard.dart';
import '../../data/repositories/community_impact_repository.dart';

/// EcoXchange Mobile — Community Leaderboard screen state: loading/error/
/// data + the active view ('area'/'state'/'participation') and period
/// filters. Every ranking comes straight from the server
/// (GET /customer/community-impact/leaderboard) — nothing is re-sorted or
/// recomputed client-side.
class CommunityLeaderboardProvider extends ChangeNotifier {
  CommunityLeaderboardProvider(this._repository);

  final CommunityImpactRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  CommunityLeaderboardResult? _data;
  String _view = 'area';
  String _period = 'all_time';

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  CommunityLeaderboardResult? get data => _data;
  String get view => _view;
  String get period => _period;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _repository.getLeaderboard(view: _view, period: _period);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> setView(String view) {
    if (_view == view) return Future.value();
    _view = view;
    return load();
  }

  Future<void> setPeriod(String period) {
    if (_period == period) return Future.value();
    _period = period;
    return load();
  }
}
