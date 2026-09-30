// ============================================================================
// TEST FIXTURES for unit/widget tests.
//
// * singleObjectClassifyFixture() and the detect*/multiObject* builders are
//   HAND-WRITTEN, API-SHAPED inputs — NOT predictions from any AI model. The
//   single-object one mirrors the live `POST /customer/pickup/classify`
//   response; the multi-object ones mirror the live Laravel
//   `POST /customer/pickup/detect` response contract (see
//   docs/AI_MULTI_OBJECT_SCAN.md), built the way Laravel builds it, for edge
//   cases a real photo can't produce on demand.
// * realLaravelDetectResponse() is a GENUINE response: recorded from the real
//   Laravel -> FastAPI (RetinaNet + EfficientNet-B0) stack on 2026-09-30 for
//   detector test image `-37_jpg.rf.cfec2e9459be7328087ec91601c395eb.jpg`
//   (4 bottles), stored in detect_response_real_laravel_4_bottles.json.
// ============================================================================

import 'dart:convert';
import 'dart:io';

Map<String, dynamic> itemJson({required int id, required String name, String category = 'Plastic'}) => {
      'id': id,
      'name': name,
      'category': category,
      'image': null,
      'description': null,
      'preliminary_base_price_per_kg': 0.40,
      'price_note': 'Preliminary estimate only.',
      'estimated_unit_weight_kg': 0.05,
      'preparation_steps': null,
      'recycling_tips': null,
      'environmental_impact': null,
    };

final plasticBottleJson = itemJson(id: 1, name: 'Plastic Bottle');
final glassBottleJson = itemJson(id: 10, name: 'Glass Bottle', category: 'Glass');

/// FIXTURE — shape of the current live classify response (`data` payload).
Map<String, dynamic> singleObjectClassifyFixture() => {
      'scan_log_id': 55,
      'ai_label': 'plastic_bottle',
      'confidence': 0.91,
      'item': plasticBottleJson,
      'top_predictions': [
        {'ai_label': 'plastic_bottle', 'confidence': 0.91},
      ],
    };

// ── multi-object (/detect) builders ────────────────────────────────────────

/// Active items in the fixture catalogue, by classifier label (ids match the
/// live catalogue). Any other label has no active item -> "unresolved".
const _catalogue = {
  'plastic_bottle': (1, 'Plastic Bottle', 'Plastic'),
  'glass_bottle': (10, 'Glass Bottle', 'Glass'),
};

/// The item summary the /detect response embeds (id, name, category, ai_label).
Map<String, dynamic>? detectItemJson(String? label) {
  final entry = _catalogue[label];
  if (entry == null) return null;
  return {'id': entry.$1, 'name': entry.$2, 'category': entry.$3, 'ai_label': label};
}

/// One detected object. [label] null = the classifier gave no material.
Map<String, dynamic> detectObject(
  int n,
  String? label, {
  double detectorConfidence = 0.9,
  double confidence = 0.9,
  String reason = 'low_classification_confidence',
}) {
  final item = detectItemJson(label);
  return {
    'id': 'object_$n',
    'detector_label': 'bottle',
    'detector_confidence': detectorConfidence,
    'bounding_box': {'x': 100.0 * n, 'y': 120.0, 'width': 80.0, 'height': 200.0},
    'classification_status': label == null ? 'unclassified' : 'classified',
    'classification_label': label,
    'classification_confidence': label == null ? null : confidence,
    'unclassified_reason': label == null ? reason : null,
    'top_predictions': label == null ? const [] : [{'ai_label': label, 'confidence': confidence}],
    'item_status': label == null ? 'not_classified' : (item != null ? 'resolved' : 'unresolved'),
    'item': item,
  };
}

/// A full /detect `data` payload with a summary consistent with [objects],
/// built the way Laravel builds it.
Map<String, dynamic> detectResponse(List<Map<String, dynamic>> objects, {int scanLogId = 77}) {
  final counts = <String, int>{};
  for (final o in objects) {
    final label = o['classification_label'] as String?;
    if (label != null) counts[label] = (counts[label] ?? 0) + 1;
  }
  final ordered = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final materials = [
    for (final e in ordered)
      {
        'ai_label': e.key,
        'suggested_quantity': e.value,
        'item_status': detectItemJson(e.key) != null ? 'resolved' : 'unresolved',
        'item': detectItemJson(e.key),
      },
  ];
  final classified = counts.values.fold(0, (a, b) => a + b);
  final resolved = objects.where((o) => o['item_status'] == 'resolved').length;
  final unresolved = objects.where((o) => o['item_status'] == 'unresolved').length;

  return {
    'scan_log_id': scanLogId,
    'mode': 'multi_object',
    'experimental': true,
    'image': {'width': 1280, 'height': 960},
    'detections': objects,
    'summary': {
      'total_detected_objects': objects.length,
      'classified_objects': classified,
      'unclassified_objects': objects.length - classified,
      'resolved_objects': resolved,
      'unresolved_objects': unresolved,
      'needs_manual_review': resolved != objects.length,
      'materials': materials,
    },
    'suggested_items': [
      for (final m in materials)
        if (m['item'] != null) {'item_id': (m['item'] as Map)['id'], 'quantity': m['suggested_quantity']},
    ],
    'quantity_note': 'AI-suggested quantities only — please check and correct them.',
    'models': {
      'detector_model_version': 'retinanet_efficientnetb0_640_lr_decay_best_e27',
      'detector_confidence_threshold': 0.5,
      'classifier_model_version': 'ecoxchange_efficientnet_b0_8class',
    },
    'ai_timing': {'detector_ms': 250, 'classification_ms': 100, 'total_ms': 360},
  };
}

/// 4 plastic + 1 glass resolved, 1 object the classifier could not classify.
Map<String, dynamic> multiObjectFixture() => detectResponse([
      for (var i = 1; i <= 4; i++) detectObject(i, 'plastic_bottle', confidence: 0.96 - i / 100),
      detectObject(5, 'glass_bottle', confidence: 0.91),
      detectObject(6, null, detectorConfidence: 0.62),
    ]);

Map<String, dynamic> onePlasticBottleFixture() => detectResponse([detectObject(1, 'plastic_bottle')], scanLogId: 81);

Map<String, dynamic> twoPlasticBottlesFixture() =>
    detectResponse([detectObject(1, 'plastic_bottle'), detectObject(2, 'plastic_bottle')], scanLogId: 82);

/// glass_bottle × 3 + plastic_bottle × 2.
Map<String, dynamic> mixedGlass3Plastic2Fixture() => detectResponse([
      detectObject(1, 'glass_bottle'),
      detectObject(2, 'plastic_bottle'),
      detectObject(3, 'glass_bottle'),
      detectObject(4, 'plastic_bottle'),
      detectObject(5, 'glass_bottle'),
    ], scanLogId: 83);

Map<String, dynamic> multiObjectEmptyFixture() => detectResponse(const [], scanLogId: 78);

/// Nothing countable: one unclassified object, one material with no active item.
Map<String, dynamic> multiObjectAllReviewFixture() =>
    detectResponse([detectObject(1, null), detectObject(2, 'aluminium_can', confidence: 0.8)], scanLogId: 79);

/// GENUINE Laravel /detect `data` payload (see header): glass_bottle × 3
/// (item 10) + plastic_bottle × 1 (item 1), scan_log_id 95.
Map<String, dynamic> realLaravelDetectResponse() => jsonDecode(
      File('test/fixtures/detect_response_real_laravel_4_bottles.json').readAsStringSync(),
    ) as Map<String, dynamic>;
