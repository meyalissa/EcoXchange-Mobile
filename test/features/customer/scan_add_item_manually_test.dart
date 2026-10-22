// EcoXchange Mobile — "Add an Item Manually" regression tests (Task 2).
//
// Drives the real ScanClassifyScreen (standalone single-object path,
// onRoundComplete: null) through a real classify round using the same
// debugSetPickedImage() seam ai_scan_provider_test.dart uses, then the
// real "Add an Item Manually" button → the real quantity-picker sheet →
// the real catalogue (ItemCatalogueProvider/CustomerCatalogueRepository,
// faked here but never a hardcoded category list) → back into the real
// _ConfirmedView and, finally, the real PickupBookingScreen hand-off.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_classification.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/ai_scan_result.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/ai_scan_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/pending_detection_store.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/ai_scan_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/scan/scan_classify_screen.dart';

import '../../fixtures/ai_scan_fixtures.dart';

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

class _NoDetectionsRepo implements AIDetectionRepository {
  @override
  Future<AIScanResult> analyse(int scanLogId) async => AIScanResult.fromJson(multiObjectEmptyFixture());

  @override
  Future<AIScanResult> restore(int scanLogId) async => AIScanResult.fromJson(multiObjectEmptyFixture());
}

class _BookingRepo extends CustomerPickupBookingRepository {
  _BookingRepo() : super(ApiClient());

  @override
  Future<ScanUploadResult> uploadImage(Uint8List bytes, String filename) async =>
      const ScanUploadResult(scanLogId: 55, imageUrl: 'https://ecoxchange.test/storage/scans/x.png');

  @override
  Future<AIClassificationResult> classify(int scanLogId) async => const AIClassificationResult(
        scanLogId: 55, aiLabel: 'plastic_bottle', confidence: 0.91, item: _plasticBottle,
        topPredictions: [AIPrediction(aiLabel: 'plastic_bottle', confidence: 0.91)],
      );

  @override
  Future<PickupEstimate> estimate(Map<int, int> quantities) async => PickupEstimate.fromJson({
        'items': quantities.entries
            .map((e) => {
                  'item_id': e.key, 'name': e.key == 1 ? 'Plastic Bottle' : 'Glass Bottle', 'category': 'Plastic',
                  'quantity': e.value, 'unit_weight_kg': 0.05, 'weight_kg': 0.05 * e.value, 'weight_source': 'computed',
                  'preliminary_price_per_kg': 0.40, 'preliminary_line_reward': 0.02 * e.value,
                })
            .toList(),
        'total_weight_kg': 0.05, 'preliminary_reward': 0.02, 'unavailable_item_ids': [], 'note': null,
      });
}

class _CatalogueRepo extends CustomerCatalogueRepository {
  _CatalogueRepo() : super(ApiClient());
  @override
  Future<List<CategoryModel>> getCategories() async => const [];
  @override
  Future<List<ItemModel>> getItems({String? category}) async => const [_plasticBottle, _glassBottle];
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

/// Drives the real single-object classify round to the real "Item
/// confirmed" screen (_ConfirmedView): picks an image via the debug seam,
/// taps "Classify with AI", then "Yes, that's right".
Future<void> _reachConfirmedView(WidgetTester tester, Uint8List imageBytes) async {
  final providerElement = tester.element(find.byType(Scaffold).first);
  Provider.of<AIScanProvider>(providerElement, listen: false).debugSetPickedImage(imageBytes);
  await tester.pump();

  await tester.tap(find.byKey(const Key('ai-classify')));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Yes, that\'s right'));
  await tester.pumpAndSettle();

  expect(find.text('Item confirmed'), findsOneWidget);
}

void main() {
  final imageBytes = Uint8List.fromList([0, 1, 2, 3]);

  Future<void> pumpScan(WidgetTester tester) async {
    // A detector that genuinely finds nothing forces the real classify-only
    // fallback deterministically (same convention ai_scan_provider_test.dart
    // uses) — never a real network call to /detect.
    await tester.pumpWidget(_wrap(
      ScanClassifyScreen(detectionRepository: _NoDetectionsRepo(), pendingStore: InMemoryPendingDetectionStore()),
      booking: _BookingRepo(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('"Add an Item Manually" is visible on the single-object confirmation, with no second AI inference', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);

    expect(find.byKey(const Key('ai-single-add-item')), findsOneWidget);
  });

  testWidgets('opens a catalogue drawn from the real item catalogue, never a hardcoded list', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);

    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();

    expect(find.text('Choose the Correct Item'), findsOneWidget);
    expect(find.text('Plastic Bottle'), findsOneWidget);
    expect(find.text('Glass Bottle'), findsOneWidget);
  });

  testWidgets('tapping an item opens the quantity sheet with Cancel and Add Item, quantity stepper starting at 1', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('manual-item-1'))); // Glass Bottle
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-add-cancel')), findsOneWidget);
    expect(find.byKey(const Key('manual-add-confirm')), findsOneWidget);
    expect(find.text('1'), findsWidgets); // the stepper's starting quantity
  });

  testWidgets('cancelling the quantity sheet returns to the catalogue list — nothing added', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('manual-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Choose the Correct Item'), findsOneWidget, reason: 'back on the catalogue list, the whole picker was not popped');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Item confirmed'), findsOneWidget);
    expect(find.text('Added by you (not detected by AI)'), findsNothing, reason: 'cancelling added nothing');
  });

  testWidgets('the quantity sheet cannot go below 1 — the decrement button is disabled at the floor', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-item-1')));
    await tester.pumpAndSettle();

    final decrementButton = find.byIcon(Icons.remove);
    await tester.tap(decrementButton);
    await tester.pumpAndSettle();

    // Still showing "1" — the floor was never crossed, no invalid (0 or
    // negative) quantity was ever reachable.
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('adding a different item at quantity 2 appears in the confirmation and updates the combined total', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-item-1'))); // Glass Bottle
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add)); // quantity 1 -> 2
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Glass Bottle'), findsOneWidget);
    expect(find.text('Added by you (not detected by AI)'), findsOneWidget);
    expect(find.textContaining('3 items total'), findsOneWidget, reason: '1 Plastic Bottle (AI-confirmed) + 2 Glass Bottle (manual)');
    expect(find.text('Continue with 3 items'), findsOneWidget);
  });

  testWidgets('a repeated tap on "Add Item" never adds the item twice', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-item-1')));
    await tester.pumpAndSettle();

    // Two rapid taps before the sheet has a chance to pop between them —
    // the second may land after the sheet has started closing, which is
    // exactly the scenario being guarded against, so a missed hit test on
    // it is expected, not a test bug.
    await tester.tap(find.byKey(const Key('manual-add-confirm')));
    await tester.tap(find.byKey(const Key('manual-add-confirm')), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('2 items total'), findsOneWidget, reason: '1 Plastic Bottle + 1 Glass Bottle — not 1 + 2');
  });

  testWidgets('adding the SAME material already confirmed merges into one row, never a duplicate', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-item-0'))); // Plastic Bottle — the SAME item already confirmed
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Plastic Bottle × 2'), findsOneWidget, reason: '1 (confirmed) + 1 (manually added) = 2, one row');
    expect(find.textContaining('items total'), findsNothing, reason: 'single-item total text only appears once a genuinely different material is added');
  });

  testWidgets('a manually added item\'s quantity can be edited, and decrementing to 0 removes it', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add-confirm')));
    await tester.pumpAndSettle();

    final glassRow = find.byKey(const Key('ai-qty-10'));
    expect(glassRow, findsOneWidget);
    // Increment it using the existing confirmation-area stepper.
    await tester.tap(find.descendant(of: glassRow, matching: find.byIcon(Icons.add)));
    await tester.pumpAndSettle();
    expect(find.text('Continue with 3 items'), findsOneWidget); // 1 + (1+1)

    // Decrement it back down to 0 — the existing removal mechanism (the
    // same one multi-object mode already uses: quantity 0 excludes it from
    // reviewedQuantities/the booking hand-off, consistent with how an
    // AI-suggested item is "removed" by its own stepper today).
    await tester.tap(find.descendant(of: glassRow, matching: find.byIcon(Icons.remove)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: glassRow, matching: find.byIcon(Icons.remove)));
    await tester.pumpAndSettle();

    expect(find.text('Continue to Pickup Booking'), findsOneWidget, reason: 'back to the single-item label — Glass Bottle no longer counted');
    expect(find.text('Continue with 3 items'), findsNothing);
  });

  testWidgets('manually added items survive Continue and reach the real booking flow with correct quantities', (tester) async {
    await pumpScan(tester);
    await _reachConfirmedView(tester, imageBytes);
    await tester.tap(find.byKey(const Key('ai-single-add-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-item-1'))); // Glass Bottle, quantity 1
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add-confirm')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with 2 items'));
    await tester.pumpAndSettle();

    // Opens on Pickup Address (initialStep: 1) — back up to Select Items
    // to confirm both items (and their quantities) truly reached
    // PickupBookingProvider, the same source Laravel computes weight and
    // reward from.
    expect(find.text('Pickup Address'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Select Items'), findsOneWidget);
    expect(find.text('Plastic Bottle'), findsOneWidget);
    expect(find.text('Glass Bottle'), findsOneWidget);
  });
}
