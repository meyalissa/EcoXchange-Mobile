import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../data/repositories/rider_location_repository.dart';

/// A device-position reader — the real implementation reads [Geolocator];
/// tests inject a fake so they never touch real GPS hardware or platform
/// channels. Returns null when a position genuinely isn't available
/// (permission denied, location services off, or any other failure).
typedef PositionReader = Future<({double latitude, double longitude})?> Function();

Future<({double latitude, double longitude})?> _readDevicePosition() async {
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

    return (latitude: position.latitude, longitude: position.longitude);
  } catch (_) {
    return null;
  }
}

/// EcoXchange Mobile — periodically sends the rider's OWN foreground GPS
/// position to Laravel while [start]ed.
///
/// This class has no concept of "active assignment" itself -- the caller
/// (RiderHomeScreen) is responsible for calling [start] only while one
/// exists (mirroring RiderDashboardProvider's own activeTask, which
/// already means accepted/en_route/collecting) and [stop] the rest of the
/// time, including on app backgrounding. It never runs as a background
/// service: once the app is backgrounded, the caller stops it, and this
/// class makes no attempt to keep running without a foreground Activity.
///
/// Never crashes the rider app over a missing GPS fix, a denied
/// permission, or a failed request -- every failure here is swallowed and
/// simply retried on the next tick, exactly like a transient network blip
/// on any other screen's polling.
class RiderLocationSender {
  RiderLocationSender(
    this._repository, {
    this.interval = const Duration(seconds: 8),
    PositionReader? positionReader,
  }) : _readPosition = positionReader ?? _readDevicePosition;

  final RiderLocationRepository _repository;
  final Duration interval;
  final PositionReader _readPosition;

  Timer? _timer;
  bool _sending = false;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _tick());
    unawaited(_tick()); // send immediately rather than waiting a full interval first
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  Future<void> _tick() async {
    if (_sending) return; // never let two requests overlap if one is slow
    _sending = true;
    try {
      final position = await _readPosition();
      if (position == null) return;
      await _repository.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // Network/API failure -- skip this tick, the next one retries.
    } finally {
      _sending = false;
    }
  }
}
