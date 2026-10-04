// EcoXchange Mobile — Customer live rider-tracking (Phase 1-3): the
// Pickup Detail screen's new "RIDER IS ON THE WAY" section. The real
// GoogleMap/MethodChannel is never created in these tests — the screen's
// injectable `trackingMapBuilder` is replaced with a probe (mirrors the
// Rider Route screen's RouteMapBuilder/_MapProbe pattern), so these
// assert on exactly what data the map was asked to draw.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/core/models/geo_point.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_detail.dart';
import 'package:ecoxchange_mobile/features/customer/data/repositories/customer_pickup_repository.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/screens/pickup_detail_screen.dart';

import '../fixtures/customer_pickup_fixtures.dart';

class _TrackingCall {
  const _TrackingCall({this.pickupPoint, this.riderPoint, this.route});
  final GeoPoint? pickupPoint;
  final GeoPoint? riderPoint;
  final PickupTrackingRoute? route;
}

/// Records what the map was asked to draw, instead of creating a real one.
class _MapProbe {
  final List<_TrackingCall> calls = [];

  Widget build(BuildContext context, {GeoPoint? pickupPoint, GeoPoint? riderPoint, PickupTrackingRoute? route}) {
    calls.add(_TrackingCall(pickupPoint: pickupPoint, riderPoint: riderPoint, route: route));
    return Container(key: const Key('fake-map'));
  }
}

/// The "server": a queue of JSON responses consumed in order (the last one
/// repeats once exhausted), so a test can simulate how the pickup detail
/// changes across successive polls. Optionally throws once.
class _Server extends CustomerPickupRepository {
  _Server(this._responses) : super(ApiClient());

  final List<Map<String, dynamic>> _responses;
  final List<String> requests = [];
  ApiException? throwOnNextCall;
  int _index = 0;

  @override
  Future<PickupDetail> getPickupDetail(int id) async {
    requests.add('GET $id');

    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }

    final json = _responses[_index < _responses.length ? _index : _responses.length - 1];
    _index++;
    return PickupDetail.fromJson(json);
  }
}

void main() {
  Future<_MapProbe> pumpScreen(WidgetTester tester, _Server server) async {
    // A tall physical size so the whole ListView (including sections below
    // the tracking map) is actually mounted -- ListView's default viewport
    // + cache extent otherwise leaves later sections unbuilt, which is a
    // test-harness concern, not a real rendering issue. Mirrors
    // rider_navigation_test.dart's own pumpShell helper.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final probe = _MapProbe();
    await tester.pumpWidget(Provider<CustomerPickupRepository>.value(
      value: server,
      child: MaterialApp(home: PickupDetailScreen(pickupId: 36, trackingMapBuilder: probe.build)),
    ));
    await tester.pumpAndSettle();
    return probe;
  }

  // 1 / 2 / 3 / 4 / 5. Rider location, pickup marker, route polyline,
  // distance and ETA are all displayed when a full, location-visible
  // assignment with a route exists.
  testWidgets('rider position, pickup marker, route, distance and ETA all reach the map and the UI', (tester) async {
    final server = _Server([
      customerPickupDetailJson(
        assignedRider: assignedRiderJson(assignmentStatus: 'en_route'),
        trackingRoute: trackingRouteJson(distanceMeters: 2600, durationSeconds: 420),
      ),
    ]);

    final probe = await pumpScreen(tester, server);

    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    final call = probe.calls.last;
    expect(call.riderPoint?.latitude, 3.12);
    expect(call.riderPoint?.longitude, 101.62);
    expect(call.pickupPoint?.latitude, 3.0428);
    expect(call.route?.distanceMeters, 2600);
    expect(call.route?.durationSeconds, 420);

    expect(find.text('2.6 km away'), findsOneWidget);
    expect(find.text('~7 min'), findsOneWidget);
  });

  // 6. Missing rider location (assigned but not yet accepted) — map still
  // shows (pickup marker only), "Waiting for rider location" shown,
  // nothing crashes.
  testWidgets('no rider location yet shows the pickup marker and a waiting message, not a crash', (tester) async {
    final server = _Server([
      customerPickupDetailJson(
        assignedRider: assignedRiderJson(assignmentStatus: 'assigned', currentLatitude: null, currentLongitude: null),
      ),
    ]);

    final probe = await pumpScreen(tester, server);

    expect(find.byKey(const Key('tracking-waiting')), findsOneWidget);
    expect(probe.calls.last.riderPoint, isNull);
    expect(probe.calls.last.pickupPoint, isNotNull);
  });

  // 7. Rider location available but no route — both markers show, no
  // distance/ETA, an honest message instead.
  testWidgets('rider location without a route shows both markers but no distance/ETA', (tester) async {
    final server = _Server([
      customerPickupDetailJson(assignedRider: assignedRiderJson(assignmentStatus: 'en_route')),
    ]);

    final probe = await pumpScreen(tester, server);

    expect(find.byKey(const Key('tracking-no-route')), findsOneWidget);
    expect(probe.calls.last.riderPoint, isNotNull);
    expect(probe.calls.last.pickupPoint, isNotNull);
    expect(probe.calls.last.route, isNull);
    expect(find.byKey(const Key('tracking-distance')), findsNothing);
  });

  // 9. Stale rider location is labelled honestly, not claimed as live.
  testWidgets('a rider location from 5 minutes ago shows a stale freshness note', (tester) async {
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
    final server = _Server([
      customerPickupDetailJson(
        assignedRider: assignedRiderJson(assignmentStatus: 'en_route', locationUpdatedAt: fiveMinutesAgo),
        trackingRoute: trackingRouteJson(),
      ),
    ]);

    await pumpScreen(tester, server);

    expect(find.text('Last updated 5 min ago'), findsOneWidget);
  });

  // 12. A partial/invalid coordinate pair (latitude without longitude)
  // never crashes -- it's just treated as "no position".
  testWidgets('a mismatched lat/lng pair does not crash and is treated as no rider position', (tester) async {
    final server = _Server([
      customerPickupDetailJson(
        assignedRider: assignedRiderJson(assignmentStatus: 'en_route', currentLatitude: 3.12, currentLongitude: null),
      ),
    ]);

    await pumpScreen(tester, server);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('tracking-waiting')), findsOneWidget);
  });

  // No rider assigned at all -- no tracking section, no polling, existing
  // "No rider assigned yet." copy (RIDER INFORMATION section) is untouched.
  testWidgets('no rider assigned shows no tracking section and never polls', (tester) async {
    final server = _Server([customerPickupDetailJson(assignedRider: null)]);

    await pumpScreen(tester, server);

    expect(find.text('No rider assigned yet.'), findsOneWidget);
    expect(find.byKey(const Key('fake-map')), findsNothing);
    expect(find.text('RIDER IS ON THE WAY'), findsNothing);

    await tester.pump(const Duration(seconds: 20));
    expect(server.requests.length, 1); // no poll ever fired
  });

  // 8. A failed poll keeps the last known state rather than clearing the
  // screen or crashing.
  testWidgets('a failed poll keeps showing the last known rider position', (tester) async {
    final server = _Server([
      customerPickupDetailJson(
        assignedRider: assignedRiderJson(assignmentStatus: 'en_route'),
        trackingRoute: trackingRouteJson(),
      ),
    ]);

    final probe = await pumpScreen(tester, server);
    expect(probe.calls.last.riderPoint, isNotNull);

    server.throwOnNextCall = const NetworkException('offline');
    await tester.pump(const Duration(seconds: 9)); // fires the first poll tick
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('2.6 km away'), findsOneWidget); // unchanged from before the failed poll
  });

  // 10. A pickup whose assignment becomes 'completed' stops polling.
  testWidgets('polling stops once the assignment is completed', (tester) async {
    final server = _Server([
      customerPickupDetailJson(assignedRider: assignedRiderJson(assignmentStatus: 'en_route'), trackingRoute: trackingRouteJson()),
      customerPickupDetailJson(status: 'completed', assignedRider: assignedRiderJson(assignmentStatus: 'completed', currentLatitude: null, currentLongitude: null)),
    ]);

    await pumpScreen(tester, server);
    expect(server.requests.length, 1);

    await tester.pump(const Duration(seconds: 9)); // first poll -> now 'completed'
    await tester.pumpAndSettle();
    expect(server.requests.length, 2);

    await tester.pump(const Duration(seconds: 20)); // would be 2+ more ticks if still polling
    await tester.pumpAndSettle();
    expect(server.requests.length, 2); // unchanged -- polling stopped
  });

  // 11. Disposing the screen stops the polling timer.
  testWidgets('leaving the screen stops polling', (tester) async {
    final server = _Server([
      customerPickupDetailJson(assignedRider: assignedRiderJson(assignmentStatus: 'en_route'), trackingRoute: trackingRouteJson()),
    ]);

    await pumpScreen(tester, server);
    expect(server.requests.length, 1);

    // Replace the whole tree -- disposes PickupDetailScreen and its timer.
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pump(const Duration(seconds: 20));
    expect(server.requests.length, 1); // no further polls after disposal
  });

  // 13. Existing pickup detail content (unrelated to tracking) is untouched.
  testWidgets('existing pickup detail sections remain intact', (tester) async {
    final server = _Server([
      customerPickupDetailJson(assignedRider: assignedRiderJson(assignmentStatus: 'en_route'), trackingRoute: trackingRouteJson()),
    ]);

    await pumpScreen(tester, server);

    // "PK-36" legitimately appears twice (app bar title + header card) --
    // both pre-existing, unrelated to this feature.
    expect(find.text('PK-36'), findsWidgets);
    expect(find.text('PICKUP INFO'), findsOneWidget);
    expect(find.text('PICKUP ADDRESS'), findsOneWidget);
    expect(find.text('RIDER INFORMATION'), findsOneWidget);
    expect(find.text('Azmi bin Noor'), findsOneWidget);
    expect(find.text('STATUS TIMELINE'), findsOneWidget);
  });
}
