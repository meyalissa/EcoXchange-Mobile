import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/nearby_recycling_centre.dart';
import '../../data/models/recycling_centre.dart';
import '../../data/repositories/customer_recycling_centre_repository.dart';

/// EcoXchange Mobile — Recycling Centre Detail (Phase 4C.2 §10, restyled
/// Phase 4C.3; extended for real Google Places discovery data). There's no
/// direct HTML reference for this screen (the design only ever shows
/// centres as picker cards, never a detail page), so this extends the
/// list card's visual language — the same icon box and colour treatment —
/// into a full layout. Renders whatever real `operating_hours` keys the
/// API returns (confirmed real shape: 3-letter day → "HH:MM-HH:MM" or
/// "closed") rather than assuming a fixed 7-day list.
///
/// Two ways to reach this screen:
///   * `RecyclingCentreDetailScreen(centreId: id)` — the ORIGINAL
///     behaviour, unchanged: fetches `GET /customer/recycling-centres/{id}`
///     (the ELIGIBILITY-scoped endpoint, `acceptingPickups()` only).
///   * `RecyclingCentreDetailScreen.fromNearby(centre: nearbyCentre)` —
///     NEW: takes an already-fetched `NearbyRecyclingCentre` directly, no
///     second network call. This is the one the new nearby-discovery list/
///     map uses, deliberately — routing a Google-Places-discovered or
///     still-pending centre through the OLD fetch-by-id path would 404
///     (that endpoint's `show()` aborts unless the centre is verified+
///     active), which would be wrong for a screen whose whole point is to
///     work for both EcoXchange partners AND external centres.
class RecyclingCentreDetailScreen extends StatefulWidget {
  const RecyclingCentreDetailScreen({super.key, required int centreId})
      : _centreId = centreId,
        _preloaded = null;

  const RecyclingCentreDetailScreen.fromNearby({super.key, required NearbyRecyclingCentre centre})
      : _centreId = null,
        _preloaded = centre;

  final int? _centreId;
  final NearbyRecyclingCentre? _preloaded;

  @override
  State<RecyclingCentreDetailScreen> createState() => _RecyclingCentreDetailScreenState();
}

class _RecyclingCentreDetailScreenState extends State<RecyclingCentreDetailScreen> {
  bool _isLoading = true;
  ApiException? _error;
  RecyclingCentreModel? _centre;

  static const _dayLabels = {
    'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday', 'thu': 'Thursday',
    'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
  };
  static const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  void initState() {
    super.initState();
    if (widget._preloaded != null) {
      _isLoading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = context.read<CustomerRecyclingCentreRepository>();
      final centre = await repository.getCentreDetail(widget._centreId!);
      if (!mounted) return;
      setState(() => _centre = centre);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) messenger.showSnackBar(const SnackBar(content: Text('Could not open that app on this device.')));
  }

  @override
  Widget build(BuildContext context) {
    final nearby = widget._preloaded;

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: EcoAppBar(title: nearby?.name ?? _centre?.name ?? 'Recycling Centre'),
      body: nearby != null ? _buildNearby(context, nearby) : _buildLegacy(context),
    );
  }

  Widget _buildLegacy(BuildContext context) {
    return AsyncStateView<RecyclingCentreModel>(
      isLoading: _isLoading,
      error: _error,
      data: _centre,
      onRetry: _load,
      builder: (context, centre) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _IdentityHeader(name: centre.name),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'ADDRESS',
            icon: Icons.location_on_outlined,
            child: Text(
              centre.address ?? [centre.city, centre.state, centre.postcode].whereType<String>().join(', '),
              style: const TextStyle(fontSize: 13, color: AppColors.n700),
            ),
          ),
          if (centre.phone != null) _SectionCard(title: 'CONTACT', icon: Icons.call_outlined, child: Text(centre.phone!, style: const TextStyle(fontSize: 13, color: AppColors.n700))),
          if (centre.operatingHours != null && centre.operatingHours!.isNotEmpty) _buildOperatingHours(centre.operatingHours!),
        ],
      ),
    );
  }

  Widget _buildNearby(BuildContext context, NearbyRecyclingCentre centre) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _IdentityHeader(name: centre.name),
        const SizedBox(height: 10),
        // Pickup-support banner -- the one sentence this whole screen must
        // never get wrong (section 4/8): never claims pickup support
        // unless the server explicitly confirmed it.
        Container(
          key: Key(centre.pickupSupported ? 'centre-supports-pickup' : 'centre-no-pickup'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: centre.pickupSupported ? AppColors.green50 : AppColors.n100,
            borderRadius: BorderRadius.circular(AppRadii.r12),
          ),
          child: Row(
            children: [
              Icon(
                centre.pickupSupported ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: centre.pickupSupported ? AppColors.green600 : AppColors.n500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  centre.pickupSupported ? 'Supports EcoXchange pickup' : 'Does not support EcoXchange pickup',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: centre.pickupSupported ? AppColors.green700 : AppColors.n600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'ADDRESS',
          icon: Icons.location_on_outlined,
          child: Text(
            centre.address ?? [centre.city, centre.state, centre.postcode].whereType<String>().join(', '),
            style: const TextStyle(fontSize: 13, color: AppColors.n700),
          ),
        ),
        if (centre.distanceLabel.isNotEmpty)
          _SectionCard(title: 'DISTANCE', icon: Icons.near_me_outlined, child: Text(centre.distanceLabel, style: const TextStyle(fontSize: 13, color: AppColors.n700))),
        if (centre.phone != null)
          _SectionCard(title: 'CONTACT', icon: Icons.call_outlined, child: Text(centre.phone!, style: const TextStyle(fontSize: 13, color: AppColors.n700))),
        if (centre.rating != null)
          _SectionCard(
            title: 'RATING',
            icon: Icons.star_outline,
            child: Text('${centre.rating!.toStringAsFixed(1)} ★', style: const TextStyle(fontSize: 13, color: AppColors.n700)),
          ),
        if (centre.businessStatus != null)
          _SectionCard(title: 'STATUS', icon: Icons.storefront_outlined, child: Text(_humaniseBusinessStatus(centre.businessStatus!), style: const TextStyle(fontSize: 13, color: AppColors.n700))),
        if (!centre.pickupSupported)
          _SectionCard(
            title: 'ECOXCHANGE REWARD',
            icon: Icons.payments_outlined,
            child: const Text('Price information unavailable', style: TextStyle(fontSize: 13, color: AppColors.n500, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (centre.googleMapsUrl != null || (centre.latitude != null && centre.longitude != null))
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('centre-open-maps'),
                  onPressed: () => _launch(Uri.parse(centre.googleMapsUrl ?? 'https://maps.google.com/?q=${centre.latitude},${centre.longitude}')),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Maps'),
                ),
              ),
            if (centre.phone != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('centre-call'),
                  onPressed: () => _launch(Uri(scheme: 'tel', path: centre.phone)),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Call'),
                ),
              ),
            ],
            if (centre.website != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('centre-website'),
                  onPressed: () => _launch(Uri.parse(centre.website!)),
                  icon: const Icon(Icons.language, size: 16),
                  label: const Text('Website'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOperatingHours(Map<String, dynamic> operatingHours) {
    return _SectionCard(
      title: 'OPERATING HOURS',
      icon: Icons.access_time_outlined,
      child: Column(
        children: _dayOrder.where((day) => operatingHours.containsKey(day)).map((day) {
          final hours = operatingHours[day]?.toString() ?? '—';
          final isClosed = hours == 'closed';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(_dayLabels[day] ?? day, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.n700))),
                Text(
                  isClosed ? 'Closed' : hours,
                  style: TextStyle(fontSize: 12, color: isClosed ? AppColors.n400 : AppColors.green600, fontWeight: isClosed ? FontWeight.w400 : FontWeight.w700),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _humaniseBusinessStatus(String raw) => switch (raw) {
        'OPERATIONAL' => 'Open',
        'CLOSED_TEMPORARILY' => 'Temporarily closed',
        'CLOSED_PERMANENTLY' => 'Permanently closed',
        _ => raw,
      };
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r16)),
            child: const Icon(Icons.storefront_outlined, color: AppColors.green600, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.n800))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.green600),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.4, color: AppColors.green600)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
