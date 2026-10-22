// EcoXchange Mobile — map pinch-zoom/drag gesture fix (Profile Photo Sync &
// Map Gestures task, Task 2), CustomerTrackingMap half.
//
// Root cause: `GoogleMap` left `gestureRecognizers` at its default empty
// set, so on Pickup Details -- where this map is nested inside
// `_RiderLocationSection`, itself inside the screen's page-level `ListView`
// -- the ListView's own vertical-drag recognizer was winning the gesture
// arena instead of the map. The fix adds an eager
// `OneSequenceGestureRecognizer` factory to this widget.
//
// Kept in its own file -- see nearby_centres_map_gesture_test.dart's
// docblock for why the two real-`GoogleMap` tests aren't combined in one
// file.
//
// This pumps the REAL `GoogleMap` widget (by mocking the
// `ecoxchange/config` "hasMapsApiKey" channel to `true`) to inspect its
// actual `gestureRecognizers` configuration and confirm the rider/pickup
// markers and route polyline still render. It does not, and cannot, prove
// real multi-touch pinch/drag behaviour -- that requires manual
// verification on an emulator or physical device.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:ecoxchange_mobile/core/models/geo_point.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/pickup_detail.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/widgets/customer_tracking_map.dart';

void main() {
  const config = MethodChannel('ecoxchange/config');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(config, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(config, null);
  });

  testWidgets('claims its gesture arena eagerly, and keeps rendering the rider/pickup markers and route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CustomerTrackingMap(
        pickupPoint: const GeoPoint(3.10, 101.60),
        riderPoint: const GeoPoint(3.11, 101.61),
        route: const PickupTrackingRoute(distanceMeters: 1200, durationSeconds: 300, polyline: r'_p~iF~ps|U'),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.gestureRecognizers, isNotEmpty);
    expect(map.gestureRecognizers.single.type, OneSequenceGestureRecognizer);

    expect(map.markers.map((m) => m.markerId.value), containsAll(['rider', 'pickup']));
    expect(map.polylines, isNotEmpty);
  });
}
