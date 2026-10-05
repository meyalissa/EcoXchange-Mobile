import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/maps/maps_key_gate.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/polyline_codec.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../customer/data/models/pickup_detail.dart' show PickupTrackingRoute;
import '../../data/models/rider_pickup_action.dart';
import '../../data/models/rider_pickup_detail.dart';
import '../../data/repositories/rider_pickup_repository.dart';
import '../providers/rider_pickup_detail_provider.dart';
import '../widgets/rider_action_runner.dart';
import '../widgets/rider_status_chip.dart';
import 'rider_pickup_detail_screen.dart';

/// One map pin, built only from coordinates Laravel actually stored.
class RouteMarkerSpec {
  const RouteMarkerSpec({required this.id, required this.title, required this.point});

  final String id;
  final String title;
  final GeoPoint point;
}

/// The pickup's coordinates: `locations.pickup`, else the address's own
/// latitude/longitude. Null when neither is stored.
GeoPoint? pickupPointOf(RiderPickupDetail detail) {
  final fromLocations = detail.locations.pickup;
  if (fromLocations != null) return fromLocations;
  final lat = detail.address?.latitude;
  final lng = detail.address?.longitude;
  return lat == null || lng == null ? null : GeoPoint(lat, lng);
}

/// Markers for the route map: rider (last stored position), pickup and the
/// recycling centre — each only when its coordinates exist. Never invents a
/// position.
List<RouteMarkerSpec> buildRouteMarkers(RiderPickupDetail detail) {
  final pickup = pickupPointOf(detail);
  return [
    if (detail.locations.rider != null) RouteMarkerSpec(id: 'rider', title: 'You', point: detail.locations.rider!),
    if (pickup != null) RouteMarkerSpec(id: 'pickup', title: detail.customerName ?? detail.reference, point: pickup),
    if (detail.locations.recyclingCentre != null)
      RouteMarkerSpec(id: 'centre', title: detail.centre?.name ?? 'Recycling centre', point: detail.locations.recyclingCentre!),
  ];
}

/// Google Maps turn-by-turn link to [destination] (the Directions REST API
/// isn't usable with the project's referrer-restricted key, so routing and
/// ETA are delegated to the Google Maps app).
Uri directionsUri(GeoPoint destination) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
    );

/// Builds the map for [markers] and, when the server has computed one, the
/// road route to follow. Injectable so widget tests don't need the native
/// Google Maps platform view.
typedef RouteMapBuilder = Widget Function(BuildContext context, List<RouteMarkerSpec> markers, PickupTrackingRoute? route);

Widget defaultRouteMapBuilder(BuildContext context, List<RouteMarkerSpec> markers, PickupTrackingRoute? route) =>
    _KeyCheckedMap(markers: markers, route: route);

class _KeyCheckedMap extends StatelessWidget {
  const _KeyCheckedMap({required this.markers, this.route});

  final List<RouteMarkerSpec> markers;
  final PickupTrackingRoute? route;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isMapsApiKeyConfigured(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(color: AppColors.n100);
        if (snapshot.data!) return _GoogleRouteMap(markers: markers, route: route);
        return Container(
          key: const Key('route-map-not-configured'),
          color: AppColors.n100,
          alignment: Alignment.center,
          padding: const EdgeInsets.fromLTRB(32, 120, 32, 280),
          child: const Text(
            'The in-app map is not configured on this build (no Google Maps key).\nUse Directions to navigate in Google Maps.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.n600, height: 1.4),
          ),
        );
      },
    );
  }
}

/// The route-wording for the single next action (03_rider_route design).
String routeActionLabel(RiderPickupAction action) => switch (action) {
      RiderPickupAction.accept => 'Accept Pickup',
      RiderPickupAction.start => "Start Pickup – I'm On The Way",
      RiderPickupAction.collect => 'I Have Arrived – Start Collecting',
      RiderPickupAction.complete => 'Complete Pickup',
    };

/// EcoXchange Mobile — Rider Route (03_rider_route design): a real Google
/// Map with the stored rider / pickup / centre coordinates, the pickup's
/// customer and address, a call button, "Directions" (opens Google Maps)
/// and the job's single next action through the shared rider action flow
/// (its own [RiderPickupDetailProvider] — server-confirmed, no optimistic
/// state). No distance or ETA is displayed: the backend computes none.
class RiderRouteScreen extends StatefulWidget {
  const RiderRouteScreen({
    super.key,
    required this.pickupId,
    this.showBack = false,
    this.mapBuilder = defaultRouteMapBuilder,
    this.onChanged,
  });

  /// The job to route to; null shows an empty state.
  final int? pickupId;
  final bool showBack;
  final RouteMapBuilder mapBuilder;

  /// Called after a confirmed action so the shell can refresh its lists.
  final VoidCallback? onChanged;

  @override
  State<RiderRouteScreen> createState() => _RiderRouteScreenState();
}

class _RiderRouteScreenState extends State<RiderRouteScreen> {
  RiderPickupDetailProvider? _provider;
  Timer? _pollTimer;

  /// Route-refresh cadence while this screen is open -- matches the
  /// customer tracking screen's own poll interval (PickupDetailScreen),
  /// deliberately separate from PickupTrackingService's server-side
  /// route-recompute TTL (30s): this just re-reads whatever the server
  /// currently has, it never forces a new Routes API call.
  static const _pollInterval = Duration(seconds: 8);

  /// Assignment statuses worth polling for -- a route only exists once the
  /// rider has accepted (see PickupController::routeFor's gating) and stops
  /// mattering once the job is done.
  static const _pollableAssignmentStatuses = {'accepted', 'en_route', 'collecting'};

  @override
  void initState() {
    super.initState();
    _createProvider();
  }

  @override
  void didUpdateWidget(RiderRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupId != widget.pickupId) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _provider?.dispose();
      _createProvider();
    }
  }

  void _createProvider() {
    final id = widget.pickupId;
    final provider = id == null ? null : RiderPickupDetailProvider(context.read<RiderPickupRepository>(), id);
    _provider = provider;
    provider?.addListener(_syncPolling);
    provider?.load();
  }

  /// Starts/stops the polling timer to match the just-loaded pickup's
  /// state. Idempotent, so it's safe to call on every provider change
  /// (initial load, a confirmed action, or a previous poll tick).
  void _syncPolling() {
    final status = _provider?.pickup?.assignment?.status;
    final shouldPoll = status != null && _pollableAssignmentStatuses.contains(status);

    if (shouldPoll) {
      _pollTimer ??= Timer.periodic(_pollInterval, (_) => _provider?.refreshSilently());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _provider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final Widget body;
    if (provider == null) {
      body = const _NoJob();
    } else {
      body = ChangeNotifierProvider.value(
        value: provider,
        child: Consumer<RiderPickupDetailProvider>(
          builder: (context, p, _) => AsyncStateView<RiderPickupDetail>(
            isLoading: p.isLoading && p.pickup == null,
            error: p.pickup == null ? p.loadError : null,
            data: p.pickup,
            onRetry: p.load,
            builder: (context, detail) => _RouteContent(
              detail: detail,
              provider: p,
              mapBuilder: widget.mapBuilder,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.n50,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (widget.showBack)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: Material(
                color: AppColors.n0,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: AppColors.n800),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoJob extends StatelessWidget {
  const _NoJob();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('route-no-job'),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 56, color: AppColors.n300),
            SizedBox(height: 12),
            Text(
              'No active job to route to.\nAccept a task to see it on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.n600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({required this.detail, required this.provider, required this.mapBuilder, required this.onChanged});

  final RiderPickupDetail detail;
  final RiderPickupDetailProvider provider;
  final RouteMapBuilder mapBuilder;
  final VoidCallback? onChanged;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text('Could not open that app on this device.')));
  }

  @override
  Widget build(BuildContext context) {
    final markers = buildRouteMarkers(detail);
    final destination = pickupPointOf(detail);
    final next = provider.nextAction;
    final weight = detail.actualWeightKg ?? detail.estimatedWeightKg;
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Always render the map, even with zero stored coordinates -- a
        // missing rider/pickup/centre coordinate must not hide the map
        // itself (_GoogleRouteMap falls back to a neutral default camera
        // when markers is empty). The "Directions" button already hides
        // itself when there's no destination to route to.
        Positioned.fill(child: mapBuilder(context, markers, detail.trackingRoute)),
        // Top: where to go (no distance/ETA — none is computed server-side).
        Positioned(
          top: topInset + 10,
          left: 64,
          right: 16,
          child: Container(
            key: const Key('route-top-card'),
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(gradient: AppColors.walletCardGradient, borderRadius: BorderRadius.circular(AppRadii.r20), boxShadow: AppShadows.sh2),
            child: Row(
              children: [
                const Icon(Icons.navigation_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Navigate to pickup', style: AppTheme.displayFont(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(
                        detail.address?.formatted ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (destination != null)
                  TextButton(
                    key: const Key('route-directions'),
                    onPressed: () => _launch(context, directionsUri(destination)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.green700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.rFull)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Directions', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
        // Bottom: the job and its single next action.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            key: const Key('route-bottom-card'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.n0,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.r24)),
              boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => RiderPickupDetailScreen(pickupId: detail.id)))
                      .then((_) => provider.load()),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.green50,
                        child: Text(
                          (detail.customerName?.isNotEmpty ?? false) ? detail.customerName![0].toUpperCase() : '?',
                          style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.green700),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail.customerName ?? '—', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.n800)),
                            Text(
                              detail.address?.formatted ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.n600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [detail.reference, if (weight != null) '~${weight.toStringAsFixed(1)} kg'].join(' · '),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green600),
                            ),
                          ],
                        ),
                      ),
                      if (detail.customerPhone != null)
                        Material(
                          color: AppColors.green50,
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const Key('route-call'),
                            tooltip: 'Call customer',
                            icon: const Icon(Icons.call, color: AppColors.green600),
                            onPressed: () => _launch(context, Uri(scheme: 'tel', path: detail.customerPhone)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: RiderStatusChip(status: detail.displayStatus)),
                if (provider.actionError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    riderActionErrorText(provider.actionError!),
                    key: const Key('route-action-error'),
                    style: const TextStyle(fontSize: 13, color: AppColors.red),
                  ),
                ],
                if (next != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      key: Key('route-action-${next.path}'),
                      onPressed: provider.isSubmitting
                          ? null
                          : () async {
                              if (await runRiderAction(context, provider, next)) onChanged?.call();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.rFull)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      icon: provider.isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(riderActionCopy(next).icon),
                      label: Text(routeActionLabel(next)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleRouteMap extends StatefulWidget {
  const _GoogleRouteMap({required this.markers, this.route});

  final List<RouteMarkerSpec> markers;
  final PickupTrackingRoute? route;

  @override
  State<_GoogleRouteMap> createState() => _GoogleRouteMapState();
}

class _GoogleRouteMapState extends State<_GoogleRouteMap> {
  // Fallback colours -- used for any marker whose custom icon hasn't
  // finished loading yet, or failed to load at all. The map must never be
  // blocked on, or break because of, a custom-icon asset.
  static const _hues = {
    'rider': BitmapDescriptor.hueAzure,
    'pickup': BitmapDescriptor.hueGreen,
    'centre': BitmapDescriptor.hueOrange,
  };

  static const _assetByMarkerId = {
    'rider': 'assets/map_markers/rider_motorcycle.png',
    'pickup': 'assets/map_markers/pickup_house.png',
    'centre': 'assets/map_markers/recycling_centre.png',
  };

  /// Logical on-screen size for a custom marker icon -- large enough to
  /// read at a glance, small enough not to swamp the map.
  static const _iconSize = 44.0;

  /// Camera used only when this pickup has no stored coordinates at all
  /// (no marker is ever placed here) -- Kuala Lumpur city centre, a
  /// neutral, zoomed-out default so the map still renders instead of
  /// disappearing. Never shown as, or mistaken for, a real pickup location.
  static const _fallbackCamera = CameraPosition(target: LatLng(3.1390, 101.6869), zoom: 11);

  /// Custom icon per marker id, filled in as each asset finishes decoding.
  /// A marker whose id has no entry here yet (still loading, or its asset
  /// failed) falls back to the existing coloured pin -- the map is never
  /// held up waiting for these, and one icon failing never affects another.
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
            // Asset missing/corrupt/failed to decode: that one marker just
            // keeps its default coloured pin (see _hues above).
          });
    }
  }

  @override
  void didUpdateWidget(covariant _GoogleRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The rider's position (and so the route) can change while this screen
    // stays open (see the Route screen's live-location poll) -- re-fit so
    // a moved rider/updated route stays in view, the same way the camera
    // is fit on first load.
    if (oldWidget.markers != widget.markers || oldWidget.route?.polyline != widget.route?.polyline) {
      _fit(_controller);
    }
  }

  LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  Future<void> _fit(GoogleMapController? controller) async {
    if (controller == null || widget.markers.length < 2) return;
    final lats = widget.markers.map((m) => m.point.latitude);
    final lngs = widget.markers.map((m) => m.point.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
    // Give the platform view a frame to lay out before fitting.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    final markers = widget.markers;
    final route = widget.route;
    final initialCamera = markers.isEmpty
        ? _fallbackCamera
        : CameraPosition(
            target: _latLng(markers.firstWhere((m) => m.id == 'pickup', orElse: () => markers.first).point),
            zoom: 14,
          );
    return GoogleMap(
      initialCameraPosition: initialCamera,
      markers: {
        for (final m in markers)
          Marker(
            markerId: MarkerId(m.id),
            position: _latLng(m.point),
            infoWindow: InfoWindow(title: m.title),
            icon: _customIcons[m.id] ?? BitmapDescriptor.defaultMarkerWithHue(_hues[m.id] ?? BitmapDescriptor.hueRed),
            // The custom icons are round badges centred on the coordinate;
            // the default fallback pin keeps its usual bottom-tip anchor.
            anchor: _customIcons.containsKey(m.id) ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
          ),
      },
      polylines: {
        // The real road route from the rider's current position to the
        // pickup, server-computed via Google Routes API -- never a
        // straight line between the markers. Same rendering approach as
        // CustomerTrackingMap (see that widget).
        if (route != null)
          Polyline(
            polylineId: const PolylineId('rider-route'),
            points: [for (final p in decodePolyline(route.polyline)) LatLng(p.latitude, p.longitude)],
            color: AppColors.green600,
            width: 4,
          ),
      },
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 80, bottom: 260),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        _fit(controller);
      },
    );
  }
}
