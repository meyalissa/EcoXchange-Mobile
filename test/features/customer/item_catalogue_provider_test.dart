// EcoXchange Mobile — ItemCatalogueProvider tests (Phase 4C.2 §21):
// category filtering, and the preliminary-pricing wording rule.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/item_catalogue_provider.dart';

Map<String, dynamic> _itemJson({int id = 1, String category = 'Plastic'}) => {
      'id': id,
      'name': 'Item $id',
      'category': category,
      'image': null,
      'description': null,
      'preliminary_base_price_per_kg': 0.40,
      'price_note': 'Preliminary estimate only. Your actual reward is calculated from the recycling centre '
          'you select at booking time, which may offer a different rate for this item.',
      'estimated_unit_weight_kg': 0.05,
      'preparation_steps': null,
      'recycling_tips': null,
      'environmental_impact': null,
    };

class _RecordingCatalogueRepository extends CustomerCatalogueRepository {
  _RecordingCatalogueRepository() : super(ApiClient());

  final List<String?> categoryCalls = [];

  @override
  Future<List<CategoryModel>> getCategories() async => [
        CategoryModel.fromJson({'name': 'Plastic', 'item_count': 3}),
        CategoryModel.fromJson({'name': 'Metal', 'item_count': 2}),
      ];

  @override
  Future<List<ItemModel>> getItems({String? category}) async {
    categoryCalls.add(category);
    return [_itemJson(category: category ?? 'Plastic')].map(ItemModel.fromJson).toList();
  }
}

void main() {
  group('ItemCatalogueProvider', () {
    test('load() fetches real categories and items together', () async {
      final provider = ItemCatalogueProvider(_RecordingCatalogueRepository());

      await provider.load();

      expect(provider.categories, hasLength(2));
      expect(provider.items, hasLength(1));
      expect(provider.error, isNull);
    });

    test('selectCategory sends only the real API-supported category filter', () async {
      final repo = _RecordingCatalogueRepository();
      final provider = ItemCatalogueProvider(repo);

      await provider.load();
      await provider.selectCategory('Metal');

      expect(repo.categoryCalls.last, 'Metal');
      expect(provider.selectedCategory, 'Metal');
    });

    test('selectCategory(null) returns to the full catalogue', () async {
      final repo = _RecordingCatalogueRepository();
      final provider = ItemCatalogueProvider(repo);

      await provider.selectCategory('Metal');
      await provider.selectCategory(null);

      expect(repo.categoryCalls.last, isNull);
      expect(provider.selectedCategory, isNull);
    });
  });

  group('ItemModel pricing wording (Phase 4C.2 §9)', () {
    test('preliminary price note is parsed verbatim from the server, never rewritten', () {
      final item = ItemModel.fromJson(_itemJson());

      expect(item.priceNote, isNotNull);
      expect(item.priceNote, contains('Preliminary estimate only'));
      // The wording must never claim a guaranteed payout.
      expect(item.priceNote!.toLowerCase(), isNot(contains('guaranteed')));
    });
  });
}
