// EcoXchange Mobile — AIScanProvider tests (Stage 4.6).
//
// A spy CustomerPickupBookingRepository subclass controls exactly what
// uploadImage()/classify() return/throw — no real HTTP. `pickImage()`
// itself needs image_picker's real platform channel (exercised for real
// in Stage 4.7's interactive verification instead); everything AFTER a
// picked image — submit()/success/AI_LABEL_UNSUPPORTED/generic-error/
// confirm/reset — is driven here via debugSetPickedImage(), a
// @visibleForTesting seam, against a real temp file (not a fake path) so
// submit()'s own `File` handling is exercised too.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_classification.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/ai_scan_provider.dart';

class _StubRepository extends CustomerPickupBookingRepository {
  _StubRepository() : super(ApiClient());

  Object? uploadImageThrows;
  Object? classifyThrows;
  AIClassificationResult? classifyReturns;
  int uploadCallCount = 0;
  int classifyCallCount = 0;

  @override
  Future<ScanUploadResult> uploadImage(String filePath) async {
    uploadCallCount++;
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
  late Directory tempDir;
  late File tempImage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_scan_provider_test');
    tempImage = File('${tempDir.path}/photo.png')..writeAsBytesSync([0, 1, 2, 3]);
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

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
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);

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
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);

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
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);

      await provider.submit();

      expect(provider.unsupportedAiLabel, isNull);
      expect(provider.result, isNull);
      expect(provider.error, isNotNull);
    });

    test('AI service unavailable (ServerException) is stored as error, no fake prediction', () async {
      final repo = _StubRepository()
        ..classifyThrows = const ServerException('The AI classification service could not process this image right now.');
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);

      await provider.submit();

      expect(provider.result, isNull);
      expect(provider.confirmedItem, isNull);
      expect(provider.error, isA<ServerException>());
    });

    test('upload failure never reaches classify()', () async {
      final repo = _StubRepository()..uploadImageThrows = const NetworkException('Could not connect.');
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);

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
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);
      await provider.submit();

      provider.confirmAiResult();

      expect(provider.confirmedItem, _glassBottle);
    });

    test('confirmManualItem() sets whatever real item the user picked, independent of the AI result', () {
      final provider = AIScanProvider(_StubRepository());

      provider.confirmManualItem(_plasticBottle);

      expect(provider.confirmedItem, _plasticBottle);
    });

    test('reset() clears every field back to the initial idle state', () async {
      final repo = _StubRepository()
        ..classifyReturns = const AIClassificationResult(
          scanLogId: 55, aiLabel: 'plastic_bottle', confidence: 0.9, item: _plasticBottle, topPredictions: [],
        );
      final provider = AIScanProvider(repo)..debugSetPickedImage(tempImage);
      await provider.submit();
      provider.confirmAiResult();

      provider.reset();

      expect(provider.confirmedItem, isNull);
      expect(provider.result, isNull);
      expect(provider.pickedImage, isNull);
      expect(provider.error, isNull);
      expect(provider.unsupportedAiLabel, isNull);
      expect(provider.scanLogId, isNull);
    });
  });
}
