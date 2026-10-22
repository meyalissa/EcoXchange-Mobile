// EcoXchange Mobile — regression tests for "Add Another Photo" (Part C /
// multi-image scan session).
//
// The real bug: tapping "Add Another Photo" appeared to silently reopen the
// PREVIOUS photo instead of asking the user to choose a camera/gallery
// source. Root cause, confirmed by inspection:
//   ScanClassifyScreen's `AIScanProvider` always called
//   `resumePendingDetection()` on creation to recover a genuinely
//   unfinished scan after e.g. an app restart. But a round's "pending
//   detection" marker was never cleared once that round was CONFIRMED and
//   handed off (the save happens before detection even runs, and nothing
//   cleared it afterwards) — so when "Add Another Photo" opened a brand
//   new ScanClassifyScreen for round 2, it read back round 1's own
//   already-finished result and showed it as if it were round 2's photo.
//
// Fixed in two complementary places:
//   1. AIScanProvider.forgetConfirmedScan() — called the moment a round is
//      actually confirmed/handed off, so it stops being "pending" at all.
//   2. ScanClassifyScreen only calls resumePendingDetection() for the
//      STANDALONE entry point (onRoundComplete == null) — a round WITHIN a
//      multi-image session never attempts to resume anything, regardless
//      of what (if anything) is in the pending-detection store.
//
// Also reflects the "standardize scan-round navigation" fix: every
// confirmed round (including the first) now returns to
// MultiImageScanScreen's own summary rather than the first one jumping
// straight to booking — see multi_image_scan_continue_navigation_test.dart
// for the dedicated tests of that behaviour. `_completeOneRound` below
// relies on this: it lands back on the summary directly, with no need to
// back out of a booking screen first.
//
// `image_picker`'s real platform channel is never mocked here (consistent
// with this codebase's established convention — see
// edit_personal_info_provider_test.dart and ai_scan_provider_test.dart):
// AIScanProvider.pickImage() already treats a platform-channel failure
// identically to a user cancellation (a silent, state-preserving return),
// so tapping the real "Take a Photo"/"Choose from Gallery" options in a
// widget test exercises the real UI flow up to that call, and then behaves
// exactly like a cancel — which is also genuinely useful for testing
// "cancelling preserves existing results". The native picker/camera itself
// is NOT exercised by these tests (see the task's final report).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
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

/// Assigns a fresh scan_log_id per upload (201, 202, ...) — a real upload
/// never reuses one, so these tests can tell two genuinely different
/// rounds apart from an accidental duplicate.
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
/// it was actually called with (never a hardcoded one), matching how the
/// real detector keys its stored result off the real upload.
class _FakeDetectionRepo implements AIDetectionRepository {
  int _calls = 0;
  final Map<int, Map<String, dynamic>> _byScanLog = {};
  static const _labels = ['plastic_bottle', 'glass_bottle'];

  @override
  Future<AIScanResult> analyse(int scanLogId) async {
    final label = _labels[_calls % _labels.length];
    _calls++;
    final json = detectResponse([detectObject(1, label)], scanLogId: scanLogId);
    _byScanLog[scanLogId] = json;
    return AIScanResult.fromJson(json);
  }

  @override
  Future<AIScanResult> restore(int scanLogId) async {
    final json = _byScanLog[scanLogId];
    if (json == null) {
      throw const ServerException('not found', statusCode: 404, code: 'DETECTION_NOT_FOUND');
    }
    return AIScanResult.fromJson(json);
  }
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

/// Drives one real round to completion from wherever the empty picker is
/// currently showing (auto-opened for round 1, opened via "Add Another
/// Photo" for later rounds): sets a picked image through the same debug
/// seam ai_scan_provider_test.dart uses, taps "Classify with AI", then
/// "Continue with N items" on the real multi-object result — landing back
/// on MultiImageScanScreen's own summary (every round, including the
/// first, now behaves this way; see this file's header).
Future<void> _completeOneRound(WidgetTester tester, Uint8List imageBytes) async {
  final providerElement = tester.element(
    find.descendant(of: find.byType(ScanClassifyScreen), matching: find.byType(Scaffold)).first,
  );
  Provider.of<AIScanProvider>(providerElement, listen: false).debugSetPickedImage(imageBytes);
  await tester.pump();

  await tester.tap(find.byKey(const Key('ai-classify')));
  await tester.pumpAndSettle();

  final continueButton = find.byKey(const Key('ai-multi-continue'));
  await tester.ensureVisible(continueButton);
  await tester.pump();
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

void main() {
  final imageBytes = Uint8List.fromList([0, 1, 2, 3]);

  testWidgets(
    'the real bug: "Add Another Photo" never silently reopens the previous round\'s photo — it shows the empty picker',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Scan & Classify'), findsOneWidget, reason: 'round 1 auto-opened');

      await _completeOneRound(tester, imageBytes);
      // Lands straight back on the summary (Task 1: standardized
      // navigation — the first round behaves exactly like every later one).
      expect(find.text('Add Another Photo'), findsOneWidget);

      await tester.tap(find.text('Add Another Photo'));
      await tester.pumpAndSettle();

      // The real regression this fixes: before the fix, this would show
      // round 1's already-confirmed Plastic Bottle result again instead of
      // an empty picker.
      expect(find.text('Scan a Recyclable Item'), findsOneWidget, reason: 'a genuinely empty picker, never a restored result');
      expect(find.text('Plastic Bottle'), findsNothing);
      expect(find.text('AI SUGGESTION'), findsNothing);
    },
  );

  testWidgets(
    'a stale pending-detection entry is never resumed into a new round, regardless of what is in storage',
    (tester) async {
      // Isolates the resumePendingDetection()-skip fix specifically: seeds
      // the store with an unrelated stale entry BEFORE the session even
      // starts, proving a round within a multi-image session ignores it
      // unconditionally rather than relying on it having been cleared.
      final staleStore = InMemoryPendingDetectionStore(
        const PendingDetection(scanLogId: 999, imageUrl: 'https://ecoxchange.test/storage/scans/stale.png'),
      );
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: staleStore),
        booking: booking,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Scan & Classify'), findsOneWidget);
      expect(find.text('Scan a Recyclable Item'), findsOneWidget, reason: 'never silently restores the stale entry');
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'not even attempting a restore request');
    },
  );

  testWidgets('"Add Another Photo" shows a camera/gallery choice, not an immediate re-scan', (tester) async {
    final booking = _BookingRepo();
    await tester.pumpWidget(_wrap(
      MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
      booking: booking,
    ));
    await tester.pumpAndSettle();
    await _completeOneRound(tester, imageBytes);

    await tester.tap(find.text('Add Another Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan a Photo')); // the empty picker's own CTA
    await tester.pumpAndSettle();

    expect(find.text('Take a Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('cancelling the source sheet preserves the existing round — nothing is lost, nothing crashes', (tester) async {
    final booking = _BookingRepo();
    await tester.pumpWidget(_wrap(
      MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
      booking: booking,
    ));
    await tester.pumpAndSettle();
    await _completeOneRound(tester, imageBytes);
    expect(find.textContaining('1 photo'), findsOneWidget);

    await tester.tap(find.text('Add Another Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan a Photo'));
    await tester.pumpAndSettle();
    // Dismiss the sheet without choosing a source (tap the scrim) — the
    // modal bottom sheet resolves with null, exactly like a real "back".
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Add Another Photo'), findsOneWidget);
    expect(find.textContaining('1 photo'), findsOneWidget, reason: 'round 1 is still intact after cancelling');
  });

  testWidgets(
    'tapping "Take a Photo" in the test environment (no real camera plugin) behaves like a cancel — round 1 is preserved',
    (tester) async {
      final booking = _BookingRepo();
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: booking,
      ));
      await tester.pumpAndSettle();
      await _completeOneRound(tester, imageBytes);

      await tester.tap(find.text('Add Another Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan a Photo'));
      await tester.pumpAndSettle();

      // No `image_picker` platform channel is mocked here (see this file's
      // header) — AIScanProvider.pickImage() already catches a
      // platform-channel failure the same way it catches a real
      // cancellation, so this exercises the real tap through to that call
      // without claiming the native camera itself was invoked.
      await tester.tap(find.text('Take a Photo'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Scan a Recyclable Item'), findsOneWidget, reason: 'back on the empty picker, not crashed, nothing fabricated');
    },
  );

  testWidgets('a second real round combines item counts correctly and keeps round 1\'s items', (tester) async {
    final booking = _BookingRepo();
    final detection = _FakeDetectionRepo();
    await tester.pumpWidget(_wrap(
      MultiImageScanScreen(detectionRepository: detection, pendingStore: InMemoryPendingDetectionStore()),
      booking: booking,
    ));
    await tester.pumpAndSettle();

    await _completeOneRound(tester, imageBytes); // round 1: Plastic Bottle
    expect(find.textContaining('1 photo'), findsOneWidget);

    await tester.tap(find.text('Add Another Photo'));
    await tester.pumpAndSettle();
    await _completeOneRound(tester, Uint8List.fromList([4, 5, 6])); // round 2: Glass Bottle
    // A later round lands on the same summary as the first — consistent.
    expect(find.text('Scan Multiple Items'), findsOneWidget);

    expect(find.textContaining('2 photos'), findsOneWidget);
    expect(booking.uploadCount, 2, reason: 'two genuinely separate uploads, not one reused');
    expect(find.text('Plastic Bottle'), findsOneWidget);
    expect(find.text('Glass Bottle'), findsOneWidget);
    expect(find.text('× 1'), findsNWidgets(2), reason: 'combined: 1 Plastic Bottle, 1 Glass Bottle — never merged into one line');
  });

  testWidgets('removing one round updates the combined summary and round count', (tester) async {
    final booking = _BookingRepo();
    final detection = _FakeDetectionRepo();
    await tester.pumpWidget(_wrap(
      MultiImageScanScreen(detectionRepository: detection, pendingStore: InMemoryPendingDetectionStore()),
      booking: booking,
    ));
    await tester.pumpAndSettle();

    await _completeOneRound(tester, imageBytes);
    await tester.tap(find.text('Add Another Photo'));
    await tester.pumpAndSettle();
    await _completeOneRound(tester, Uint8List.fromList([4, 5, 6]));
    expect(find.textContaining('2 photos'), findsOneWidget);

    // Tap the remove (×) button on the first round card specifically.
    await tester.tap(find.descendant(of: find.byKey(const Key('scan-round-0')), matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 photo'), findsOneWidget);
    expect(find.text('Glass Bottle'), findsOneWidget, reason: 'round 2 (glass) remains — only round 1 (plastic) was removed');
    expect(find.text('Plastic Bottle'), findsNothing);
  });

  group('narrow-width layout (Task 3 — no clipped "Add Another Photo" label)', () {
    testWidgets('both bottom actions render at a ~320px-wide screen with no overflow', (tester) async {
      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: _BookingRepo(),
      ));
      await tester.pumpAndSettle();
      await _completeOneRound(tester, imageBytes);
      expect(find.text('Add Another Photo'), findsOneWidget);

      // Shrink the viewport only once back on MultiImageScanScreen's own
      // summary, isolating the check to the one screen this task changed
      // (the AI-result screen this round briefly passed through is a
      // separate concern).
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The full label, not a truncated "Add Another P…" — both are now
      // full-width stacked buttons, never competing for half the screen.
      expect(find.text('Add Another Photo'), findsOneWidget);
      expect(find.byKey(const Key('multi-scan-continue')), findsOneWidget);
    });

    testWidgets('the empty-session "Scan a Photo" state also fits at a ~320px-wide screen', (tester) async {
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        MultiImageScanScreen(detectionRepository: _FakeDetectionRepo(), pendingStore: InMemoryPendingDetectionStore()),
        booking: _BookingRepo(),
      ));
      await tester.pumpAndSettle();

      // Auto-opens Scan & Classify (Task 1) — its own empty picker, not
      // the Scan Multiple Items bottom bar, is what's on screen here.
      expect(tester.takeException(), isNull);
      expect(find.text('Scan a Recyclable Item'), findsOneWidget);
    });
  });
}
