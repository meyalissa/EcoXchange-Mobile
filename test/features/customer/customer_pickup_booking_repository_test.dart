// EcoXchange Mobile — CustomerPickupBookingRepository request-shape tests
// (Stage 3). A spy `ApiClient` subclass captures exactly what each
// repository method sends — no HTTP/Dio call ever happens — so these tests
// can assert the one security-relevant rule Stage 3 requires: no client-
// computed reward/rate/feasibility/weight-total field is EVER sent to the
// server, only the real `item_id`/`quantity` selection (and the plain
// scalar ids/strings each endpoint's own validation expects).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';

class _SpyApiClient extends ApiClient {
  String? lastPath;
  Map<String, dynamic>? lastData;
  Map<String, dynamic> responseData = const {};

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data, Duration? receiveTimeout}) async {
    lastPath = path;
    lastData = data;
    return responseData;
  }
}

void main() {
  group('CustomerPickupBookingRepository — request shape', () {
    test('estimate() sends only item_id/quantity — no client weight/reward', () async {
      final spy = _SpyApiClient()
        ..responseData = {'items': [], 'total_weight_kg': 0.0, 'preliminary_reward': 0.0, 'unavailable_item_ids': [], 'note': null};
      final repo = CustomerPickupBookingRepository(spy);

      await repo.estimate({5: 2, 9: 1});

      expect(spy.lastPath, '/customer/pickup/estimate');
      final items = spy.lastData!['items'] as List<dynamic>;
      expect(items, hasLength(2));
      for (final row in items.cast<Map<String, dynamic>>()) {
        expect(row.keys, containsAll(['item_id', 'quantity']));
        // Never a client-supplied weight/reward/rate on this endpoint.
        expect(row.containsKey('weight_kg'), isFalse);
        expect(row.containsKey('reward'), isFalse);
        expect(row.containsKey('price_per_kg'), isFalse);
      }
    });

    test('centres() sends items + address_id only — no client-side feasibility/rate', () async {
      final spy = _SpyApiClient()..responseData = {'centres': [], 'preliminary_reward': 0.0, 'unavailable_item_ids': [], 'message': null};
      final repo = CustomerPickupBookingRepository(spy);

      await repo.centres(quantities: {5: 1}, addressId: 42);

      expect(spy.lastPath, '/customer/pickup/centres');
      expect(spy.lastData!['address_id'], 42);
      expect(spy.lastData!.keys, containsAll(['items', 'address_id']));
      expect(spy.lastData!.containsKey('feasibility'), isFalse);
      expect(spy.lastData!.containsKey('estimated_reward'), isFalse);
    });

    test('review() sends items/address_id/center_id (+ optional scan_log_id) only', () async {
      final spy = _SpyApiClient()..responseData = _minimalReviewJson();
      final repo = CustomerPickupBookingRepository(spy);

      await repo.review(quantities: {5: 1}, addressId: 42, centerId: 7, scanLogId: 3);

      expect(spy.lastPath, '/customer/pickup/review');
      expect(spy.lastData!['address_id'], 42);
      expect(spy.lastData!['center_id'], 7);
      expect(spy.lastData!['scan_log_id'], 3);
      expect(spy.lastData!.containsKey('notes'), isFalse); // /review's own validation doesn't accept notes
      expect(spy.lastData!.containsKey('pickup_date'), isFalse);
      expect(spy.lastData!.containsKey('ready_to_submit'), isFalse);
    });

    test('review() omits scan_log_id entirely when none was uploaded', () async {
      final spy = _SpyApiClient()..responseData = _minimalReviewJson();
      final repo = CustomerPickupBookingRepository(spy);

      await repo.review(quantities: {5: 1}, addressId: 42, centerId: 7);

      expect(spy.lastData!.containsKey('scan_log_id'), isFalse);
    });

    test('submit() sends exactly the real submission fields — never a client reward/feasibility/weight total', () async {
      final spy = _SpyApiClient()..responseData = {'pickup': _minimalPickupJson()};
      final repo = CustomerPickupBookingRepository(spy);

      await repo.submit(
        quantities: {5: 2},
        addressId: 42,
        centerId: 7,
        pickupDate: '2026-12-01',
        pickupTime: '08:00-10:00',
        notes: 'Leave at gate',
        scanLogId: 3,
      );

      expect(spy.lastPath, '/customer/pickup');
      expect(spy.lastData!.keys, containsAll(['items', 'address_id', 'center_id', 'pickup_date', 'pickup_time', 'notes', 'scan_log_id']));
      expect(spy.lastData!.containsKey('estimated_reward'), isFalse);
      expect(spy.lastData!.containsKey('total_weight_kg'), isFalse);
      expect(spy.lastData!.containsKey('feasibility'), isFalse);
      expect(spy.lastData!.containsKey('rate'), isFalse);
    });

    test('submit() omits notes when blank/whitespace-only rather than sending an empty string', () async {
      final spy = _SpyApiClient()..responseData = {'pickup': _minimalPickupJson()};
      final repo = CustomerPickupBookingRepository(spy);

      await repo.submit(quantities: {5: 1}, addressId: 42, centerId: 7, pickupDate: '2026-12-01', pickupTime: '08:00-10:00', notes: '   ');

      expect(spy.lastData!.containsKey('notes'), isFalse);
    });
  });

  group('CustomerPickupBookingRepository — classify() (Stage 4.6)', () {
    test('classify() sends only scan_log_id and parses the real AI response shape', () async {
      final spy = _SpyApiClient()
        ..responseData = {
          'scan_log_id': 55,
          'ai_label': 'plastic_bottle',
          'confidence': 0.987,
          'item': {
            'id': 1, 'name': 'Plastic Bottle', 'category': 'Plastic', 'image': null, 'description': null,
            'preliminary_base_price_per_kg': 0.40, 'price_note': null, 'estimated_unit_weight_kg': 0.05,
            'preparation_steps': null, 'recycling_tips': null, 'environmental_impact': null,
          },
          'top_predictions': [
            {'ai_label': 'plastic_bottle', 'confidence': 0.987},
            {'ai_label': 'glass_bottle', 'confidence': 0.010},
          ],
        };
      final repo = CustomerPickupBookingRepository(spy);

      final result = await repo.classify(55);

      expect(spy.lastPath, '/customer/pickup/classify');
      expect(spy.lastData, {'scan_log_id': 55});
      expect(result.aiLabel, 'plastic_bottle');
      expect(result.confidence, 0.987);
      expect(result.item.id, 1);
      expect(result.item.name, 'Plastic Bottle');
      expect(result.topPredictions, hasLength(2));
      expect(result.topPredictions.first.aiLabel, 'plastic_bottle');
    });
  });
}

Map<String, dynamic> _minimalReviewJson() {
  return {
    'ready_to_submit': true,
    'reasons': [],
    'address': {
      'id': 1, 'label': null, 'house_no': '1', 'street_name': 'A', 'city': 'KL', 'postcode': '58100',
      'state': 'WP', 'formatted': '1, A, KL', 'short_address': null, 'latitude': 3.1, 'longitude': 101.6,
      'has_coordinates': true, 'is_default': true,
    },
    'centre': {'id': 7, 'name': 'EcoGreen'},
    'items': [],
    'total_weight_kg': 0.0,
    'feasibility': null,
    'image': null,
  };
}

Map<String, dynamic> _minimalPickupJson() {
  return {
    'id': 1, 'reference': 'PK-1', 'status': 'pending', 'notes': null, 'pickup_date': '2026-12-01',
    'pickup_time': '08:00-10:00', 'estimated_weight_kg': 0.5, 'actual_weight_kg': null,
    'estimated_reward': 0.5, 'actual_reward': null, 'created_at': null, 'address': null, 'items': [],
    'centre': null, 'assigned_rider': null, 'image_url': null,
  };
}
