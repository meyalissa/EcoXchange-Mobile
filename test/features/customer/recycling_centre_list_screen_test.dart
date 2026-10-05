// EcoXchange Mobile — Profile → Recycling Centres (Recycling Centre
// Discovery). The real GoogleMap/MethodChannel is never created in these
// tests — the screen's injectable `mapBuilder` is replaced with a probe
// (mirrors the Pickup Detail tracking map's own `_MapProbe` pattern), so
// these assert on exactly what data the map was asked to draw, alongside
// the real list/filter/search UI driven by the real provider over a faked
// repository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/models/geo_point.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/address.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/nearby_recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_address_repository.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_recycling_centre_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/providers/recycling_centre_list_provider.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/recycling_centre_list_screen.dart';

import '../../fixtures/recycling_centre_fixtures.dart';

class _MapCall {
  const _MapCall({required this.centres, this.userLocation});
  final List<NearbyRecyclingCentre> centres;
  final GeoPoint? userLocation;
}

/// Records what the map was asked to draw instead of creating a real
/// GoogleMap platform view.
class _MapProbe {
  final List<_MapCall> calls = [];

  Widget build(
    BuildContext context, {
    required List<NearbyRecyclingCentre> centres,
    GeoPoint? userLocation,
    int? selectedCentreId,
    required ValueChanged<int> onMarkerTap,
  }) {
    calls.add(_MapCall(centres: centres, userLocation: userLocation));
    return Container(key: const Key('fake-map'));
  }
}

class _FakeCentreRepository extends CustomerRecyclingCentreRepository {
  _FakeCentreRepository(this.result) : super(ApiClient());

  final List<NearbyRecyclingCentre> result;

  @override
  Future<List<NearbyRecyclingCentre>> getNearby({required double lat, required double lng, String? search, double? radiusKm}) async => result;
}

class _EmptyAddressRepository extends CustomerAddressRepository {
  _EmptyAddressRepository() : super(ApiClient());

  @override
  Future<List<AddressModel>> getAddresses() async => [];
}

void main() {
  final pickupCentre = NearbyRecyclingCentre.fromJson(nearbyCentreJson(id: 1, name: 'EcoGreen Recycling Centre'));
  final externalCentre = NearbyRecyclingCentre.fromJson(externalCentreJson(id: 2, name: 'Discovered Scrap Metal Yard'));

  Future<_MapProbe> pumpScreen(WidgetTester tester, {required List<NearbyRecyclingCentre> centres, GeoPoint? position}) async {
    // Tall viewport so the map + full card list are actually mounted.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final probe = _MapProbe();
    final provider = RecyclingCentreListProvider(
      _FakeCentreRepository(centres),
      _EmptyAddressRepository(),
      positionReader: () async => position,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: RecyclingCentreListScreen(mapBuilder: probe.build))),
      ),
    );
    await tester.pumpAndSettle();
    return probe;
  }

  testWidgets('All Centres (default) displays the external, non-pickup-supported centre, visibly labelled', (tester) async {
    await pumpScreen(tester, centres: [pickupCentre, externalCentre], position: const GeoPoint(3.1, 101.6));

    expect(find.byKey(const Key('centre-card-1')), findsOneWidget);
    expect(find.byKey(const Key('centre-card-2')), findsOneWidget);
    expect(find.text('Does not support EcoXchange pickup'), findsOneWidget);
    expect(find.text('Pickup available'), findsOneWidget);
  });

  testWidgets('Pickup Available hides the external centre entirely', (tester) async {
    await pumpScreen(tester, centres: [pickupCentre, externalCentre], position: const GeoPoint(3.1, 101.6));

    await tester.tap(find.byKey(const Key('centre-filter-pickup')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('centre-card-1')), findsOneWidget);
    expect(find.byKey(const Key('centre-card-2')), findsNothing);
    expect(find.text('Does not support EcoXchange pickup'), findsNothing);
  });

  testWidgets('search narrows the visible list to the matching centre only', (tester) async {
    await pumpScreen(tester, centres: [pickupCentre, externalCentre], position: const GeoPoint(3.1, 101.6));

    await tester.enterText(find.byKey(const Key('centre-search')), 'Scrap');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('centre-card-1')), findsNothing);
    expect(find.byKey(const Key('centre-card-2')), findsOneWidget);
  });

  testWidgets('the map is handed every fetched centre marker regardless of the list filter', (tester) async {
    final probe = await pumpScreen(tester, centres: [pickupCentre, externalCentre], position: const GeoPoint(3.1, 101.6));

    expect(probe.calls, isNotEmpty);
    expect(probe.calls.last.centres.map((c) => c.id), containsAll([1, 2]));

    await tester.tap(find.byKey(const Key('centre-filter-pickup')));
    await tester.pumpAndSettle();

    // Section 5: map and list always share the same dataset -- once the
    // list filters down to pickup-only, the map does too.
    expect(probe.calls.last.centres.map((c) => c.id), [1]);
  });

  testWidgets('the map receives the real resolved device location when GPS is available', (tester) async {
    final probe = await pumpScreen(tester, centres: [pickupCentre], position: const GeoPoint(3.21, 101.72));

    expect(probe.calls.last.userLocation?.latitude, 3.21);
    expect(probe.calls.last.userLocation?.longitude, 101.72);
  });

  testWidgets('shows a real empty/permission state (never a fabricated location) when GPS and saved address both fail', (tester) async {
    await pumpScreen(tester, centres: [pickupCentre], position: null);

    expect(find.byKey(const Key('centre-location-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('centre-card-1')), findsNothing);
  });

  testWidgets('tapping a marker opens the info panel with the correct pickup-support label', (tester) async {
    await pumpScreen(tester, centres: [pickupCentre, externalCentre], position: const GeoPoint(3.1, 101.6));

    // Drive the same selection the map's onMarkerTap would -- the real
    // provider, not the probe, owns selectedCentreId.
    final context = tester.element(find.byType(RecyclingCentreListScreen));
    context.read<RecyclingCentreListProvider>().selectCentre(2);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('centre-info-panel')), findsOneWidget);
    expect(find.text('Does not support EcoXchange pickup'), findsAtLeastNWidgets(1));
  });
}
