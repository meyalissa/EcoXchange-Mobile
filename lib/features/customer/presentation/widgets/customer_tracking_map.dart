import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/maps/maps_key_gate.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/polyline_codec.dart';
import '../../data/models/pickup_detail.dart';

/// Builds the tracking map. Injectable so widget tests don't need the
/// native Google Maps platform view — mirrors RouteMapBuilder on the
/// Rider Route screen.
typedef TrackingMapBuilder = Widget Function(
  BuildContext context, {
  GeoPoint? pickupPoint,
  GeoPoint? riderPoint,
  PickupTrackingRoute? route,
});

Widget defaultTrackingMapBuilder(
  BuildContext context, {
  GeoPoint? pickupPoint,
  GeoPoint? riderPoint,
  PickupTrackingRoute? route,
}) =>
    CustomerTrackingMap(pickupPoint: pickupPoint, riderPoint: riderPoint, route: route);

/// EcoXchange Mobile — Customer live rider-tracking map (Phase 1-3).
///
/// Shows the pickup location, the rider's latest real position (if any),
/// and the real road route between them (if the server computed one) --
/// never invented markers or a fabricated straight line. Reuses the exact
/// same `assets/map_markers/*.png` files and Maps-key gating as the Rider
/// Route screen (see core/maps/maps_key_gate.dart) -- no duplicate marker
/// assets, no second native-map-key check.
class CustomerTrackingMap extends StatelessWidget {
  const CustomerTrackingMap({super.key, this.pickupPoint, this.riderPoint, this.route});

  final GeoPoint? pickupPoint;
  final GeoPoint? riderPoint;
  final PickupTrackingRoute? route;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isMapsApiKeyConfigured(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(color: AppColors.n100);
        if (!snapshot.data!) {
          return Container(
            key: const Key('tracking-map-not-configured'),
            color: AppColors.n100,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: const Text(
              'The in-app map is not configured on this build (no Google Maps key).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.n600, height: 1.4, fontSize: 12),
            ),
          );
        }

        return _GoogleTrackingMap(pickupPoint: pickupPoint, riderPoint: riderPoint, route: route);
      },
    );
  }
}

class _GoogleTrackingMap extends StatefulWidget {
  const _GoogleTrackingMap({this.pickupPoint, this.riderPoint, this.route});

  final GeoPoint? pickupPoint;
  final GeoPoint? riderPoint;
  final PickupTrackingRoute? route;

  @override
  State<_GoogleTrackingMap> createState() => _GoogleTrackingMapState();
}

class _GoogleTrackingMapState extends State<_GoogleTrackingMap> {
  static const _assetByMarkerId = {
    'rider': 'assets/map_markers/rider_motorcycle.png',
    'pickup': 'assets/map_markers/pickup_house.png',
  };
  static const _hues = {'rider': BitmapDescriptor.hueAzure, 'pickup': BitmapDescriptor.hueGreen};
  static const _iconSize = 44.0;

  /// Kuala Lumpur centre, zoomed out -- same neutral default the Rider
  /// Route map falls back to when there is genuinely nothing to show yet.
  /// Never used as, or mistaken for, a real position.
  static const _fallbackCamera = CameraPosition(target: LatLng(3.1390, 101.6869), zoom: 11);

  final Map<String, BitmapDescriptor> _customIcons = {};
  bool _iconsRequested = false;
  GoogleMapController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iconsRequested) return;
    _iconsRequested = true;
    final configuration = createLocalImageConfiguration(context);
    for (final entry in _assetByMarkerId.entries) {
      BitmapDescriptor.asset(configuration, entry.value, width: _iconSize, height: _iconSize)
          .then((icon) {
            if (!mounted) return;
            setState(() => _customIcons[entry.key] = icon);
          })
          .catchError((Object _) {
            // Asset missing/corrupt/failed to decode -- that marker just
            // keeps its default coloured pin (see _hues above).
          });
    }
  }

  @override
  void didUpdateWidget(covariant _GoogleTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupPoint != widget.pickupPoint ||
        oldWidget.riderPoint != widget.riderPoint ||
        oldWidget.route?.polyline != widget.route?.polyline) {
      _fitCamera();
    }
  }

  LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  Marker _marker(String id, GeoPoint point, String title) {
    final hasCustomIcon = _customIcons.containsKey(id);

    return Marker(
      markerId: MarkerId(id),
      position: _latLng(point),
      infoWindow: InfoWindow(title: title),
      icon: _customIcons[id] ?? BitmapDescriptor.defaultMarkerWithHue(_hues[id] ?? BitmapDescriptor.hueRed),
      anchor: hasCustomIcon ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
    );
  }

  Future<void> _fitCamera() async {
    final controller = _controller;
    if (controller == null) return;

    final points = <LatLng>[
      if (widget.riderPoint != null) _latLng(widget.riderPoint!),
      if (widget.pickupPoint != null) _latLng(widget.pickupPoint!),
    ];
    if (points.length < 2) return; // nothing to "fit" with 0 or 1 point -- initialCameraPosition already covers it

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickupPoint;
    final rider = widget.riderPoint;
    final focus = pickup ?? rider;

    final initialCamera = focus == null ? _fallbackCamera : CameraPosition(target: _latLng(focus), zoom: 14);

    final markers = <Marker>{
      if (rider != null) _marker('rider', rider, 'Your rider'),
      if (pickup != null) _marker('pickup', pickup, 'Pickup location'),
    };

    final polylines = <Polyline>{
      if (widget.route != null)
        Polyline(
          polylineId: const PolylineId('tracking-route'),
          points: [for (final p in decodePolyline(widget.route!.polyline)) LatLng(p.latitude, p.longitude)],
          color: AppColors.green600,
          width: 4,
        ),
    };

    return GoogleMap(
      initialCameraPosition: initialCamera,
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        _fitCamera();
      },
    );
  }
}
