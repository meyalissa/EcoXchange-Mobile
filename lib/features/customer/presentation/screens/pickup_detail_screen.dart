import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/pickup_detail.dart';
import '../../data/repositories/customer_pickup_repository.dart';
import '../widgets/pickup_status_style.dart';

/// EcoXchange Mobile — Pickup Detail (Phase 4C.2 §8, restyled Phase 4C.3
/// to match `pickup-details.html`). A single fetch-and-show screen (no
/// filters/pagination to coordinate), so this uses simple local state
/// rather than a dedicated ChangeNotifier — see the Phase 4C.2 report for
/// why detail screens are deliberately lighter-weight than the list/
/// dashboard providers.
///
/// The design's header card also shows a "POINTS" stat and its timeline
/// gives every stage a timestamp — neither exists on [PickupDetail]
/// (there is no points concept anywhere in the backend, and the API only
/// ever returns the CURRENT status, never a per-stage history), so both
/// are deliberately left out here rather than invented — see
/// [_StatusTimeline] and the header card below.
class PickupDetailScreen extends StatefulWidget {
  const PickupDetailScreen({super.key, required this.pickupId});

  final int pickupId;

  @override
  State<PickupDetailScreen> createState() => _PickupDetailScreenState();
}

class _PickupDetailScreenState extends State<PickupDetailScreen> {
  bool _isLoading = true;
  ApiException? _error;
  PickupDetail? _pickup;

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
      final repository = context.read<CustomerPickupRepository>();
      final pickup = await repository.getPickupDetail(widget.pickupId);
      if (!mounted) return;
      setState(() => _pickup = pickup);
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
      appBar: EcoAppBar(title: _pickup != null ? _pickup!.reference : 'Pickup Detail'),
      body: AsyncStateView<PickupDetail>(
        isLoading: _isLoading,
        error: _error,
        data: _pickup,
        onRetry: _load,
        builder: (context, pickup) => _PickupDetailContent(pickup: pickup),
      ),
    );
  }
}

class _PickupDetailContent extends StatelessWidget {
  const _PickupDetailContent({required this.pickup});

  final PickupDetail pickup;

  @override
  Widget build(BuildContext context) {
    final style = PickupStatusStyle.forStatus(pickup.status);
    final reward = pickup.actualReward ?? pickup.estimatedReward;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header card ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.pickupHeaderGradient, borderRadius: BorderRadius.circular(AppRadii.r16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PICKUP ID', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(pickup.reference, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.rFull)),
                    child: Text(style.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeaderStat(label: 'DATE', value: pickup.pickupDate ?? '—'),
                  const SizedBox(width: 24),
                  _HeaderStat(label: 'REWARD', value: reward != null ? '+RM ${reward.toStringAsFixed(2)}' : '—'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Uploaded image — real URL only, honest empty state ─────────────
        _SectionCard(
          title: 'UPLOADED PHOTO',
          child: pickup.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.r12),
                  child: AppNetworkImage(
                    url: pickup.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _imageFallback('Photo could not be loaded'),
                  ),
                )
              : _imageFallback('No uploaded image'),
        ),

        if (pickup.items.isNotEmpty) _ItemsCollectedCard(items: pickup.items, total: reward),

        _SectionCard(
          title: 'PICKUP INFO',
          child: Column(
            children: [
              _InfoRow('Date', pickup.pickupDate ?? '—'),
              _InfoRow('Time', pickup.pickupTime ?? '—'),
              if (pickup.notes != null && pickup.notes!.isNotEmpty) _InfoRow('Notes', pickup.notes!),
              _InfoRow('Estimated Weight', pickup.estimatedWeightKg != null ? '${pickup.estimatedWeightKg!.toStringAsFixed(2)} kg' : '—'),
              if (pickup.actualWeightKg != null) _InfoRow('Actual Weight', '${pickup.actualWeightKg!.toStringAsFixed(2)} kg'),
              _InfoRow('Estimated Reward', pickup.estimatedReward != null ? 'RM ${pickup.estimatedReward!.toStringAsFixed(2)}' : '—'),
              if (pickup.actualReward != null) _InfoRow('Actual Reward', 'RM ${pickup.actualReward!.toStringAsFixed(2)}'),
            ],
          ),
        ),

        if (pickup.address != null)
          _SectionCard(title: 'PICKUP ADDRESS', child: Text(pickup.address!.formatted, style: const TextStyle(fontSize: 13, color: AppColors.n700))),

        if (pickup.centre != null)
          _SectionCard(
            title: 'RECYCLING CENTRE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickup.centre!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.n800)),
                if (pickup.centre!.address != null) ...[
                  const SizedBox(height: 2),
                  Text(pickup.centre!.address!, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                ],
                if (pickup.centre!.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(pickup.centre!.phone!, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                ],
              ],
            ),
          ),

        _SectionCard(
          title: 'RIDER INFORMATION',
          child: pickup.assignedRider != null ? _RiderRow(rider: pickup.assignedRider!) : const Text('No rider assigned yet.', style: TextStyle(fontSize: 13, color: AppColors.n500)),
        ),

        _SectionCard(title: 'STATUS TIMELINE', child: _StatusTimeline(status: pickup.status)),
      ],
    );
  }

  Widget _imageFallback(String message) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: AppColors.n400, size: 28),
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(color: AppColors.n500, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.rider});

  final AssignedRider rider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.green100,
          child: Text(
            rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.green700, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rider.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n800)),
              if (rider.vehicleType != null || rider.phoneNumber != null) ...[
                const SizedBox(height: 2),
                Text(
                  [rider.vehicleType, rider.vehiclePlateNo, rider.phoneNumber].whereType<String>().join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.n500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Real items only, priced from the real `price_per_kg_snapshot` captured
/// at collection time × the real weight recorded for that item — never a
/// re-derived or estimated figure invented by the client.
class _ItemsCollectedCard extends StatelessWidget {
  const _ItemsCollectedCard({required this.items, required this.total});

  final List<PickupDetailItem> items;
  final double? total;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'ITEMS COLLECTED',
      child: Column(
        children: [
          for (final item in items) _ItemRow(item: item),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.n200, width: 1.5))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n700)),
                Text(total != null ? 'RM ${total!.toStringAsFixed(2)}' : '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.green600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final PickupDetailItem item;

  @override
  Widget build(BuildContext context) {
    final weight = item.actualWeightKg ?? item.estimatedWeightKg;
    final price = (weight != null && item.pricePerKgSnapshot != null) ? weight * item.pricePerKgSnapshot! : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.n100))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r8)),
            child: const Icon(Icons.recycling_outlined, size: 18, color: AppColors.green600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.itemName} × ${item.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800)),
                if (weight != null) Text('${weight.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
              ],
            ),
          ),
          Text(price != null ? 'RM ${price.toStringAsFixed(2)}' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.green600)),
        ],
      ),
    );
  }
}

/// A visual progress indicator over the linear happy-path stage order —
/// driven ENTIRELY by the pickup's one real current `status` (no
/// per-stage timestamps exist in the API, so none are shown). Cancelled
/// pickups don't fit this linear model (cancellation can happen from any
/// stage), so they get their own single-state card instead.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final String status;

  static const _stages = <String, String>{
    'pending': 'Submitted',
    'approved': 'Approved',
    'assigned': 'Rider Assigned',
    'collecting': 'Collecting',
    'completed': 'Completed',
  };

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('This pickup was cancelled.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800)),
        ],
      );
    }

    final keys = _stages.keys.toList();
    final currentIndex = keys.indexOf(status);

    return Column(
      children: [
        for (var i = 0; i < keys.length; i++)
          _TimelineStep(
            label: _stages[keys[i]]!,
            reached: currentIndex >= 0 && i <= currentIndex,
            isLast: i == keys.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.label, required this.reached, required this.isLast});

  final String label;
  final bool reached;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppColors.green500 : AppColors.n200;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: reached ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: reached ? AppColors.green200 : AppColors.n200)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 2),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: reached ? AppColors.n800 : AppColors.n400)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.4, color: AppColors.green600)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.n500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.n800))),
        ],
      ),
    );
  }
}
