// EcoXchange Mobile — MultiObjectResultView widget tests.
//
// Driven by TEST FIXTURES (hand-written, API-shaped; see
// test/fixtures/ai_scan_fixtures.dart) through a fake detection repository.
// These verify the review UI only — no detector runs here.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_scan_result.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/pending_detection_store.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/ai_scan_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/ai_scan_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/scan/multi_object_result_view.dart';

import '../../fixtures/ai_scan_fixtures.dart';

class _BookingRepo extends CustomerPickupBookingRepository {
  _BookingRepo() : super(ApiClient());

  @override
  Future<ScanUploadResult> uploadImage(String filePath) async =>
      const ScanUploadResult(scanLogId: 77, imageUrl: 'https://ecoxchange.test/storage/scans/y.png');
}

class _FixtureDetectionRepo implements AIDetectionRepository {
  _FixtureDetectionRepo(this.json);

  final Map<String, dynamic> json;

  @override
  Future<AIScanResult> analyse(int scanLogId) async => AIScanResult.fromJson(json);

  @override
  Future<AIScanResult> restore(int scanLogId) async => AIScanResult.fromJson(json);
}

// A valid 1×1 PNG, so the photo widget has a real image file to reference.
const _png1x1 = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

void main() {
  // An off-screen tap must fail the test, never silently miss.
  WidgetController.hitTestWarningShouldBeFatal = true;

  late Directory tempDir;
  late File photo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('multi_object_view_test');
    photo = File('${tempDir.path}/photo.png')..writeAsBytesSync(_png1x1);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<AIScanProvider> scanned(Map<String, dynamic> fixture) async {
    final provider = AIScanProvider(
      _BookingRepo(),
      detectionRepository: _FixtureDetectionRepo(fixture),
      pendingStore: InMemoryPendingDetectionStore(),
    )..debugSetPickedImage(photo);
    await provider.submitMultiObject();
    return provider;
  }

  Future<void> pumpView(
    WidgetTester tester,
    AIScanProvider provider, {
    File? image,
    VoidCallback? onContinue,
    VoidCallback? onChooseManually,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeNotifierProvider.value(
              value: provider,
              child: MultiObjectResultView(
                image: image,
                onContinue: onContinue ?? () {},
                onChooseManually: onChooseManually ?? () {},
                onScanAnother: provider.reset,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Finder stepperButton(int itemId, IconData icon) =>
      find.descendant(of: find.byKey(Key('ai-qty-$itemId')), matching: find.byIcon(icon));

  testWidgets('lists every object with detector + material info, and the AI-suggested quantity per material', (tester) async {
    final provider = await scanned(multiObjectFixture());
    await pumpView(tester, provider);

    expect(find.text('AI DETECTED OBJECTS'), findsOneWidget);
    expect(find.text('Detected: 6 objects'), findsOneWidget);
    for (var i = 1; i <= 6; i++) {
      expect(find.byKey(Key('ai-detection-$i')), findsOneWidget);
    }
    final first = find.byKey(const Key('ai-detection-1'));
    expect(find.descendant(of: first, matching: find.text('Object 1 · detected as "bottle" (90%)')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('Plastic Bottle')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('Material confidence: 95%')), findsOneWidget);
    expect(find.text('Glass Bottle'), findsNWidgets(2), reason: 'detection row + quantity line');
    expect(find.text('5 counted · 1 needs manual review'), findsOneWidget);
    expect(find.text('Confirm quantities'), findsOneWidget);
    expect(find.text('AI suggested quantity: 4'), findsOneWidget);
    expect(find.text('AI suggested quantity: 1'), findsOneWidget);
    expect(find.text('Continue with 5 items'), findsOneWidget);
    expect(find.textContaining('Final weight and reward are calculated by EcoXchange'), findsOneWidget);
  });

  testWidgets('B/C/D. real per-material quantities: one, two and mixed', (tester) async {
    await pumpView(tester, await scanned(onePlasticBottleFixture()));
    expect(find.text('AI suggested quantity: 1'), findsOneWidget);

    await pumpView(tester, await scanned(twoPlasticBottlesFixture()));
    expect(find.text('AI suggested quantity: 2'), findsOneWidget);
    expect(find.text('Continue with 2 items'), findsOneWidget);

    await pumpView(tester, await scanned(mixedGlass3Plastic2Fixture()));
    expect(find.descendant(of: find.byKey(const Key('ai-qty-10')), matching: find.text('AI suggested quantity: 3')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('ai-qty-1')), matching: find.text('AI suggested quantity: 2')), findsOneWidget);
    expect(find.text('Continue with 5 items'), findsOneWidget);
  });

  testWidgets('G. an unclassified object is shown for manual review — never as a material', (tester) async {
    final provider = await scanned(multiObjectFixture());
    await pumpView(tester, provider);

    final row = find.byKey(const Key('ai-detection-6'));
    expect(find.descendant(of: row, matching: find.text('Unclassified')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Material unclear · needs manual review')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Plastic Bottle')), findsNothing);
    expect(find.byKey(const Key('ai-manual-review-notice')), findsOneWidget);
  });

  testWidgets('E/F. the user can correct a quantity; the correction is labelled and reversible', (tester) async {
    final provider = await scanned(multiObjectFixture());
    await pumpView(tester, provider);

    await tapVisible(tester, stepperButton(1, Icons.add));

    expect(provider.quantityOf(1), 5);
    expect(find.text('Edited by you'), findsOneWidget);
    expect(find.text('AI suggested quantity: 4'), findsOneWidget, reason: 'the AI suggestion stays visible');
    expect(find.text('Continue with 6 items'), findsOneWidget);

    await tapVisible(tester, find.text('Use AI suggestion'));

    expect(provider.quantityOf(1), 4);
    expect(find.text('Edited by you'), findsNothing);
    expect(find.text('Continue with 5 items'), findsOneWidget);
  });

  testWidgets('continue is disabled when every quantity is corrected to 0, and enabled otherwise', (tester) async {
    var continued = 0;
    final provider = await scanned(multiObjectFixture());
    await pumpView(tester, provider, onContinue: () => continued++);

    await tapVisible(tester, find.byKey(const Key('ai-multi-continue')));
    expect(continued, 1);

    provider
      ..setQuantity(1, 0)
      ..setQuantity(10, 0);
    await tester.pump();

    expect(find.text('Set at least 1 item'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('ai-multi-continue')));
    expect(continued, 1, reason: 'no hand-off with nothing to book');
  });

  testWidgets('a manually added item is listed as added by the user and counted', (tester) async {
    var addTapped = 0;
    final provider = await scanned(multiObjectAllReviewFixture());
    await pumpView(tester, provider, onChooseManually: () => addTapped++);

    await tapVisible(tester, find.byKey(const Key('ai-multi-add-item')));
    expect(addTapped, 1);

    // What the screen does with the item the user picks from the catalogue.
    provider.addManualItem(ItemModel.fromJson(itemJson(id: 7, name: 'Aluminium Can', category: 'Metal')));
    await tester.pump();

    expect(find.text('Added by you (not detected by AI)'), findsOneWidget);
    expect(find.text('Continue with 1 item'), findsOneWidget);
  });

  testWidgets('empty detection result shows a clear message and manual fallback', (tester) async {
    var manual = 0;
    final provider = await scanned(multiObjectEmptyFixture());
    await pumpView(tester, provider, onChooseManually: () => manual++);

    expect(find.text('No Items Detected'), findsOneWidget);
    expect(find.text('Confirm quantities'), findsNothing);

    await tapVisible(tester, find.text('Choose Item Manually'));
    expect(manual, 1);
  });

  testWidgets('nothing countable: explains why, keeps the real unsupported label', (tester) async {
    final provider = await scanned(multiObjectAllReviewFixture());
    await pumpView(tester, provider);

    expect(find.text('Material unclear · needs manual review'), findsOneWidget);
    expect(find.text('Not available on EcoXchange · needs manual review'), findsOneWidget);
    expect(find.text('Aluminium can'), findsOneWidget, reason: 'the real (unsupported) label is shown, not replaced');
    expect(find.byKey(const Key('ai-unresolved-aluminium_can')), findsOneWidget);
    expect(find.text('None of the detected objects could be counted as a supported item.'), findsOneWidget);
    expect(find.text('Set at least 1 item'), findsOneWidget);
  });

  testWidgets('bounding boxes are drawn over the photo when the image size is known', (tester) async {
    final provider = await scanned(multiObjectFixture());
    await pumpView(tester, provider, image: photo);

    expect(find.byKey(const Key('ai-detection-overlay')), findsOneWidget);
  });

  testWidgets('a restored result is labelled as read back, not re-run', (tester) async {
    final provider = AIScanProvider(
      _BookingRepo(),
      detectionRepository: _FixtureDetectionRepo(realLaravelDetectResponse()),
      pendingStore: InMemoryPendingDetectionStore(
        const PendingDetection(scanLogId: 95, imageUrl: 'https://ecoxchange.test/storage/scans/y.png'),
      ),
    );
    await provider.resumePendingDetection();
    await pumpView(tester, provider);

    expect(find.byKey(const Key('ai-restored-notice')), findsOneWidget);
    expect(find.text('AI suggested quantity: 3'), findsOneWidget);
    expect(find.text('AI suggested quantity: 1'), findsOneWidget);
  });
}
