// EcoXchange Mobile — multi-object AI scan: repository (real /detect contract),
// AIScanProvider (detect, read-back/resume, quantity correction, errors) and
// the booking hand-off of the user-confirmed quantities.
//
// Results come from TEST FIXTURES (test/fixtures/ai_scan_fixtures.dart):
// hand-written API-shaped bodies plus one genuine recorded Laravel response.
// The HTTP boundary is faked; no detector runs here.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/core/api/api_config.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_classification.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_scan_result.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/pending_detection_store.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/ai_scan_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/ai_scan_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart';

import '../../fixtures/ai_scan_fixtures.dart';

const _imageUrl = 'https://ecoxchange.test/storage/scans/y.png';

class _BookingRepo extends CustomerPickupBookingRepository {
  _BookingRepo() : super(ApiClient());

  int uploadCalls = 0;
  int classifyCalls = 0;
  Map<int, int>? lastEstimateQuantities;

  @override
  Future<ScanUploadResult> uploadImage(String filePath) async {
    uploadCalls++;
    return const ScanUploadResult(scanLogId: 77, imageUrl: _imageUrl);
  }

  @override
  Future<AIClassificationResult> classify(int scanLogId) async {
    classifyCalls++;
    return AIClassificationResult.fromJson(singleObjectClassifyFixture());
  }

  @override
  Future<PickupEstimate> estimate(Map<int, int> quantities) async {
    lastEstimateQuantities = Map.of(quantities);
    // Only the REQUEST is under test here; the response content is irrelevant.
    return const PickupEstimate(items: [], totalWeightKg: 0, preliminaryReward: 0, unavailableItemIds: [], note: null);
  }
}

/// Serves a fixture (or a pending future) — stands in for an AIScanRepository.
class _FakeScanRepo implements AIScanRepository {
  _FakeScanRepo({this.json, this.pending});

  final Map<String, dynamic>? json;
  final Completer<AIScanResult>? pending;
  int calls = 0;

  @override
  Future<AIScanResult> analyse(int scanLogId) async {
    calls++;
    if (pending != null) return pending!.future;
    return AIScanResult.fromJson(json!);
  }
}

/// Stands in for the /detect repository: analyse = POST (inference),
/// restore = GET (stored result, no inference).
class _FakeDetectionRepo implements AIDetectionRepository {
  _FakeDetectionRepo({this.json, this.analyseThrows, this.restoreThrows, this.onAnalyse});

  final Map<String, dynamic>? json;
  final Object? analyseThrows;
  final Object? restoreThrows;
  final void Function()? onAnalyse;
  final List<int> analysed = [];
  final List<int> restored = [];

  @override
  Future<AIScanResult> analyse(int scanLogId) async {
    analysed.add(scanLogId);
    onAnalyse?.call();
    if (analyseThrows != null) throw analyseThrows!;
    return AIScanResult.fromJson(json!);
  }

  @override
  Future<AIScanResult> restore(int scanLogId) async {
    restored.add(scanLogId);
    if (restoreThrows != null) throw restoreThrows!;
    return AIScanResult.fromJson(json!);
  }
}

/// Fakes only the HTTP boundary, so the REAL CustomerPickupBookingRepository
/// request building and response parsing run.
class _FakeApi extends ApiClient {
  _FakeApi(this.response);

  final Map<String, dynamic> response;
  String? method;
  String? path;
  Map<String, dynamic>? data;
  Duration? receiveTimeout;

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data, Duration? receiveTimeout}) async {
    method = 'POST';
    this.path = path;
    this.data = data;
    this.receiveTimeout = receiveTimeout;
    return response;
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    method = 'GET';
    this.path = path;
    return response;
  }
}

ItemModel _item(int id, String name) => ItemModel.fromJson(itemJson(id: id, name: name));

void main() {
  late Directory tempDir;
  late File tempImage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_scan_multi_test');
    tempImage = File('${tempDir.path}/photo.png')..writeAsBytesSync([0, 1, 2, 3]);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A provider that has run a real submitMultiObject() against [fixture].
  Future<AIScanProvider> detected(Map<String, dynamic> fixture, {PendingDetectionStore? store}) async {
    final provider = AIScanProvider(
      _BookingRepo(),
      detectionRepository: _FakeDetectionRepo(json: fixture),
      pendingStore: store ?? InMemoryPendingDetectionStore(),
    )..debugSetPickedImage(tempImage);
    await provider.submitMultiObject();
    return provider;
  }

  group('repository — real /detect request and response handling', () {
    test('POST /customer/pickup/detect with scan_log_id and the longer detect timeout; parses the real response', () async {
      final api = _FakeApi(realLaravelDetectResponse());

      final result = await DetectionScanRepository(CustomerPickupBookingRepository(api)).analyse(95);

      expect((api.method, api.path), ('POST', '/customer/pickup/detect'));
      expect(api.data, {'scan_log_id': 95});
      expect(api.receiveTimeout, ApiConfig.detectReceiveTimeout);
      expect(result.isMultiObject, isTrue);
      expect(result.lines.map((l) => (l.item!.id, l.suggestedQuantity)), [(10, 3), (1, 1)]);
    });

    test('read-back is GET /customer/pickup/detect/{scanLog}', () async {
      final api = _FakeApi(realLaravelDetectResponse());

      final result = await DetectionScanRepository(CustomerPickupBookingRepository(api)).restore(95);

      expect((api.method, api.path), ('GET', '/customer/pickup/detect/95'));
      expect(result.scanLogId, 95);
    });

    test('a malformed detection response is rejected as AI_INVALID_RESPONSE, never partially trusted', () async {
      final missingSummary = realLaravelDetectResponse()..remove('summary');
      final badStatus = realLaravelDetectResponse();
      (badStatus['detections'] as List).first['item_status'] = 'maybe';
      final notMulti = singleObjectClassifyFixture();

      for (final body in [missingSummary, badStatus, notMulti]) {
        final repo = CustomerPickupBookingRepository(_FakeApi(body));
        await expectLater(
          repo.detect(95),
          throwsA(isA<ServerException>().having((e) => e.code, 'code', 'AI_INVALID_RESPONSE')),
        );
      }
    });
  });

  group('backward compatibility — single-object classify is unchanged', () {
    test('submit() still classifies through /classify and never calls /detect', () async {
      final repo = _BookingRepo();
      final detection = _FakeDetectionRepo(json: multiObjectFixture());
      final provider = AIScanProvider(repo, detectionRepository: detection, pendingStore: InMemoryPendingDetectionStore())
        ..debugSetPickedImage(tempImage);

      await provider.submit();

      expect(repo.classifyCalls, 1);
      expect(detection.analysed, isEmpty);
      expect(provider.isMultiObjectResult, isFalse);
      expect(provider.result?.aiLabel, 'plastic_bottle', reason: 'the existing single-object getter still works');
      expect(provider.scanResult?.lines.single.suggestedQuantity, 1);
      expect(provider.scanLogId, 55);

      provider.confirmAiResult();
      expect(provider.confirmedItem?.id, 1, reason: 'single-object confirm flow unchanged');
    });

    test('an injected single-object scanRepository is still what submit() uses', () async {
      final scanRepo = _FakeScanRepo(json: multiObjectFixture());
      final provider = AIScanProvider(_BookingRepo(), scanRepository: scanRepo, pendingStore: InMemoryPendingDetectionStore())
        ..debugSetPickedImage(tempImage);

      await provider.submit();

      expect(scanRepo.calls, 1);
      expect(provider.isMultiObjectResult, isTrue);
    });
  });

  group('multi-object detect (submitMultiObject)', () {
    test('uploads once, then detects that scan_log_id — not /classify', () async {
      final repo = _BookingRepo();
      final detection = _FakeDetectionRepo(json: multiObjectFixture());
      final provider = AIScanProvider(repo, detectionRepository: detection, pendingStore: InMemoryPendingDetectionStore())
        ..debugSetPickedImage(tempImage);

      await provider.submitMultiObject();

      expect(repo.uploadCalls, 1);
      expect(repo.classifyCalls, 0);
      expect(detection.analysed, [77]);
      expect(provider.isMultiObjectResult, isTrue);
      expect(provider.isRestoredResult, isFalse);
      expect(provider.result, isNull, reason: 'single-object getter is null in multi-object mode');
      expect(provider.uploadedImageUrl, _imageUrl);
    });

    test('exposes the AI-suggested quantity per resolved material', () async {
      final provider = await detected(multiObjectFixture());

      expect(provider.suggestedQuantityOf(1), 4);
      expect(provider.suggestedQuantityOf(10), 1);
      expect(provider.quantityOf(1), 4);
      expect(provider.totalReviewedQuantity, 5);
      expect(provider.isQuantityCorrected(1), isFalse);
    });

    test('B/C/D. suggested quantities follow the detected objects per material', () async {
      expect((await detected(onePlasticBottleFixture())).suggestedQuantityOf(1), 1);
      expect((await detected(twoPlasticBottlesFixture())).suggestedQuantityOf(1), 2);

      final mixed = await detected(mixedGlass3Plastic2Fixture());
      expect((mixed.suggestedQuantityOf(10), mixed.suggestedQuantityOf(1)), (3, 2));
      expect(mixed.reviewedQuantities.map((l) => (l.item.id, l.quantity)), [(10, 3), (1, 2)]);
    });

    test('G. unclassified/unresolved objects are never counted until the user adds an item', () async {
      final provider = await detected(multiObjectAllReviewFixture());

      expect(provider.scanResult!.reviewDetections, hasLength(2));
      expect(provider.suggestedQuantityOf(1), 0, reason: 'a "bottle" detection is never booked as plastic_bottle');
      expect(provider.reviewedQuantities, isEmpty);

      provider.addManualItem(_item(3, 'Aluminium Can')); // the user resolves it
      expect(provider.isManuallyAdded(3), isTrue);
      expect(provider.suggestedQuantityOf(3), 0);
      expect(provider.reviewedQuantities.map((l) => (l.item.id, l.quantity)), [(3, 1)]);
    });

    test('adding an item the AI already suggested increments it instead of duplicating it', () async {
      final provider = await detected(multiObjectFixture());

      provider.addManualItem(_item(1, 'Plastic Bottle'));

      expect(provider.isManuallyAdded(1), isFalse);
      expect(provider.quantityOf(1), 5);
      expect(provider.reviewedQuantities.where((l) => l.item.id == 1), hasLength(1));
    });

    test('empty detection result: nothing to book', () async {
      final provider = await detected(multiObjectEmptyFixture());

      expect(provider.isMultiObjectResult, isTrue);
      expect(provider.reviewedQuantities, isEmpty);
    });

    test('the scan is remembered BEFORE detection runs, so a lost response can still be recovered', () async {
      final store = InMemoryPendingDetectionStore();
      PendingDetection? atDetectTime;
      final detection = _FakeDetectionRepo(json: multiObjectFixture(), onAnalyse: () => store.read().then((p) => atDetectTime = p));
      final provider = AIScanProvider(_BookingRepo(), detectionRepository: detection, pendingStore: store)
        ..debugSetPickedImage(tempImage);

      await provider.submitMultiObject();
      await Future<void>.delayed(Duration.zero);

      expect(atDetectTime?.scanLogId, 77);
      expect((await store.read())?.imageUrl, _imageUrl);
    });
  });

  group('E/F. user quantity correction', () {
    test('E. increment/decrement record a correction; the AI suggestion itself is kept', () async {
      final provider = await detected(multiObjectFixture());

      provider.incrementQuantity(1); // 4 -> 5
      expect(provider.quantityOf(1), 5);
      expect(provider.isQuantityCorrected(1), isTrue);
      expect(provider.suggestedQuantityOf(1), 4, reason: 'the AI suggestion is never overwritten');

      provider.decrementQuantity(10); // 1 -> 0
      expect(provider.quantityOf(10), 0);
      expect(provider.isQuantityCorrected(10), isTrue);

      provider.decrementQuantity(10); // stays at 0, never negative
      expect(provider.quantityOf(10), 0);
    });

    test('F. "Use AI suggestion" resets, and returning to the AI value clears the edited state', () async {
      final provider = await detected(multiObjectFixture());

      provider.setQuantity(1, 3);
      provider.setQuantity(1, 4);
      expect(provider.isQuantityCorrected(1), isFalse);

      provider.setQuantity(1, 7);
      provider.resetQuantityToSuggestion(1);
      expect(provider.quantityOf(1), 4);
      expect(provider.isQuantityCorrected(1), isFalse);
    });

    test('reviewedQuantities carries corrections and drops items set to 0', () async {
      final provider = await detected(multiObjectFixture());

      provider.setQuantity(1, 5);
      provider.setQuantity(10, 0);

      expect(provider.reviewedQuantities.map((l) => (l.item.id, l.quantity)), [(1, 5)]);
      expect(provider.totalReviewedQuantity, 5);
    });

    test('a new scan discards earlier corrections and manual items', () async {
      final provider = await detected(multiObjectFixture());
      provider.setQuantity(1, 9);
      provider.addManualItem(_item(3, 'Aluminium Can'));

      await provider.submitMultiObject();

      expect(provider.quantityOf(1), 4);
      expect(provider.isQuantityCorrected(1), isFalse);
      expect(provider.manualItems, isEmpty);
    });

    test('reset() clears the result, corrections and the remembered scan', () async {
      final store = InMemoryPendingDetectionStore();
      final provider = await detected(multiObjectFixture(), store: store);
      provider.setQuantity(1, 9);

      provider.reset();
      await Future<void>.delayed(Duration.zero);

      expect(provider.scanResult, isNull);
      expect(provider.isMultiObjectResult, isFalse);
      expect(provider.quantityOf(1), 0);
      expect(await store.read(), isNull);
    });
  });

  group('errors — nothing is ever fabricated', () {
    Future<AIScanProvider> failing(Object error) async {
      final provider = AIScanProvider(
        _BookingRepo(),
        detectionRepository: _FakeDetectionRepo(analyseThrows: error),
        pendingStore: InMemoryPendingDetectionStore(),
      )..debugSetPickedImage(tempImage);
      await provider.submitMultiObject();
      return provider;
    }

    test('H. 503 AI unavailable -> the clear user-facing message, no result', () async {
      final provider = await failing(const ServerException(
        'The AI detection service is currently unavailable. Please try again shortly.',
        statusCode: 503,
        code: 'AI_SERVICE_UNAVAILABLE',
      ));

      expect(provider.error?.message, AIScanProvider.aiUnavailableMessage);
      expect(provider.error?.message, 'AI classification is temporarily unavailable. Please try again or use manual selection.');
      expect((provider.error! as ServerException).code, 'AI_SERVICE_UNAVAILABLE');
      expect(provider.scanResult, isNull);
      expect(provider.reviewedQuantities, isEmpty);
      expect(provider.isSubmitting, isFalse);
    });

    test('network timeout, 401, 403 and 422 surface as their real errors with no result', () async {
      final cases = <ApiException>[
        const TimeoutApiException('The request took too long.'),
        const UnauthorizedException('Unauthenticated.'),
        const ForbiddenException('This action is unauthorized.'),
        const BusinessRuleException('The AI service could not process this image.', code: 'AI_INVALID_IMAGE'),
        const BusinessRuleException('The uploaded photo could not be found or has already been used.', code: 'IMAGE_INVALID'),
      ];
      for (final error in cases) {
        final provider = await failing(error);
        expect(provider.error, same(error), reason: '$error');
        expect(provider.scanResult, isNull);
      }
    });

    test('a malformed-response error keeps its message and leaves no result', () async {
      final provider = await failing(const ServerException(
        CustomerPickupBookingRepository.malformedDetectionMessage,
        code: 'AI_INVALID_RESPONSE',
      ));

      expect(provider.error?.message, CustomerPickupBookingRepository.malformedDetectionMessage);
      expect(provider.scanResult, isNull);
    });

    test('isSubmitting is true while detection is in flight, and nothing is shown early', () async {
      final pending = Completer<AIScanResult>();
      final provider = AIScanProvider(_BookingRepo(), scanRepository: _FakeScanRepo(pending: pending), pendingStore: InMemoryPendingDetectionStore())
        ..debugSetPickedImage(tempImage);

      final future = provider.submit();
      await Future<void>.delayed(Duration.zero);

      expect(provider.isSubmitting, isTrue);
      expect(provider.scanResult, isNull);

      pending.complete(AIScanResult.fromJson(multiObjectFixture()));
      await future;

      expect(provider.isSubmitting, isFalse);
      expect(provider.isMultiObjectResult, isTrue);
    });
  });

  group('read-back / resume (GET /customer/pickup/detect/{scanLog})', () {
    test('J. restores the stored result and its AI suggestions WITHOUT running inference', () async {
      final detection = _FakeDetectionRepo(json: realLaravelDetectResponse());
      final provider = AIScanProvider(
        _BookingRepo(),
        detectionRepository: detection,
        pendingStore: InMemoryPendingDetectionStore(const PendingDetection(scanLogId: 95, imageUrl: _imageUrl)),
      );

      await provider.resumePendingDetection();

      expect(detection.restored, [95]);
      expect(detection.analysed, isEmpty, reason: 'no new AI inference');
      expect(provider.isMultiObjectResult, isTrue);
      expect(provider.isRestoredResult, isTrue);
      expect(provider.scanLogId, 95);
      expect(provider.uploadedImageUrl, _imageUrl);
      expect(provider.pickedImage, isNull);
      expect((provider.suggestedQuantityOf(10), provider.suggestedQuantityOf(1)), (3, 1));
      expect(provider.isRestoring, isFalse);
    });

    test('I. 404 DETECTION_NOT_FOUND / IMAGE_INVALID -> nothing restored, no error, remembered scan forgotten', () async {
      for (final code in ['DETECTION_NOT_FOUND', 'IMAGE_INVALID']) {
        final store = InMemoryPendingDetectionStore(const PendingDetection(scanLogId: 95, imageUrl: _imageUrl));
        final provider = AIScanProvider(
          _BookingRepo(),
          detectionRepository: _FakeDetectionRepo(restoreThrows: ServerException('Not found.', statusCode: 404, code: code)),
          pendingStore: store,
        );

        await provider.resumePendingDetection();

        expect(provider.scanResult, isNull, reason: code);
        expect(provider.error, isNull, reason: code);
        expect(await store.read(), isNull, reason: code);
      }
    });

    test('a network failure during read-back keeps the remembered scan for a later attempt', () async {
      final store = InMemoryPendingDetectionStore(const PendingDetection(scanLogId: 95, imageUrl: _imageUrl));
      final provider = AIScanProvider(
        _BookingRepo(),
        detectionRepository: _FakeDetectionRepo(restoreThrows: const NetworkException('Could not connect.')),
        pendingStore: store,
      );

      await provider.resumePendingDetection();

      expect(provider.scanResult, isNull);
      expect((await store.read())?.scanLogId, 95);
    });

    test('with nothing remembered, no request is made', () async {
      final detection = _FakeDetectionRepo(json: realLaravelDetectResponse());
      final provider = AIScanProvider(_BookingRepo(), detectionRepository: detection, pendingStore: InMemoryPendingDetectionStore());

      await provider.resumePendingDetection();

      expect(detection.restored, isEmpty);
      expect(provider.scanResult, isNull);
    });

    test('a completed POST is not followed by a GET', () async {
      final detection = _FakeDetectionRepo(json: multiObjectFixture());
      final provider = AIScanProvider(_BookingRepo(), detectionRepository: detection, pendingStore: InMemoryPendingDetectionStore())
        ..debugSetPickedImage(tempImage);

      await provider.submitMultiObject();
      await provider.resumePendingDetection(); // e.g. a stray call: result already present

      expect(detection.analysed, [77]);
      expect(detection.restored, isEmpty);
    });
  });

  group('K. booking hand-off (weight/reward stay server-side)', () {
    test('the USER-CORRECTED quantities reach PickupBookingProvider and its estimate request', () async {
      final scan = await detected(mixedGlass3Plastic2Fixture()); // AI: glass 3, plastic 2
      scan.decrementQuantity(10); // user: glass 2
      scan.incrementQuantity(1); // user: plastic 3

      final repo = _BookingRepo();
      final booking = PickupBookingProvider(
        repo,
        CustomerAddressRepository(ApiClient()),
        CustomerRecyclingCentreRepository(ApiClient()),
        prefillQuantities: scan.reviewedQuantities,
        prefillScanLogId: scan.scanLogId,
        prefillImageUrl: scan.uploadedImageUrl,
      );

      expect(booking.quantities, {10: 2, 1: 3});
      expect(booking.hasAiSuggestedQuantities, isTrue);
      expect(booking.scanLogId, scan.scanLogId, reason: 'the same uploaded photo, not a second upload');
      expect(booking.uploadedImageUrl, _imageUrl);

      await booking.loadEstimate();
      expect(repo.lastEstimateQuantities, {10: 2, 1: 3}, reason: 'Laravel computes weight/reward from these');
    });

    test('prefillQuantities skips lines set to 0', () {
      final booking = PickupBookingProvider(
        _BookingRepo(),
        CustomerAddressRepository(ApiClient()),
        CustomerRecyclingCentreRepository(ApiClient()),
        prefillQuantities: [
          PrefillItemQuantity(item: _item(1, 'Plastic Bottle'), quantity: 5),
          PrefillItemQuantity(item: _item(3, 'Plastic Bag'), quantity: 0),
        ],
      );

      expect(booking.quantities, {1: 5});
    });

    test('the existing single-item prefill still defaults to quantity 1 and is not marked AI-suggested', () {
      final booking = PickupBookingProvider(
        _BookingRepo(),
        CustomerAddressRepository(ApiClient()),
        CustomerRecyclingCentreRepository(ApiClient()),
        prefillItem: _item(1, 'Plastic Bottle'),
      );

      expect(booking.quantities, {1: 1});
      expect(booking.hasAiSuggestedQuantities, isFalse);
    });
  });
}
