// EcoXchange Mobile — map pinch-zoom/drag gesture fix (Profile Photo Sync &
// Map Gestures task, Task 2), NearbyCentresMap half.
//
// Root cause: `GoogleMap` left `gestureRecognizers` at its default empty
// set, so on Recycling Centres -- where the map is nested inside the
// screen's page-level `ListView` -- the ListView's own vertical-drag
// recognizer was winning the gesture arena instead of the map. The fix
// adds an eager `OneSequenceGestureRecognizer` factory to this widget.
//
// Kept in its own file (not combined with the CustomerTrackingMap test):
// pumping two separate real `GoogleMap` platform views across two
// `testWidgets` in the same file was found to make the second one never
// finish resolving its "is the key configured" FutureBuilder, even though
// each works correctly in total isolation -- a `flutter_test`/platform-view
// interaction, not anything in this app's own code. Each `flutter test`
// target file already gets its own process, so one `GoogleMap` test per
// file sidesteps that cleanly.
//
// This pumps the REAL `GoogleMap` widget (by mocking the
// `ecoxchange/config` "hasMapsApiKey" channel to `true`) to inspect its
// actual `gestureRecognizers` configuration and confirm marker data/tap
// wiring survived the change. It does not, and cannot, prove real
// multi-touch pinch/drag behaviour -- that requires manual verification on
// an emulator or physical device.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:ecoxchange_mobile/core/models/geo_point.dart';
import 'package:ecoxchange_mobile/features/customer/data/models/nearby_recycling_centre.dart';
import 'package:ecoxchange_mobile/features/customer/presentation/widgets/nearby_centres_map.dart';

void main() {
  const config = MethodChannel('ecoxchange/config');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(config, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(config, null);
  });

  testWidgets('claims its gesture arena eagerly instead of leaving the page ListView to win it', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
      home: NearbyCentresMap(
        centres: const [
          NearbyRecyclingCentre(
            id: 7,
            name: 'EcoRecycle Shah Alam',
            address: null,
            city: null,
            state: null,
            postcode: null,
            latitude: 3.05,
            longitude: 101.52,
            phone: null,
            website: null,
            rating: null,
            businessStatus: null,
            googleMapsUrl: null,
            source: 'self_registered',
            pickupSupported: true,
            distanceKm: null,
          ),
        ],
        userLocation: const GeoPoint(3.05, 101.52),
        onMarkerTap: (id) => tapped = id,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.gestureRecognizers, isNotEmpty);
    expect(map.gestureRecognizers.single.type, OneSequenceGestureRecognizer);

    // The gesture fix didn't disturb marker-tap wiring: the same
    // onMarkerTap callback the screen passed in is still what fires.
    final marker = map.markers.firstWhere((m) => m.markerId == const MarkerId('centre-7'));
    marker.onTap!();
    expect(tapped, 7);
  });
}
