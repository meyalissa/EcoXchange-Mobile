// EcoXchange Mobile — PickupBookingScreen navigation (Part A/C of the
// unified AI scanning + pickup flow task).
//
// Verifies the actual screen-level transition the scan-first entry point
// relies on: when items/quantities are already confirmed by scanning
// (prefillQuantities + initialStep: 1), the booking screen opens directly
// on the next step (Pickup Address) instead of re-asking the user to
// select items — and that tapping Back from there returns to Select
// Items with the scanned quantity still shown, never silently discarded.
// Real widgets pumped against faked repositories, no HTTP/Dio call.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/category.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/item.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_booking.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_catalogue_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_booking_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/pickup_booking_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/booking/pickup_booking_screen.dart';

const _plasticBottle = ItemModel(
  id: 1, name: 'Plastic Bottle', category: 'Plastic', image: null, description: null,
  preliminaryBasePricePerKg: 0.40, priceNote: null, estimatedUnitWeightKg: 0.05,
  preparationSteps: null, recyclingTips: null, environmentalImpact: null,
);

class _CatalogueRepo extends CustomerCatalogueRepository {
  _CatalogueRepo() : super(ApiClient());
  @override
  Future<List<CategoryModel>> getCategories() async => const [];
  @override
  Future<List<ItemModel>> getItems({String? category}) async => [_plasticBottle];
}

class _AddressRepo extends CustomerAddressRepository {
  _AddressRepo() : super(ApiClient());
  @override
  Future<List<AddressModel>> getAddresses() async => const [];
}

class _CentreRepo extends CustomerRecyclingCentreRepository {
  _CentreRepo() : super(ApiClient());
}

class _BookingRepo extends CustomerPickupBookingRepository {
  _BookingRepo() : super(ApiClient());
  @override
  Future<PickupEstimate> estimate(Map<int, int> quantities) async =>
      const PickupEstimate(items: [], totalWeightKg: 0, preliminaryReward: 0, unavailableItemIds: [], note: null);
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      Provider<CustomerCatalogueRepository>.value(value: _CatalogueRepo()),
      Provider<CustomerAddressRepository>.value(value: _AddressRepo()),
      Provider<CustomerRecyclingCentreRepository>.value(value: _CentreRepo()),
      Provider<CustomerPickupBookingRepository>.value(value: _BookingRepo()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('scan-first hand-off (initialStep: 1) opens on Pickup Address, not Select Items', (tester) async {
    await tester.pumpWidget(_wrap(PickupBookingScreen(
      prefillQuantities: [const PrefillItemQuantity(item: _plasticBottle, quantity: 2)],
      prefillScanLogId: 77,
      initialStep: 1,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Pickup Address'), findsOneWidget);
    expect(find.text('Select Items'), findsNothing);
  });

  testWidgets('Back from the scan-first hand-off returns to Select Items with the scanned quantity intact', (tester) async {
    await tester.pumpWidget(_wrap(PickupBookingScreen(
      prefillQuantities: [const PrefillItemQuantity(item: _plasticBottle, quantity: 2)],
      prefillScanLogId: 77,
      initialStep: 1,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Select Items'), findsOneWidget);
    expect(find.text('Plastic Bottle'), findsOneWidget);
    expect(find.text('Continue with 2 items'), findsOneWidget, reason: 'the scanned quantity survived Back, never silently reset');
  });

  testWidgets('manual booking (no prefill) still opens on Select Items as before', (tester) async {
    await tester.pumpWidget(_wrap(const PickupBookingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Select Items'), findsOneWidget);
  });
}
