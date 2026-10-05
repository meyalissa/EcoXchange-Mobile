import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/utils/polyline_codec.dart';

void main() {
  group('decodePolyline', () {
    test('decodes a real Google-encoded polyline into the correct points', () {
      // The canonical example from Google's own polyline algorithm docs:
      // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 1e-5));
      expect(points[0].longitude, closeTo(-120.2, 1e-5));
      expect(points[1].latitude, closeTo(40.7, 1e-5));
      expect(points[1].longitude, closeTo(-120.95, 1e-5));
      expect(points[2].latitude, closeTo(43.252, 1e-5));
      expect(points[2].longitude, closeTo(-126.453, 1e-5));
    });

    test('an empty string (e.g. a degraded Routes API response) decodes to an empty list, never a crash', () {
      expect(decodePolyline(''), isEmpty);
    });
  });
}
