// EcoXchange Mobile — AIScanProvider tests (Stage 4.6).
//
// A spy CustomerPickupBookingRepository subclass controls exactly what
// uploadImage()/classify() return/throw — no real HTTP. `pickImage()`
// itself needs image_picker's real platform channel (exercised for real
// in Stage 4.7's interactive verification instead); everything AFTER a
// picked image — submit()/success/AI_LABEL_UNSUPPORTED/generic-error/
// confirm/reset — is driven here via debugSetPickedImage(), a
// @visibleForTesting seam, against real bytes (not a file path) so
// submit()'s own bytes handling is exercised too — this is also the
// platform-independent representation the app itself uses (see
// AIScanProvider's docblock for why: Image.file/dart:io.File are not
// supported on Flutter Web, so the whole pipeline is bytes-based now).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_classification.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_scan_result.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/ai_scan_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/ai_scan_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart' show PrefillItemQuantity;

import '../../fixtures/ai_scan_fixtures.dart';

/// Part B's submit() tries object-counting before classification (see
/// AIScanProvider's docblock). This file exercises only the classify step
/// (Stage 4.6, pre-unification behaviour), so every provider here is given
/// a detector that genuinely finds nothing, forcing the real classify-only
/// fallback path every time -- never a real network call to /detect.
class _NoDetectionsRepo implements AIDetectionRepository {
  @override
  Future<AIScanResult> analyse(int scanLogId) async => AIScanResult.fromJson(multiObjectEmptyFixture());

  @override
  Future<AIScanResult> restore(int scanLogId) async => AIScanResult.fromJson(multiObjectEmptyFixture());
}

class _StubRepository extends CustomerPickupBookingRepository {
  _StubRepository() : super(ApiClient());

  Object? uploadImageThrows;
  Object? classifyThrows;
  AIClassificationResult? classifyReturns;
  int uploadCallCount = 0;
  int classifyCallCount = 0;
  Uint8List? lastUploadBytes;
  String? lastUploadFilename;

  @override
  Future<ScanUploadResult> uploadImage(Uint8List bytes, String filename) async {
    uploadCallCount++;
    lastUploadBytes = bytes;
    lastUploadFilename = filename;
    if (uploadImageThrows != null) throw uploadImageThrows!;
    return const ScanUploadResult(scanLogId: 55, imageUrl: 'https://ecoxchange.test/storage/scans/x.png');
  }

  @override
  Future<AIClassificationResult> classify(int scanLogId) async {
    classifyCallCount++;
    if (classifyThrows != null) throw classifyThrows!;
    return classifyReturns!;
  }
}

const _plasticBottle = ItemModel(
  id: 1, name: 'Plastic Bottle', category: 'Plastic', image: null, description: null,
  preliminaryBasePricePerKg: 0.40, priceNote: null, estimatedUnitWeightKg: 0.05,
  preparationSteps: null, recyclingTips: null, environmentalImpact: null,
);

const _glassBottle = ItemModel(
  id: 10, name: 'Glass Bottle', category: 'Glass', image: null, description: null,
  preliminaryBasePricePerKg: 0.10, priceNote: null, estimatedUnitWeightKg: 0.15,
  preparationSteps: null, recyclingTips: null, environmentalImpact: null,
);

void main() {
  final testImageBytes = Uint8List.fromList([0, 1, 2, 3]);

  group('AIScanProvider — submit()', () {
    test('does nothing without a picked image — never fabricates a result', () async {
      final provider = AIScanProvider(_StubRepository());

      await provider.submit();

      expect(provider.result, isNull);
      expect(provider.error, isNull);
    });

    test('successful classification stores the REAL result unchanged', () async {
      final repo = _StubRepository()
        ..classifyReturns = const AIClassificationResult(
          scanLogId: 55, aiLabel: 'plastic_bottle', confidence: 0.987, item: _plasticBottle,
          topPredictions: [AIPrediction(aiLabel: 'plastic_bottle', confidence: 0.987)],
        );
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);

      await provider.submit();

      expect(repo.uploadCallCount, 1);
      expect(repo.classifyCallCount, 1);
      expect(provider.result?.aiLabel, 'plastic_bottle');
      expect(provider.result?.item.id, 1);
      expect(provider.scanLogId, 55);
      expect(provider.uploadedImageUrl, 'https://ecoxchange.test/storage/scans/x.png');
      expect(provider.unsupportedAiLabel, isNull);
      expect(provider.error, isNull);
      expect(provider.isSubmitting, isFalse);
    });

    test('AI_LABEL_UNSUPPORTED is surfaced honestly — no item guessed', () async {
      final repo = _StubRepository()
        ..classifyThrows = const BusinessRuleException(
          'AI prediction is not currently supported by EcoXchange.',
          code: 'AI_LABEL_UNSUPPORTED',
          details: {'ai_label': 'newspaper', 'confidence': 0.75},
        );
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);

      await provider.submit();

      expect(provider.result, isNull);
      expect(provider.confirmedItem, isNull);
      expect(provider.unsupportedAiLabel, 'newspaper');
      expect(provider.unsupportedConfidence, 0.75);
      expect(provider.error, isNull, reason: 'unsupported is a distinct, honest outcome — not a generic error');
    });

    test('a different BusinessRuleException code falls through to error, not unsupported', () async {
      final repo = _StubRepository()
        ..classifyThrows = const BusinessRuleException('Something else went wrong.', code: 'SOME_OTHER_CODE');
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);

      await provider.submit();

      expect(provider.unsupportedAiLabel, isNull);
      expect(provider.result, isNull);
      expect(provider.error, isNotNull);
    });

    test('AI service unavailable (ServerException) is stored as error, no fake prediction', () async {
      final repo = _StubRepository()
        ..classifyThrows = const ServerException('The AI classification service could not process this image right now.');
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);

      await provider.submit();

      expect(provider.result, isNull);
      expect(provider.confirmedItem, isNull);
      expect(provider.error, isA<ServerException>());
    });

    test('upload failure never reaches classify()', () async {
      final repo = _StubRepository()..uploadImageThrows = const NetworkException('Could not connect.');
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);

      await provider.submit();

      expect(repo.classifyCallCount, 0);
      expect(provider.error, isA<NetworkException>());
    });
  });

  group('AIScanProvider — confirm / reset', () {
    test('confirmAiResult() adopts the AI-matched item as confirmed', () async {
      final repo = _StubRepository()
        ..classifyReturns = const AIClassificationResult(
          scanLogId: 55, aiLabel: 'glass_bottle', confidence: 0.9, item: _glassBottle, topPredictions: [],
        );
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);
      await provider.submit();

      provider.confirmAiResult();

      expect(provider.confirmedItem, _glassBottle);
    });

    test('confirmManualItem() sets whatever real item the user picked, independent of the AI result', () {
      final provider = AIScanProvider(_StubRepository());

      provider.confirmManualItem(_plasticBottle);

      expect(provider.confirmedItem, _plasticBottle);
    });

    // Task 2 — "Add an Item Manually".
    test('confirmManualItem() with an explicit quantity seeds reviewedQuantities so it is never lost', () {
      final provider = AIScanProvider(_StubRepository());

      provider.confirmManualItem(_plasticBottle, quantity: 3);

      expect(provider.confirmedItem, _plasticBottle);
      expect(provider.quantityOf(_plasticBottle.id), 3);
      expect(provider.reviewedQuantities, [isA<PrefillItemQuantity>().having((l) => l.quantity, 'quantity', 3)]);
    });

    test('a confirmed single-object result plus "Add an Item Manually" for a DIFFERENT item keeps both, counted once each', () async {
      final repo = _StubRepository()
        ..classifyReturns = const AIClassificationResult(
          scanLogId: 55, aiLabel: 'plastic_bottle', confidence: 0.9, item: _plasticBottle, topPredictions: [],
        );
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);
      await provider.submit();
      provider.confirmAiResult();

      provider.addManualItem(_glassBottle, quantity: 2);

      expect(provider.reviewedQuantities, hasLength(2));
      final byId = {for (final l in provider.reviewedQuantities) l.item.id: l.quantity};
      expect(byId, {_plasticBottle.id: 1, _glassBottle.id: 2});
      expect(provider.totalReviewedQuantity, 3);
    });

    test('"Add an Item Manually" for the SAME material already confirmed merges the quantity, never duplicates the row', () async {
      final repo = _StubRepository()
        ..classifyReturns = const AIClassificationResult(
          scanLogId: 55, aiLabel: 'plastic_bottle', confidence: 0.9, item: _plasticBottle, topPredictions: [],
        );
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);
      await provider.submit();
      provider.confirmAiResult();

      provider.addManualItem(_plasticBottle, quantity: 2);

      expect(provider.reviewedQuantities, hasLength(1), reason: 'merged into the one Plastic Bottle row, not a second one');
      expect(provider.quantityOf(_plasticBottle.id), 3, reason: '1 (confirmed) + 2 (manually added)');
      expect(provider.isManuallyAdded(_plasticBottle.id), isFalse, reason: 'it was the AI-suggested item, not purely manual');
    });

    test('reset() clears every field back to the initial idle state', () async {
      final repo = _StubRepository()
        ..classifyReturns = const AIClassificationResult(
          scanLogId: 55, aiLabel: 'plastic_bottle', confidence: 0.9, item: _plasticBottle, topPredictions: [],
        );
      final provider = AIScanProvider(repo, detectionRepository: _NoDetectionsRepo())..debugSetPickedImage(testImageBytes);
      await provider.submit();
      provider.confirmAiResult();

      provider.reset();

      expect(provider.confirmedItem, isNull);
      expect(provider.result, isNull);
      expect(provider.pickedImageBytes, isNull);
      expect(provider.error, isNull);
      expect(provider.unsupportedAiLabel, isNull);
      expect(provider.scanLogId, isNull);
    });
  });
}
