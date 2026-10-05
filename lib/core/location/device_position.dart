import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';

/// A device-position reader — the real implementation reads [Geolocator];
/// tests inject a fake so they never touch real GPS hardware or platform
/// channels. Returns null when a position genuinely isn't available
/// (permission denied, location services off, or any other failure) —
/// never a fabricated/placeholder coordinate.
typedef DevicePositionReader = Future<GeoPoint?> Function();

/// EcoXchange Mobile — reads the device's current GPS position, handling
/// the permission/service-enabled dance. Shared by any customer-side
/// feature that wants "use my current location" (first introduced for
/// Profile → Recycling Centres' nearby-centre discovery) — mirrors
/// `RiderLocationSender`'s own `_readDevicePosition()` exactly (same
/// package, same permission flow, same swallow-every-failure contract)
/// rather than inventing a second GPS-reading convention; kept as its own
/// top-level function here instead of importing the rider feature's
/// private one, since that one is `_`-private to its file by design.
Future<GeoPoint?> readDevicePosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return GeoPoint(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}
