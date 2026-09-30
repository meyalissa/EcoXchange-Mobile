/// EcoXchange Mobile — recyclable item catalogue entry, shaped EXACTLY like
/// `App\Http\Resources\Customer\ItemResource` (confirmed by inspection).
///
/// PRICING SEMANTICS — read before using [preliminaryBasePricePerKg]
/// anywhere in the UI: this is the global catalogue rate, a PRELIMINARY
/// estimate only (the Resource's own field name says so). [priceNote] is
/// the server-authored explanation of that — the UI must surface it
/// verbatim rather than writing its own wording, so the two can never
/// drift apart (see item_detail_screen.dart / item_list_screen.dart).
class ItemModel {
  const ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    required this.description,
    required this.preliminaryBasePricePerKg,
    required this.priceNote,
    required this.estimatedUnitWeightKg,
    required this.preparationSteps,
    required this.recyclingTips,
    required this.environmentalImpact,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String?,
      image: json['image'] as String?,
      description: json['description'] as String?,
      preliminaryBasePricePerKg: (json['preliminary_base_price_per_kg'] as num?)?.toDouble(),
      priceNote: json['price_note'] as String?,
      estimatedUnitWeightKg: (json['estimated_unit_weight_kg'] as num?)?.toDouble(),
      preparationSteps: (json['preparation_steps'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      recyclingTips: json['recycling_tips'] as String?,
      environmentalImpact: json['environmental_impact'] as String?,
    );
  }

  final int id;
  final String name;
  final String? category;
  final String? image;
  final String? description;
  final double? preliminaryBasePricePerKg;
  final String? priceNote;
  final double? estimatedUnitWeightKg;
  final List<String>? preparationSteps;
  final String? recyclingTips;
  final String? environmentalImpact;
}
