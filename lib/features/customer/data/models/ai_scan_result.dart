import 'ai_classification.dart';
import 'item.dart';

/// EcoXchange Mobile — unified AI scan result. The UI consumes THIS type,
/// never a specific model architecture.
///
/// Two response modes (see docs/AI_MULTI_OBJECT_SCAN.md):
///   * [AIScanMode.singleObject] — the live `POST /customer/pickup/classify`
///     response (EfficientNet-B0). One image -> one item, suggested quantity
///     1. Parsed exactly as before via [AIClassificationResult].
///   * [AIScanMode.multiObject] — the live, EXPERIMENTAL
///     `POST /customer/pickup/detect` response (and its read-back,
///     `GET /customer/pickup/detect/{scanLog}`, which has the same shape):
///     a generic RetinaNet `bottle` detector finds the objects, and
///     EfficientNet-B0 classifies each crop's material.
///
/// Every quantity here is only an AI SUGGESTION. Weight and reward are never
/// computed from this model — the booking flow sends the (user-corrected)
/// quantities to Laravel, which remains the only source of truth.
enum AIScanMode { singleObject, multiObject }

/// Whether EfficientNet-B0 gave this object a material.
enum AIClassificationStatus { classified, unclassified }

/// Laravel's mapping of an object's material to an EcoXchange item
/// (`item_status` in the /detect response).
enum AIItemStatus {
  /// The classifier label matches an active item — counted in the suggestion.
  resolved,

  /// The classifier label has no active item — not counted; manual review.
  unresolved,

  /// The classifier gave no material — not counted; manual review.
  notClassified,
}

AIItemStatus _itemStatus(Object? value) => switch (value) {
      'resolved' => AIItemStatus.resolved,
      'unresolved' => AIItemStatus.unresolved,
      'not_classified' => AIItemStatus.notClassified,
      final other => throw FormatException('Unknown item_status: $other'),
    };

ItemModel? _item(Object? json) => json == null ? null : ItemModel.fromJson(json as Map<String, dynamic>);

/// Box in ORIGINAL-image pixels (after EXIF orientation), origin top-left,
/// exactly as the server returns it. Scale by [AIScanResult.imageWidth] /
/// [AIScanResult.imageHeight] to draw it.
class AIBoundingBox {
  const AIBoundingBox({required this.x, required this.y, required this.width, required this.height});

  factory AIBoundingBox.fromJson(Map<String, dynamic> json) {
    return AIBoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;
}

class AIDetectedObject {
  const AIDetectedObject({
    required this.id,
    required this.index,
    required this.detectorLabel,
    required this.detectorConfidence,
    required this.boundingBox,
    required this.classificationStatus,
    required this.aiLabel,
    required this.classificationConfidence,
    required this.unclassifiedReason,
    required this.itemStatus,
    required this.item,
  });

  /// [index] is the 1-based display position ("Object 1").
  factory AIDetectedObject.fromJson(Map<String, dynamic> json, int index) {
    final classified = switch (json['classification_status']) {
      'classified' => AIClassificationStatus.classified,
      'unclassified' => AIClassificationStatus.unclassified,
      final other => throw FormatException('Unknown classification_status: $other'),
    };
    return AIDetectedObject(
      id: json['id'] as String,
      index: index,
      detectorLabel: json['detector_label'] as String,
      detectorConfidence: (json['detector_confidence'] as num).toDouble(),
      boundingBox: AIBoundingBox.fromJson(json['bounding_box'] as Map<String, dynamic>),
      classificationStatus: classified,
      aiLabel: json['classification_label'] as String?,
      classificationConfidence: (json['classification_confidence'] as num?)?.toDouble(),
      unclassifiedReason: json['unclassified_reason'] as String?,
      itemStatus: _itemStatus(json['item_status']),
      item: _item(json['item']),
    );
  }

  /// Server id, e.g. `object_1`.
  final String id;
  final int index;

  /// The detector's GENERIC object class (`bottle`) — never a material.
  final String detectorLabel;
  final double detectorConfidence;
  final AIBoundingBox boundingBox;

  final AIClassificationStatus classificationStatus;

  /// EfficientNet-B0's material label for this crop; null when unclassified.
  /// The ONLY source of material.
  final String? aiLabel;
  final double? classificationConfidence;

  /// Server token when unclassified (e.g. `low_classification_confidence`).
  final String? unclassifiedReason;

  final AIItemStatus itemStatus;

  /// The item Laravel resolved from [aiLabel] (summary fields only: id, name,
  /// category). Null unless [itemStatus] is resolved.
  final ItemModel? item;

  bool get isClassified => classificationStatus == AIClassificationStatus.classified;
  bool get isResolved => itemStatus == AIItemStatus.resolved;
  bool get needsManualReview => !isResolved;
}

/// One material the AI counted: its label, how many, and the item Laravel
/// resolved it to. [item] is null for an unresolved material (no active item),
/// which is never counted into a booking by the app.
class AIScanLine {
  const AIScanLine({required this.aiLabel, required this.item, required this.suggestedQuantity});

  factory AIScanLine.fromJson(Map<String, dynamic> json) {
    return AIScanLine(
      aiLabel: json['ai_label'] as String,
      item: _item(json['item']),
      suggestedQuantity: json['suggested_quantity'] as int,
    );
  }

  final String aiLabel;
  final ItemModel? item;
  final int suggestedQuantity;

  bool get isResolved => item != null;
}

class AIScanResult {
  const AIScanResult._({
    required this.mode,
    required this.scanLogId,
    required this.classification,
    required this.detections,
    required this.materials,
    required this.imageWidth,
    required this.imageHeight,
    required this.needsManualReview,
  });

  /// The current classifier result, unchanged: one line, quantity 1.
  factory AIScanResult.singleObject(AIClassificationResult classification) {
    return AIScanResult._(
      mode: AIScanMode.singleObject,
      scanLogId: classification.scanLogId,
      classification: classification,
      detections: const [],
      materials: [
        AIScanLine(aiLabel: classification.aiLabel, item: classification.item, suggestedQuantity: 1),
      ],
      imageWidth: null,
      imageHeight: null,
      needsManualReview: false,
    );
  }

  /// Parses either mode. A response without `mode` is the classify response
  /// and is treated as single-object (backward compatible). Throws
  /// [FormatException]/[TypeError] on a malformed body — never guesses.
  factory AIScanResult.fromJson(Map<String, dynamic> json) {
    switch (json['mode']) {
      case null:
      case 'single_object':
        return AIScanResult.singleObject(AIClassificationResult.fromJson(json));
      case 'multi_object':
        final image = json['image'] as Map<String, dynamic>;
        final summary = json['summary'] as Map<String, dynamic>;
        final detections = json['detections'] as List<dynamic>;
        return AIScanResult._(
          mode: AIScanMode.multiObject,
          scanLogId: json['scan_log_id'] as int,
          classification: null,
          detections: [
            for (var i = 0; i < detections.length; i++)
              AIDetectedObject.fromJson(detections[i] as Map<String, dynamic>, i + 1),
          ],
          materials: (summary['materials'] as List<dynamic>)
              .map((e) => AIScanLine.fromJson(e as Map<String, dynamic>))
              .toList(),
          imageWidth: image['width'] as int,
          imageHeight: image['height'] as int,
          needsManualReview: summary['needs_manual_review'] as bool,
        );
      default:
        throw FormatException('Unknown AI scan mode: ${json['mode']}');
    }
  }

  final AIScanMode mode;
  final int scanLogId;

  /// Non-null only in single-object mode.
  final AIClassificationResult? classification;

  /// Empty in single-object mode.
  final List<AIDetectedObject> detections;

  /// Every material the AI counted (single-object: exactly one line, 1),
  /// resolved or not — see [lines] for the countable ones.
  final List<AIScanLine> materials;

  /// Original image size, used to scale the pixel bounding boxes.
  final int? imageWidth;
  final int? imageHeight;

  /// Server flag: at least one object is unresolved or unclassified.
  final bool needsManualReview;

  bool get isMultiObject => mode == AIScanMode.multiObject;
  int get totalDetected => detections.length;

  /// Materials resolved to an item — the only ones whose quantity can be
  /// booked. Unresolved materials and unclassified objects are never here.
  List<AIScanLine> get lines => materials.where((m) => m.isResolved).toList();
  List<AIScanLine> get unresolvedMaterials => materials.where((m) => !m.isResolved).toList();

  List<AIDetectedObject> get resolvedDetections => detections.where((d) => d.isResolved).toList();
  List<AIDetectedObject> get reviewDetections => detections.where((d) => d.needsManualReview).toList();

  /// Resolved detections attributed to [itemId].
  List<AIDetectedObject> detectionsFor(int itemId) =>
      detections.where((d) => d.isResolved && d.item?.id == itemId).toList();
}
