import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/personal_impact.dart';
import '../../data/repositories/community_impact_repository.dart';

/// EcoXchange Mobile — one customer's own impact + estimated environmental
/// benefit (GET /customer/community-impact/personal). Deliberately a
/// separate provider from [CommunityImpactProvider] — personal data is
/// never derived from, or mixed into, the community aggregates that
/// provider holds; see that class's own docblock for why suppression never
/// applies here.
class PersonalImpactProvider extends ChangeNotifier {
  PersonalImpactProvider(this._repository);

  final CommunityImpactRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  PersonalImpactSummary? _data;
  // Matches CommunityImpactProvider's own default so the two sections of
  // the Community Impact screen never show different periods on first load.
  String _period = 'all_time';

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  PersonalImpactSummary? get data => _data;
  String get period => _period;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _repository.getPersonalImpact(period: _period);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// Called when the Community Impact screen's own period filter changes,
  /// so this section always matches the period shown above it rather than
  /// exposing a second, confusing period selector.
  Future<void> setPeriod(String period) {
    if (_period == period) return Future.value();
    _period = period;
    return load();
  }
}
