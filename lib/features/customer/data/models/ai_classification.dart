import 'item.dart';

/// EcoXchange Mobile — Stage 4.6. Shaped EXACTLY like
/// `PickupPreparationController::classify()`'s real response (confirmed by
/// inspection, Stage 4.5) — never invented. `aiLabel`/`confidence` are the
/// EfficientNet-B0 model's raw output, unchanged; `item` is the real,
/// active `items` row Laravel matched via `items.ai_label` (null only if
/// the caller is handling the 422 "unsupported" case separately — see
/// AIScanProvider).
class AIPrediction {
  const AIPrediction({required this.aiLabel, required this.confidence});

  factory AIPrediction.fromJson(Map<String, dynamic> json) {
    return AIPrediction(
      aiLabel: json['ai_label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  final String aiLabel;
  final double confidence;
}

class AIClassificationResult {
  const AIClassificationResult({
    required this.scanLogId,
    required this.aiLabel,
    required this.confidence,
    required this.item,
    required this.topPredictions,
  });

  factory AIClassificationResult.fromJson(Map<String, dynamic> json) {
    return AIClassificationResult(
      scanLogId: json['scan_log_id'] as int,
      aiLabel: json['ai_label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      item: ItemModel.fromJson(json['item'] as Map<String, dynamic>),
      topPredictions: (json['top_predictions'] as List<dynamic>? ?? const [])
          .map((e) => AIPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int scanLogId;
  final String aiLabel;
  final double confidence;

  /// Always non-null here — this model represents ONLY the success case
  /// (an active item was matched). The "AI prediction is not currently
  /// supported" case is a [BusinessRuleException] (code
  /// `AI_LABEL_UNSUPPORTED`), handled separately by the caller — see
  /// AIScanProvider.classify().
  final ItemModel item;

  final List<AIPrediction> topPredictions;
}
