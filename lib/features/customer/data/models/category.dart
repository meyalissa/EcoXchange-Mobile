/// EcoXchange Mobile — shaped EXACTLY like `Api\Customer\CategoryController`
/// (confirmed by inspection). There is no Category model/table in the
/// backend — these are distinct `items.category` string values among
/// active items, each with a real count. No taxonomy is invented here.
class CategoryModel {
  const CategoryModel({required this.name, required this.itemCount});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      name: json['name'] as String,
      itemCount: json['item_count'] as int,
    );
  }

  final String name;
  final int itemCount;
}
