// EcoXchange Mobile — Pickup Booking widget tests (Stage 3).
//
// Real widgets pumped against faked repositories (same convention as every
// other widget test in this project — no HTTP/Dio call ever happens).
// Focused on the gating rules the brief explicitly requires: cannot
// proceed without a required selection, and a not-ready review blocks
// submission.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/item_catalogue_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/booking/booking_items_step.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/booking/booking_review_step.dart';

class _OneItemCatalogueRepository extends CustomerCatalogueRepository {
  _OneItemCatalogueRepository() : super(ApiClient());

  @override
  Future<List<CategoryModel>> getCategories() async => const [];

  @override
  Future<List<ItemModel>> getItems({String? category}) async => [
        const ItemModel(
          id: 1,
          name: 'Plastic Bottle',
          category: 'Plastic',
          image: null,
          description: null,
          preliminaryBasePricePerKg: 0.40,
          priceNote: 'Preliminary estimate only.',
          estimatedUnitWeightKg: 0.05,
          preparationSteps: null,
          recyclingTips: null,
          environmentalImpact: null,
        ),
      ];
}

class _FakeBookingRepository extends CustomerPickupBookingRepository {
  _FakeBookingRepository() : super(ApiClient());

  @override
  Future<PickupEstimate> estimate(Map<int, int> quantities) async {
    return PickupEstimate.fromJson({
      'items': quantities.entries
          .map((e) => {
                'item_id': e.key, 'name': 'Plastic Bottle', 'category': 'Plastic', 'quantity': e.value,
                'unit_weight_kg': 0.05, 'weight_kg': 0.05 * e.value, 'weight_source': 'computed',
                'preliminary_price_per_kg': 0.40, 'preliminary_line_reward': 0.02 * e.value,
              })
          .toList(),
      'total_weight_kg': 0.05,
      'preliminary_reward': 0.02,
      'unavailable_item_ids': [],
      'note': 'Preliminary estimate only.',
    });
  }
}

Widget _wrap({required PickupBookingProvider booking, required Widget child, ItemCatalogueProvider? catalogue}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: booking),
      if (catalogue != null) ChangeNotifierProvider.value(value: catalogue),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('BookingItemsStep', () {
    testWidgets('Continue is disabled until at least one item is selected, then enabled', (tester) async {
      final booking = PickupBookingProvider(_FakeBookingRepository(), CustomerAddressRepository(ApiClient()), CustomerRecyclingCentreRepository(ApiClient()));
      final catalogue = ItemCatalogueProvider(_OneItemCatalogueRepository());

      await tester.pumpWidget(_wrap(booking: booking, catalogue: catalogue, child: BookingItemsStep(onNext: () {})));
      await tester.pumpAndSettle();

      final continueButton = find.widgetWithText(ElevatedButton, 'Select at least 1 item');
      expect(continueButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

      // Tap the "+" stepper on the one real item card.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(booking.hasSelectedItems, isTrue);
      final enabledButton = find.widgetWithText(ElevatedButton, 'Continue with 1 item');
      expect(enabledButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(enabledButton).onPressed, isNotNull);
    });

    testWidgets('tapping Continue calls the real estimate endpoint and advances on success', (tester) async {
      final booking = PickupBookingProvider(_FakeBookingRepository(), CustomerAddressRepository(ApiClient()), CustomerRecyclingCentreRepository(ApiClient()));
      final catalogue = ItemCatalogueProvider(_OneItemCatalogueRepository());
      var advanced = false;

      await tester.pumpWidget(_wrap(booking: booking, catalogue: catalogue, child: BookingItemsStep(onNext: () => advanced = true)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with 1 item'));
      await tester.pumpAndSettle();

      expect(booking.estimate, isNotNull);
      expect(advanced, isTrue);
    });
  });

  group('BookingReviewStep', () {
    ReviewResult notReadyReview() => ReviewResult.fromJson({
          'ready_to_submit': false,
          'reasons': [
            {'code': 'MINIMUM_NOT_REACHED', 'message': 'Your estimated reward is below this recycling centre\'s minimum pickup requirement.'},
          ],
          'address': {
            'id': 1, 'label': 'Home', 'house_no': '1', 'street_name': 'A', 'city': 'KL', 'postcode': '58100',
            'state': 'WP', 'formatted': '1, A, KL', 'short_address': null, 'latitude': 3.1, 'longitude': 101.6,
            'has_coordinates': true, 'is_default': true,
          },
          'centre': {'id': 1, 'name': 'EcoGreen'},
          'items': [],
          'total_weight_kg': 0.0,
          'feasibility': null,
          'image': null,
        });

    testWidgets('a not-ready review shows the real reasons and disables Submit', (tester) async {
      final booking = _ReviewSeededBookingProvider(review: notReadyReview());

      await tester.pumpWidget(_wrap(booking: booking, child: BookingReviewStep(onBack: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Not Ready to Submit'), findsOneWidget);
      expect(find.textContaining('minimum pickup requirement'), findsOneWidget);

      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Pickup');
      expect(submitButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);
    });
  });
}

/// A `PickupBookingProvider` whose `loadReview()` is pre-seeded with a
/// fixed result (via the real repository, faked) — avoids re-driving the
/// whole items/address/centre selection just to reach the Review step in
/// a widget test.
class _ReviewSeededBookingProvider extends PickupBookingProvider {
  _ReviewSeededBookingProvider({required ReviewResult review})
      : super(_SeededReviewRepository(review), CustomerAddressRepository(ApiClient()), CustomerRecyclingCentreRepository(ApiClient())) {
    setQuantity(
      const ItemModel(
        id: 1, name: 'Plastic Bottle', category: 'Plastic', image: null, description: null,
        preliminaryBasePricePerKg: 0.40, priceNote: null, estimatedUnitWeightKg: 0.05,
        preparationSteps: null, recyclingTips: null, environmentalImpact: null,
      ),
      1,
    );
    addAddressAndSelect(_fixtureAddress);
    selectCentre(_fixtureCentre);
  }
}

class _SeededReviewRepository extends CustomerPickupBookingRepository {
  _SeededReviewRepository(this._review) : super(ApiClient());

  final ReviewResult _review;

  @override
  Future<ReviewResult> review({required Map<int, int> quantities, required int addressId, required int centerId, int? scanLogId}) async => _review;
}

const _fixtureAddress = AddressModelFixture();
const _fixtureCentre = EligibleCentre(
  id: 1,
  name: 'EcoGreen',
  address: 'Somewhere',
  distanceKm: 1.0,
  distanceLabel: '1.0 km',
  eligible: true,
  missingItems: [],
  rates: [],
  estimatedReward: 0.5,
  recommended: true,
  rewardDelta: 0.0,
  rewardChangeNote: null,
);

/// A trivial `const`-constructible stand-in — `AddressModel` itself has no
/// `const` constructor (it's built from real JSON), so this fixture wraps
/// one with the fields `PickupBookingProvider.addAddressAndSelect` needs.
class AddressModelFixture extends AddressModel {
  const AddressModelFixture()
      : super(
          id: 1,
          label: 'Home',
          houseNo: '1',
          streetName: 'A',
          city: 'KL',
          postcode: '58100',
          state: 'WP',
          formatted: '1, A, KL',
          shortAddress: null,
          latitude: 3.1,
          longitude: 101.6,
          hasCoordinates: true,
          isDefault: true,
        );
}
