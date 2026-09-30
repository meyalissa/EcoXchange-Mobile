import '../../../../core/api/api_client.dart';
import '../models/category.dart';
import '../models/item.dart';

/// EcoXchange Mobile — GET /api/v1/customer/categories, /items (+ /{item}).
/// Kept as one repository (not three) since all three real endpoints are
/// facets of the same catalogue concept in the backend (CategoryController/
/// ItemController both read the `items` table directly, no separate
/// Category domain — see CategoryModel's docblock).
class CustomerCatalogueRepository {
  CustomerCatalogueRepository(this._api);

  final ApiClient _api;

  Future<List<CategoryModel>> getCategories() async {
    final data = await _api.get('/customer/categories');
    return (data['categories'] as List<dynamic>).map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [category] is sent only when set — matches ItemController::index()'s
  /// own optional `category` validation exactly; omitting it returns the
  /// full active catalogue.
  Future<List<ItemModel>> getItems({String? category}) async {
    final data = await _api.get('/customer/items', query: {
      if (category != null) 'category': category,
    });
    return (data['items'] as List<dynamic>).map((e) => ItemModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ItemModel> getItemDetail(int id) async {
    final data = await _api.get('/customer/items/$id');
    return ItemModel.fromJson(data['item'] as Map<String, dynamic>);
  }
}
