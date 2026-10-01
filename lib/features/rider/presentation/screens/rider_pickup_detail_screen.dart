import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/rider_pickup_detail.dart';
import '../../data/repositories/rider_pickup_repository.dart';
import '../widgets/rider_status_chip.dart';

/// EcoXchange Mobile — Rider Pickup Detail (Phase R1, READ-ONLY):
/// `GET /rider/pickups/{id}`. Everything a rider needs to find, contact and
/// collect the pickup. A pickup assigned to someone else is a real 403,
/// shown through the shared error state. State-changing actions
/// (accept/start/collect/complete) are deliberately not here yet.
///
/// A single fetch-and-show screen, so it keeps simple local state like the
/// Customer PickupDetailScreen rather than a dedicated ChangeNotifier.
class RiderPickupDetailScreen extends StatefulWidget {
  const RiderPickupDetailScreen({super.key, required this.pickupId});

  final int pickupId;

  @override
  State<RiderPickupDetailScreen> createState() => _RiderPickupDetailScreenState();
}

class _RiderPickupDetailScreenState extends State<RiderPickupDetailScreen> {
  bool _isLoading = true;
  ApiException? _error;
  RiderPickupDetail? _pickup;

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
      final pickup = await context.read<RiderPickupRepository>().getPickupDetail(widget.pickupId);
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
      appBar: EcoAppBar(title: _pickup?.reference ?? 'Pickup Detail'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView<RiderPickupDetail>(
          isLoading: _isLoading,
          error: _error,
          data: _pickup,
          onRetry: _load,
          builder: (context, pickup) => _DetailContent(pickup: pickup),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.pickup});

  final RiderPickupDetail pickup;

  @override
  Widget build(BuildContext context) {
    final weight = pickup.actualWeightKg ?? pickup.estimatedWeightKg;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(pickup.reference, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.n800)),
                  ),
                  RiderStatusChip(key: const Key('rider-detail-status'), status: pickup.displayStatus),
                ],
              ),
              const SizedBox(height: 6),
              if (pickup.pickupDate != null)
                _InfoRow(icon: Icons.event_outlined, text: [pickup.pickupDate, pickup.pickupTime].whereType<String>().join(' · ')),
              if (weight != null)
                _InfoRow(
                  icon: Icons.scale_outlined,
                  text: '${weight.toStringAsFixed(2)} kg ${pickup.actualWeightKg != null ? '(actual)' : '(estimated)'}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Customer',
          children: [
            _InfoRow(icon: Icons.person_outline, text: pickup.customerName ?? '—'),
            if (pickup.customerPhone != null) _InfoRow(icon: Icons.phone_outlined, text: pickup.customerPhone!),
          ],
        ),
        _Section(
          title: 'Pickup address',
          children: [_InfoRow(icon: Icons.location_on_outlined, text: pickup.address?.formatted ?? '—')],
        ),
        if (pickup.centre != null)
          _Section(
            title: 'Deliver to',
            children: [
              _InfoRow(icon: Icons.storefront_outlined, text: pickup.centre!.name ?? '—'),
              if (pickup.centre!.address != null) _InfoRow(icon: Icons.map_outlined, text: pickup.centre!.address!),
              if (pickup.centre!.phone != null) _InfoRow(icon: Icons.phone_outlined, text: pickup.centre!.phone!),
            ],
          ),
        _Section(
          title: 'Items',
          children: [
            if (pickup.items.isEmpty)
              const Text('No items listed.', style: TextStyle(fontSize: 13, color: AppColors.n500))
            else
              for (final item in pickup.items)
                Padding(
                  key: Key('rider-item-${item.itemId}'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName ?? 'Item #${item.itemId}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800),
                        ),
                      ),
                      Text('× ${item.quantity}', style: const TextStyle(fontSize: 13, color: AppColors.n600)),
                      if ((item.actualWeightKg ?? item.estimatedWeightKg) != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${(item.actualWeightKg ?? item.estimatedWeightKg)!.toStringAsFixed(2)} kg',
                          style: const TextStyle(fontSize: 12, color: AppColors.n500),
                        ),
                      ],
                    ],
                  ),
                ),
          ],
        ),
        if (pickup.notes != null && pickup.notes!.trim().isNotEmpty)
          _Section(title: 'Customer notes', children: [Text(pickup.notes!, style: const TextStyle(fontSize: 13, color: AppColors.n700, height: 1.4))]),
        if (pickup.imageUrl != null)
          _Section(
            title: 'Photo from customer',
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.r12),
                child: AppNetworkImage(
                  url: pickup.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    color: AppColors.n100,
                    alignment: Alignment.center,
                    child: const Text('Photo could not be loaded.', style: TextStyle(fontSize: 12, color: AppColors.n500)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.n500)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.n500),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.n700, height: 1.35))),
        ],
      ),
    );
  }
}
