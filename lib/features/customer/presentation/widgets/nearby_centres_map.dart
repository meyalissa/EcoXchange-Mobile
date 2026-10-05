import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/maps/maps_key_gate.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/nearby_recycling_centre.dart';

/// Builds the nearby-centres map. Injectable so widget tests don't need
/// the native Google Maps platform view — mirrors CustomerTrackingMap/
/// RouteMapBuilder's own pattern.
typedef NearbyCentresMapBuilder = Widget Function(
  BuildContext context, {
  required List<NearbyRecyclingCentre> centres,
  GeoPoint? userLocation,
  int? selectedCentreId,
  required ValueChanged<int> onMarkerTap,
});

Widget defaultNearbyCentresMapBuilder(
  BuildContext context, {
  required List<NearbyRecyclingCentre> centres,
  GeoPoint? userLocation,
  int? selectedCentreId,
  required ValueChanged<int> onMarkerTap,
}) =>
    NearbyCentresMap(centres: centres, userLocation: userLocation, selectedCentreId: selectedCentreId, onMarkerTap: onMarkerTap);

/// EcoXchange Mobile — Profile → Recycling Centres map: every real nearby
/// centre as a marker (green = supports an EcoXchange pickup, neutral =
/// discoverable only — see NearbyRecyclingCentre.pickupSupported, never
/// inferred from `source`), plus the device's own live location via the
/// Maps SDK's native "my location" layer. No route/polyline — this is
/// discovery, not navigation (that's the Rider Route screen's job).
///
/// Coordinates always come from [centres] (ultimately
/// `recycling_center_profiles.latitude/longitude`) — nothing here is
/// hardcoded.
class NearbyCentresMap extends StatelessWidget {
  const NearbyCentresMap({super.key, required this.centres, this.userLocation, this.selectedCentreId, required this.onMarkerTap});

  final List<NearbyRecyclingCentre> centres;
  final GeoPoint? userLocation;
  final int? selectedCentreId;
  final ValueChanged<int> onMarkerTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isMapsApiKeyConfigured(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(color: AppColors.n100);
        if (!snapshot.data!) {
          return Container(
            key: const Key('nearby-map-not-configured'),
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

        return _GoogleNearbyCentresMap(centres: centres, userLocation: userLocation, selectedCentreId: selectedCentreId, onMarkerTap: onMarkerTap);
      },
    );
  }
}

class _GoogleNearbyCentresMap extends StatefulWidget {
  const _GoogleNearbyCentresMap({required this.centres, this.userLocation, this.selectedCentreId, required this.onMarkerTap});

  final List<NearbyRecyclingCentre> centres;
  final GeoPoint? userLocation;
  final int? selectedCentreId;
  final ValueChanged<int> onMarkerTap;

  @override
  State<_GoogleNearbyCentresMap> createState() => _GoogleNearbyCentresMapState();
}

class _GoogleNearbyCentresMapState extends State<_GoogleNearbyCentresMap> {
  static const _iconSize = 40.0;

  /// Kuala Lumpur centre, zoomed out -- same neutral default every other
  /// map in this app falls back to when there is genuinely nothing to
  /// show yet. Never mistaken for a real position.
  static const _fallbackCamera = CameraPosition(target: LatLng(3.1390, 101.6869), zoom: 11);

  BitmapDescriptor? _pickupIcon;
  bool _iconRequested = false;
  GoogleMapController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iconRequested) return;
    _iconRequested = true;
    final configuration = createLocalImageConfiguration(context);
    BitmapDescriptor.asset(configuration, 'assets/map_markers/recycling_centre.png', width: _iconSize, height: _iconSize)
        .then((icon) {
          if (!mounted) return;
          setState(() => _pickupIcon = icon);
        })
        .catchError((Object _) {
          // Asset missing/corrupt/failed to decode -- pickup-supported
          // markers just keep the default green pin below.
        });
  }

  @override
  void didUpdateWidget(covariant _GoogleNearbyCentresMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.centres != widget.centres || oldWidget.userLocation != widget.userLocation) {
      _fitBounds();
    } else if (oldWidget.selectedCentreId != widget.selectedCentreId && widget.selectedCentreId != null) {
      _focusSelected();
    }
  }

  LatLng _latLng(double lat, double lng) => LatLng(lat, lng);

  Future<void> _fitBounds() async {
    final controller = _controller;
    if (controller == null) return;

    final points = <LatLng>[
      if (widget.userLocation != null) _latLng(widget.userLocation!.latitude, widget.userLocation!.longitude),
      for (final c in widget.centres)
        if (c.latitude != null && c.longitude != null) _latLng(c.latitude!, c.longitude!),
    ];
    if (points.length < 2) return;

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _focusSelected() async {
    final controller = _controller;
    final id = widget.selectedCentreId;
    if (controller == null || id == null) return;

    final matches = widget.centres.where((c) => c.id == id);
    if (matches.isEmpty) return;
    final centre = matches.first;
    if (centre.latitude == null || centre.longitude == null) return;

    await controller.animateCamera(CameraUpdate.newLatLng(_latLng(centre.latitude!, centre.longitude!)));
  }

  @override
  Widget build(BuildContext context) {
    final withCoords = widget.centres.where((c) => c.latitude != null && c.longitude != null).toList();
    final focus = widget.userLocation ?? (withCoords.isNotEmpty ? GeoPoint(withCoords.first.latitude!, withCoords.first.longitude!) : null);
    final initialCamera = focus == null ? _fallbackCamera : CameraPosition(target: _latLng(focus.latitude, focus.longitude), zoom: 13);

    return GoogleMap(
      initialCameraPosition: initialCamera,
      markers: {
        for (final c in withCoords)
          Marker(
            markerId: MarkerId('centre-${c.id}'),
            position: _latLng(c.latitude!, c.longitude!),
            infoWindow: InfoWindow(title: c.name, snippet: c.pickupSupported ? 'Supports EcoXchange pickup' : 'Does not support EcoXchange pickup'),
            // Pickup-supported centres use the app's own recycling-centre
            // icon (brand-consistent, matches the Rider Route map).
            // External/non-pickup centres fall back to a distinctly
            // different-coloured default pin -- the Maps SDK has no true
            // neutral grey hue, so azure (a cool, muted tone next to the
            // vibrant pickup-supported green) is the closest honest
            // approximation of "discoverable only, not a partner".
            icon: c.pickupSupported
                ? (_pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen))
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            anchor: c.pickupSupported && _pickupIcon != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
            onTap: () => widget.onMarkerTap(c.id),
          ),
      },
      myLocationEnabled: widget.userLocation != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        _fitBounds();
      },
    );
  }
}
