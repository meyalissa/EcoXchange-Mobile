// EcoXchange Mobile — Pickup Booking Step 3's "All Centres" tab
// (Recycling Centre Discovery inside the booking flow). Confirms the
// safety boundary BookingCentreStep's own docblock describes: an
// external/non-pickup-supported centre is visibly labelled and browsable,
// but tapping it can never set `PickupBookingProvider.selectedCentre` --
// only the unchanged "Pickup Available" tab's real `EligibleCentre` rows
// can do that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/nearby_recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/booking/booking_centre_step.dart';

import '../../fixtures/recycling_centre_fixtures.dart';

class _FakeCentreRepository extends CustomerRecyclingCentreRepository {
  _FakeCentreRepository(this.result) : super(ApiClient());

  final List<NearbyRecyclingCentre> result;

  @override
  Future<List<NearbyRecyclingCentre>> getNearby({required double lat, required double lng, String? search, double? radiusKm}) async => result;
}

const _address = AddressModel(
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

void main() {
  testWidgets('the All Centres tab shows the external centre, clearly labelled, and never lets it be selected', (tester) async {
    final pickupCentre = NearbyRecyclingCentre.fromJson(nearbyCentreJson(id: 1, name: 'EcoGreen Recycling Centre'));
    final externalCentre = NearbyRecyclingCentre.fromJson(externalCentreJson(id: 2, name: 'Discovered Scrap Metal Yard'));

    final booking = PickupBookingProvider(
      CustomerPickupBookingRepository(ApiClient()),
      CustomerAddressRepository(ApiClient()),
      _FakeCentreRepository([pickupCentre, externalCentre]),
    );
    booking.addAddressAndSelect(_address);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: booking,
        child: MaterialApp(home: Scaffold(body: BookingCentreStep(onNext: () {}, onBack: () {}))),
      ),
    );
    await tester.pumpAndSettle();

    // Default tab is Pickup Available -- the discovery tab's own fetch
    // must not have fired yet.
    expect(booking.nearbyCentres, isEmpty);

    await tester.tap(find.byKey(const Key('booking-centre-tab-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('all-centre-card-1')), findsOneWidget);
    expect(find.byKey(const Key('all-centre-card-2')), findsOneWidget);
    expect(find.text('Does not support EcoXchange pickup'), findsOneWidget);
    expect(find.text('Pickup available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('all-centre-card-2')));
    await tester.pumpAndSettle();

    // Tapping the external card only navigated to its detail screen -- it
    // never became the booking's selected centre.
    expect(booking.selectedCentre, isNull);
    expect(booking.canProceedFromCentre, isFalse);
  });

  testWidgets('switching back to Pickup Available restores the real eligibility list untouched', (tester) async {
    final booking = PickupBookingProvider(
      CustomerPickupBookingRepository(ApiClient()),
      CustomerAddressRepository(ApiClient()),
      _FakeCentreRepository(const []),
    );
    booking.addAddressAndSelect(_address);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: booking,
        child: MaterialApp(home: Scaffold(body: BookingCentreStep(onNext: () {}, onBack: () {}))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('booking-centre-tab-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-centre-tab-pickup')));
    await tester.pumpAndSettle();

    expect(booking.centreTab, CentreTab.pickupAvailable);
  });
}
