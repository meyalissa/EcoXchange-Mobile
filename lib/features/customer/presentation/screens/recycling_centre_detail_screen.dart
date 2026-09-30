import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/recycling_centre.dart';
import '../../data/repositories/customer_recycling_centre_repository.dart';

/// EcoXchange Mobile — Recycling Centre Detail (Phase 4C.2 §10, restyled
/// Phase 4C.3). There's no direct HTML reference for this screen (the
/// design only ever shows centres as picker cards, never a detail page),
/// so this extends the list card's visual language — the same icon box
/// and colour treatment — into a full layout. Renders whatever real
/// `operating_hours` keys the API returns (confirmed real shape: 3-letter
/// day → "HH:MM-HH:MM" or "closed") rather than assuming a fixed 7-day
/// list; no rating/distance/ETA anywhere, since none of it is real.
class RecyclingCentreDetailScreen extends StatefulWidget {
  const RecyclingCentreDetailScreen({super.key, required this.centreId});

  final int centreId;

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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = context.read<CustomerRecyclingCentreRepository>();
      final centre = await repository.getCentreDetail(widget.centreId);
      if (!mounted) return;
      setState(() => _centre = centre);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: EcoAppBar(title: _centre?.name ?? 'Recycling Centre'),
      body: AsyncStateView<RecyclingCentreModel>(
        isLoading: _isLoading,
        error: _error,
        data: _centre,
        onRetry: _load,
        builder: (context, centre) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Identity header ─────────────────────────────────────────────
            EcoCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r16)),
                    child: const Icon(Icons.storefront_outlined, color: AppColors.green600, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(centre.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.n800)),
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

            if (centre.phone != null) _SectionCard(title: 'CONTACT', icon: Icons.call_outlined, child: Text(centre.phone!, style: const TextStyle(fontSize: 13, color: AppColors.n700))),

            if (centre.operatingHours != null && centre.operatingHours!.isNotEmpty)
              _SectionCard(
                title: 'OPERATING HOURS',
                icon: Icons.access_time_outlined,
                child: Column(
                  children: _dayOrder.where((day) => centre.operatingHours!.containsKey(day)).map((day) {
                    final hours = centre.operatingHours![day]?.toString() ?? '—';
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
              ),
          ],
        ),
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
