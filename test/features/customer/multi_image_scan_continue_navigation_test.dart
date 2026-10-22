// EcoXchange Mobile — Task 1 (standardize scan-round navigation).
//
// Previously, the FIRST confirmed scan round skipped MultiImageScanScreen's
// own round summary and opened PickupBookingScreen directly, while every
// SUBSEQUENT round returned to the summary — an inconsistency this task
// fixes: every confirmed round, including the first, now returns to the
// summary, and booking only begins once the user explicitly taps
// "Continue →" there.
//
// (History: an EARLIER fix made the first round auto-continue specifically
// to avoid a confusing "it sent me back to AI Scan" feeling, from a time
// when this screen's own empty state was the first thing a user saw. That
// confusion no longer applies — MultiImageScanScreen now auto-opens
// Scan & Classify itself on a fresh session (a separate, still-current
// fix) — so landing on this summary after confirming is an expected
// forward step, not a bounce back, and the old special case just made the
// first round behave visibly differently from every later one.)
//
// This drives the REAL widgets and the REAL "Continue with N items" button
// (never instantiates PickupBookingScreen directly) through an injected
// fake detection repository — no real AI service, no `image_picker`
// platform channel.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_scan_result.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/pending_detection_store.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/ai_scan_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/ai_scan_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/scan/multi_image_scan_screen.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/scan/scan_classify_screen.dart';

import '../../fixtures/ai_scan_fixtures.dart';

class _BookingRepo extends CustomerPickupBookingRepository {
  _BookingRepo() : super(ApiClient());
  int _next = 201;
  int uploadCount = 0;

  @override
  Future<ScanUploadResult> uploadImage(Uint8List bytes, String filename) async {
    uploadCount++;
    final id = _next++;
    return ScanUploadResult(scanLogId: id, imageUrl: 'https://ecoxchange.test/storage/scans/$id.png');
  }

  @override
  Future<PickupEstimate> estimate(Map<int, int> quantities) async =>
      const PickupEstimate(items: [], totalWeightKg: 0, preliminaryReward: 0, unavailableItemIds: [], note: null);
}

/// Alternates plastic/glass per call, always embedding whatever scan_log_id
/// it was actually called with — matches how the real detector keys its
/// stored result off the real upload.
class _FakeDetectionRepo implements AIDetectionRepository {
  int _calls = 0;
  static const _labels = ['plastic_bottle', 'glass_bottle'];

  @override
  Future<AIScanResult> analyse(int scanLogId) async {
    final label = _labels[_calls % _labels.length];
    _calls++;
    return AIScanResult.fromJson(detectResponse([detectObject(1, label)], scanLogId: scanLogId));
  }

  @override
  Future<AIScanResult> restore(int scanLogId) async => analyse(scanLogId);
}

class _CatalogueRepo extends CustomerCatalogueRepository {
  _CatalogueRepo() : super(ApiClient());
  @override
  Future<List<CategoryModel>> getCategories() async => const [];
  @override
  Future<List<ItemModel>> getItems({String? category}) async => [
    ItemModel.fromJson(plasticBottleJson),
    ItemModel.fromJson(glassBottleJson),
  ];
}

class _AddressRepo extends CustomerAddressRepository {
  _AddressRepo() : super(ApiClient());
  @override
  Future<List<AddressModel>> getAddresses() async => const [];
}

class _CentreRepo extends CustomerRecyclingCentreRepository {
  _CentreRepo() : super(ApiClient());
}

Widget _wrap(Widget child, {required CustomerPickupBookingRepository booking}) {
  return MultiProvider(
    providers: [
      Provider<CustomerPickupBookingRepository>.value(value: booking),
      Provider<CustomerCatalogueRepository>.value(value: _CatalogueRepo()),
      Provider<CustomerAddressRepository>.value(value: _AddressRepo()),
      Provider<CustomerRecyclingCentreRepository>.value(value: _CentreRepo()),
    ],
    child: MaterialApp(home: child),
  );
}

/// Drives one real scan round to completion from wherever the empty picker
/// is currently showing (auto-opened for round 1, opened via "Add Another
/// Photo" for later rounds): sets a picked image through the same debug
/// seam ai_scan_provider_test.dart uses, taps "Classify with AI", then
/// "Continue with N items" on the real multi-object result — but does NOT
/// tap `multi-scan-continue` itself, since every round now returns to the
/// summary rather than booking.
Future<void> _scanOneRound(WidgetTester tester, Uint8List imageBytes) async {
  final providerElement = tester.element(
    find.descendant(of: find.byType(ScanClassifyScreen), matching: find.byType(Scaffold)).first,
  );
  Provider.of<AIScanProvider>(providerElement, listen: false).debugSetPickedImage(imageBytes);
  await tester.pump();

  await tester.tap(find.byKey(const Key('ai-classify')));
  await tester.pumpAndSettle();

  final continueButton = find.byKey(const Key('ai-multi-continue'));
  expect(continueButton, findsOneWidget, reason: 'the real AI result screen must be showing by now');
  await tester.ensureVisible(continueButton);
  await tester.pump();
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

void main() {
  final testImageBytes = Uint8List.fromList([0, 1, 2, 3]);

  testWidgets(
    'the FIRST confirmed round returns to the Scan Multiple Items summary — never opens booking directly',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();
      // Auto-opened — the user never has to tap "Scan a Photo" on an empty
      // Scan Multiple Items screen first (a separate, still-current fix).
      expect(find.text('Scan & Classify'), findsOneWidget);

      await _scanOneRound(tester, testImageBytes);

      // The behaviour this task fixes: the first round must land on the
      // summary, exactly like every later round — never Pickup Address.
      expect(find.text('Scan Multiple Items'), findsOneWidget);
      expect(find.text('Pickup Address'), findsNothing);
      expect(find.textContaining('1 photo'), findsOneWidget);
      expect(find.text('Plastic Bottle'), findsWidgets, reason: 'the first round is already in the combined summary');
      expect(find.byKey(const Key('multi-scan-continue')), findsOneWidget, reason: 'the user can now explicitly continue to booking');
    },
  );

  testWidgets(
    'the first round is inserted exactly once — never duplicated by the auto-open/continue sequence',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();

      await _scanOneRound(tester, testImageBytes);

      expect(find.textContaining('1 photo'), findsOneWidget);
      expect(find.byKey(const Key('scan-round-0')), findsOneWidget);
      expect(find.byKey(const Key('scan-round-1')), findsNothing);
      expect(booking.uploadCount, 1);
    },
  );

  testWidgets(
    'subsequent rounds use the SAME summary — consistent with the first, combined quantities stay correct',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();

      await _scanOneRound(tester, testImageBytes); // round 1: Plastic Bottle
      expect(find.text('Scan Multiple Items'), findsOneWidget);

      await tester.tap(find.text('Add Another Photo'));
      await tester.pumpAndSettle();
      await _scanOneRound(tester, Uint8List.fromList([4, 5, 6])); // round 2: Glass Bottle

      // Same screen, same summary behaviour as round 1 — not booking.
      expect(find.text('Scan Multiple Items'), findsOneWidget);
      expect(find.text('Pickup Address'), findsNothing);
      expect(find.textContaining('2 photos'), findsOneWidget);
      expect(find.text('Plastic Bottle'), findsOneWidget);
      expect(find.text('Glass Bottle'), findsOneWidget);
      expect(booking.uploadCount, 2, reason: 'two genuinely separate uploads, not one reused');
    },
  );

  testWidgets(
    'booking begins only once the user explicitly taps Continue from the summary — with the correct combined hand-off',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();

      await _scanOneRound(tester, testImageBytes);
      expect(find.text('Pickup Address'), findsNothing, reason: 'not yet — still on the summary');

      await tester.tap(find.byKey(const Key('multi-scan-continue')));
      await tester.pumpAndSettle();

      expect(find.text('Pickup Address'), findsOneWidget);
      expect(find.text('Scan Multiple Items'), findsNothing);
    },
  );

  testWidgets(
    'back navigation from booking still preserves the scan session — multi-image scanning is not lost',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();

      await _scanOneRound(tester, testImageBytes);
      await tester.tap(find.byKey(const Key('multi-scan-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Pickup Address'), findsOneWidget);

      // Back from Pickup Address -> Select Items (same booking screen, same data).
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Select Items'), findsOneWidget);
      expect(find.text('Plastic Bottle'), findsOneWidget, reason: 'the scanned item is still prefilled, not discarded');

      // Back again from Select Items -> the real Navigator pop -> the round
      // summary this session already has, with "Add Another Photo" visible.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Scan Multiple Items'), findsOneWidget);
      expect(find.text('Add Another Photo'), findsOneWidget, reason: 'multi-image scanning is still reachable, one Back tap away');
      expect(find.byKey(const Key('multi-scan-continue')), findsOneWidget);
      expect(find.textContaining('1 photo'), findsOneWidget, reason: 'the round was never lost or duplicated by backing out');
    },
  );
}
