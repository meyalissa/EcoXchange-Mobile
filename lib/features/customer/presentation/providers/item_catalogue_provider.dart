import 'package:flutter/foundation.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';
import '../../data/repositories/customer_catalogue_repository.dart';

/// EcoXchange Mobile — Item catalogue screen state: real categories, real
/// items, and the API-supported category filter — kept as one provider
/// since the screen shows both together (a category chip row above an item
/// grid), matching how CustomerCatalogueRepository groups the two real
/// endpoints.
class ItemCatalogueProvider extends ChangeNotifier {
  ItemCatalogueProvider(this._repository);

  final CustomerCatalogueRepository _repository;

  bool _isLoading = false;
  ApiException? _error;
  List<CategoryModel> _categories = const [];
  List<ItemModel> _items = const [];
  String? _selectedCategory;

  bool get isLoading => _isLoading;
  ApiException? get error => _error;
  List<CategoryModel> get categories => _categories;
  List<ItemModel> get items => _items;
  String? get selectedCategory => _selectedCategory;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getItems(category: _selectedCategory),
      ]);
      _categories = results[0] as List<CategoryModel>;
      _items = results[1] as List<ItemModel>;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> selectCategory(String? category) async {
    _selectedCategory = category;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _repository.getItems(category: _selectedCategory);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
