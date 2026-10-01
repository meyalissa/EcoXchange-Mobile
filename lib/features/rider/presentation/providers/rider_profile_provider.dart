import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/rider_profile.dart';
import '../../data/repositories/rider_profile_repository.dart';

/// EcoXchange Mobile — Rider Profile state: loading/error/data +
/// pull-to-refresh. See RiderProfileRepository for the real endpoint.
class RiderProfileProvider extends ChangeNotifier {
  RiderProfileProvider(this._repository);

  final RiderProfileRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  RiderProfile? _profile;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  RiderProfile? get profile => _profile;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.getProfile();
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
