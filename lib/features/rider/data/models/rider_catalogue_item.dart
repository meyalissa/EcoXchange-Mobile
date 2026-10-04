/// EcoXchange Mobile — one active catalogue item a rider can add on site,
/// from `GET /api/v1/rider/items` (`{id, name, category}`; no price — the
/// rider API never exposes prices or rewards). [id] is the catalogue
/// `items.id`, sent as `new_items[].item_id` when completing a pickup.
class RiderCatalogueItem {
  const RiderCatalogueItem({required this.id, required this.name, required this.category});

  factory RiderCatalogueItem.fromJson(Map<String, dynamic> json) {
    return RiderCatalogueItem(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String?,
    );
  }

  final int id;
  final String name;
  final String? category;
}
