import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/recycling_centre.dart';
import '../../data/repositories/customer_recycling_centre_repository.dart';

/// EcoXchange Mobile — Recycling Centre List screen state.
class RecyclingCentreListProvider extends ChangeNotifier {
  RecyclingCentreListProvider(this._repository);

  final CustomerRecyclingCentreRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  List<RecyclingCentreModel> _centres = const [];

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  List<RecyclingCentreModel> get centres => _centres;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _centres = await _repository.getCentres();
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
