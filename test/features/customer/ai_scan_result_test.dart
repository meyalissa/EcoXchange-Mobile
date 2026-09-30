// EcoXchange Mobile — AIScanResult parsing tests.
//
// Inputs are TEST FIXTURES (test/fixtures/ai_scan_fixtures.dart): hand-written
// API-shaped responses, plus ONE genuine Laravel /detect response recorded
// from the real RetinaNet + EfficientNet-B0 stack (realLaravelDetectResponse).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/features/customer/data/models/ai_classification.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_scan_result.dart';

import '../../fixtures/ai_scan_fixtures.dart';

void main() {
  group('single-object (current classifier) — backward compatible', () {
    test('a classify response without "mode" parses as single-object, quantity 1', () {
      final result = AIScanResult.fromJson(singleObjectClassifyFixture());

      expect(result.mode, AIScanMode.singleObject);
      expect(result.isMultiObject, isFalse);
      expect(result.scanLogId, 55);
      expect(result.classification?.aiLabel, 'plastic_bottle');
      expect(result.classification?.confidence, 0.91);
      expect(result.detections, isEmpty);
      expect(result.lines, hasLength(1));
      expect(result.lines.single.item!.id, 1);
      expect(result.lines.single.suggestedQuantity, 1);
    });

    test('an explicit "single_object" mode parses the same way', () {
      final json = singleObjectClassifyFixture()..['mode'] = 'single_object';

      final result = AIScanResult.fromJson(json);

      expect(result.mode, AIScanMode.singleObject);
      expect(result.lines.single.suggestedQuantity, 1);
    });

    test('singleObject() wraps an existing AIClassificationResult unchanged', () {
      final classification = AIClassificationResult.fromJson(singleObjectClassifyFixture());

      final result = AIScanResult.singleObject(classification);

      expect(identical(result.classification, classification), isTrue);
      expect(result.lines.single.item!.name, 'Plastic Bottle');
    });
  });

  group('multi-object — the real Laravel /detect contract', () {
    test('A. parses a GENUINE Laravel /detect response (4 real bottles)', () {
      final result = AIScanResult.fromJson(realLaravelDetectResponse());

      expect(result.mode, AIScanMode.multiObject);
      expect(result.scanLogId, 95);
      expect(result.classification, isNull);
      expect((result.imageWidth, result.imageHeight), (640, 640));
      expect(result.totalDetected, 4);
      expect(result.needsManualReview, isFalse);

      final first = result.detections.first;
      expect(first.id, 'object_1');
      expect(first.index, 1);
      expect(first.detectorLabel, 'bottle');
      expect(first.detectorConfidence, 0.9623);
      expect(first.isClassified, isTrue);
      expect(first.aiLabel, 'glass_bottle');
      expect(first.classificationConfidence, closeTo(0.8731, 1e-4));
      expect(first.itemStatus, AIItemStatus.resolved);
      expect(first.item?.id, 10);
      expect(first.item?.name, 'Glass Bottle');
      expect((first.boundingBox.x, first.boundingBox.width), (160.8, 161.41), reason: 'pixels, as the server sends them');

      expect(result.detections.map((d) => d.detectorLabel).toSet(), {'bottle'});
      expect(result.detections.map((d) => d.aiLabel), ['glass_bottle', 'glass_bottle', 'plastic_bottle', 'glass_bottle']);
      expect(result.lines.map((l) => (l.aiLabel, l.item!.id, l.suggestedQuantity)), [
        ('glass_bottle', 10, 3),
        ('plastic_bottle', 1, 1),
      ]);
      expect(result.detectionsFor(10), hasLength(3));
    });

    test('B. one detected plastic bottle -> suggested quantity 1', () {
      final result = AIScanResult.fromJson(onePlasticBottleFixture());

      expect(result.lines.single.item!.name, 'Plastic Bottle');
      expect(result.lines.single.suggestedQuantity, 1);
    });

    test('C. two detected plastic bottles -> suggested quantity 2', () {
      final result = AIScanResult.fromJson(twoPlasticBottlesFixture());

      expect(result.totalDetected, 2);
      expect(result.lines.single.item!.id, 1);
      expect(result.lines.single.suggestedQuantity, 2);
    });

    test('D. mixed glass_bottle × 3 + plastic_bottle × 2 -> separate quantities', () {
      final result = AIScanResult.fromJson(mixedGlass3Plastic2Fixture());

      expect(result.lines.map((l) => (l.item!.name, l.suggestedQuantity)), [
        ('Glass Bottle', 3),
        ('Plastic Bottle', 2),
      ]);
      expect(result.detectionsFor(10), hasLength(3));
      expect(result.detectionsFor(1), hasLength(2));
    });

    test('G. an unclassified object gets no material and no item, and is not counted', () {
      final result = AIScanResult.fromJson(multiObjectFixture());

      final unclassified = result.detections.last;
      expect(unclassified.detectorLabel, 'bottle', reason: 'still just a generic detection');
      expect(unclassified.isClassified, isFalse);
      expect(unclassified.aiLabel, isNull);
      expect(unclassified.item, isNull, reason: 'never mapped to plastic_bottle from the "bottle" detector label');
      expect(unclassified.itemStatus, AIItemStatus.notClassified);
      expect(unclassified.needsManualReview, isTrue);
      expect(unclassified.unclassifiedReason, 'low_classification_confidence');

      expect(result.needsManualReview, isTrue);
      expect(result.reviewDetections, [unclassified]);
      expect(result.lines.map((l) => (l.item!.id, l.suggestedQuantity)), [(1, 4), (10, 1)],
          reason: 'the unclassified object adds to no quantity');
    });

    test('a material with no active item is unresolved, keeps its real label, and is not bookable', () {
      final result = AIScanResult.fromJson(multiObjectAllReviewFixture());

      final can = result.detections[1];
      expect(can.aiLabel, 'aluminium_can');
      expect(can.itemStatus, AIItemStatus.unresolved);
      expect(can.item, isNull);
      expect(result.lines, isEmpty);
      expect(result.unresolvedMaterials.single.aiLabel, 'aluminium_can');
      expect(result.unresolvedMaterials.single.suggestedQuantity, 1);
    });

    test('an empty detection result parses to zero detections and zero lines', () {
      final result = AIScanResult.fromJson(multiObjectEmptyFixture());

      expect(result.isMultiObject, isTrue);
      expect(result.totalDetected, 0);
      expect(result.lines, isEmpty);
    });

    test('an unknown mode, classification_status or item_status is rejected instead of guessed', () {
      expect(() => AIScanResult.fromJson({'mode': 'something_else'}), throwsFormatException);

      final badStatus = multiObjectFixture();
      (badStatus['detections'] as List).first['classification_status'] = 'maybe';
      expect(() => AIScanResult.fromJson(badStatus), throwsFormatException);

      final badItemStatus = multiObjectFixture();
      (badItemStatus['detections'] as List).first['item_status'] = 'guessed';
      expect(() => AIScanResult.fromJson(badItemStatus), throwsFormatException);
    });
  });
}
