// EcoXchange Mobile — MultiImageScanSessionProvider tests (Part C).
//
// Pure state tests: each ScanRoundResult here stands in for what a real
// completed ScanClassifyScreen round would hand back (a real scan_log_id +
// confirmed quantities) — no HTTP, no image_picker. The behaviour under
// test is purely how rounds accumulate/combine/remove.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/multi_image_scan_session_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart';

ItemModel _item(int id, String name) {
  return ItemModel(
    id: id,
    name: name,
    category: 'Plastic',
    image: null,
    description: null,
    preliminaryBasePricePerKg: 0.40,
    priceNote: null,
    estimatedUnitWeightKg: 0.05,
    preparationSteps: null,
    recyclingTips: null,
    environmentalImpact: null,
  );
}

void main() {
  group('MultiImageScanSessionProvider', () {
    test('starts empty', () {
      final session = MultiImageScanSessionProvider();
      expect(session.isEmpty, isTrue);
      expect(session.roundCount, 0);
      expect(session.scanLogIds, isEmpty);
      expect(session.combinedQuantities, isEmpty);
    });

    test('a single round is a genuine subset — one scan_log_id, that round\'s own quantities', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');

      session.addRound(ScanRoundResult(scanLogId: 101, imageUrl: 'https://x/1.jpg', quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));

      expect(session.roundCount, 1);
      expect(session.scanLogIds, [101]);
      expect(session.representativeImageUrl, 'https://x/1.jpg');
      expect(session.combinedQuantities, [isA<PrefillItemQuantity>().having((l) => l.quantity, 'quantity', 1)]);
    });

    test('combines the SAME confirmed item across separate photos into one summed quantity', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');

      session.addRound(ScanRoundResult(scanLogId: 101, imageUrl: 'https://x/1.jpg', quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));
      session.addRound(ScanRoundResult(scanLogId: 102, imageUrl: 'https://x/2.jpg', quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));

      expect(session.roundCount, 2);
      expect(session.scanLogIds, [101, 102]);
      expect(session.combinedQuantities, hasLength(1));
      expect(session.combinedQuantities.first.quantity, 2);
      expect(session.totalCombinedQuantity, 2);
    });

    test('keeps different confirmed items as separate combined lines', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');
      final jar = _item(2, 'Glass Jar');

      session.addRound(ScanRoundResult(scanLogId: 101, imageUrl: null, quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));
      session.addRound(ScanRoundResult(scanLogId: 102, imageUrl: null, quantities: [PrefillItemQuantity(item: jar, quantity: 1)]));

      final combined = {for (final l in session.combinedQuantities) l.item.id: l.quantity};
      expect(combined, {1: 1, 2: 1});
    });

    test('a round with multiple reviewed lines (multi-object-in-one-photo) contributes every line', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');
      final jar = _item(2, 'Glass Jar');

      session.addRound(ScanRoundResult(
        scanLogId: 101,
        imageUrl: null,
        quantities: [PrefillItemQuantity(item: bottle, quantity: 3), PrefillItemQuantity(item: jar, quantity: 2)],
      ));

      final combined = {for (final l in session.combinedQuantities) l.item.id: l.quantity};
      expect(combined, {1: 3, 2: 2});
      expect(session.totalCombinedQuantity, 5);
    });

    test('removeRoundAt drops exactly that round\'s scan_log_id and recomputes the combined total', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');

      session.addRound(ScanRoundResult(scanLogId: 101, imageUrl: null, quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));
      session.addRound(ScanRoundResult(scanLogId: 102, imageUrl: null, quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));

      session.removeRoundAt(0);

      expect(session.roundCount, 1);
      expect(session.scanLogIds, [102]);
      expect(session.totalCombinedQuantity, 1);
    });

    test('removeRoundAt ignores an out-of-range index rather than throwing', () {
      final session = MultiImageScanSessionProvider();
      session.removeRoundAt(0);
      session.removeRoundAt(-1);
      expect(session.roundCount, 0);
    });

    test('addRound ignores a second round with the same scan_log_id (accidental duplicate insertion)', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');

      session.addRound(ScanRoundResult(scanLogId: 101, imageUrl: 'https://x/1.jpg', quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));
      // Same scan_log_id again — e.g. a double tap on "Continue" firing the
      // confirm handler twice before the screen actually pops.
      session.addRound(ScanRoundResult(scanLogId: 101, imageUrl: 'https://x/1.jpg', quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));

      expect(session.roundCount, 1);
      expect(session.totalCombinedQuantity, 1);
    });

    test('isFull is true once maxRounds is reached, and addRound beyond it is a no-op', () {
      final session = MultiImageScanSessionProvider();
      final bottle = _item(1, 'Plastic Bottle');

      for (var i = 0; i < MultiImageScanSessionProvider.maxRounds; i++) {
        session.addRound(ScanRoundResult(scanLogId: 1000 + i, imageUrl: null, quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));
      }
      expect(session.isFull, isTrue);

      session.addRound(ScanRoundResult(scanLogId: 9999, imageUrl: null, quantities: [PrefillItemQuantity(item: bottle, quantity: 1)]));

      expect(session.roundCount, MultiImageScanSessionProvider.maxRounds);
      expect(session.scanLogIds.contains(9999), isFalse);
    });
  });
}
