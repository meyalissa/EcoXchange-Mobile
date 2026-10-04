import '../models/geo_point.dart';

/// EcoXchange Mobile — decodes Google's encoded polyline format
/// (https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
/// into a list of [GeoPoint]s.
///
/// A small local implementation rather than a new dependency — the
/// algorithm is ~20 lines of well-known integer/bit math with nothing
/// project-specific to configure. Never calls Google again: the encoded
/// string always comes from the server's own Google Routes API response
/// (see PickupTrackingRoute), this only turns that string into drawable
/// points.
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    lat += _decodeNextDelta(encoded, () => index, (v) => index = v);
    lng += _decodeNextDelta(encoded, () => index, (v) => index = v);
    points.add(GeoPoint(lat / 1e5, lng / 1e5));
  }

  return points;
}

/// Decodes one varint-encoded, zigzag-signed delta starting at `getIndex()`,
/// advancing the index via `setIndex` as it consumes characters.
int _decodeNextDelta(String encoded, int Function() getIndex, void Function(int) setIndex) {
  var index = getIndex();
  var result = 0;
  var shift = 0;
  int b;

  do {
    b = encoded.codeUnitAt(index++) - 63;
    result |= (b & 0x1f) << shift;
    shift += 5;
  } while (b >= 0x20);

  setIndex(index);

  return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
}
