import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_button.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/rider_pickup_action.dart';
import '../../data/models/rider_pickup_detail.dart';
import '../../data/repositories/rider_pickup_repository.dart';
import '../providers/rider_pickup_detail_provider.dart';
import '../widgets/rider_action_runner.dart';
import '../widgets/rider_status_chip.dart';

/// EcoXchange Mobile — Rider Pickup Detail: `GET /rider/pickups/{id}` plus
/// the rider's next action (Phase R2.2). Everything a rider needs to find,
/// contact and collect the pickup; a pickup assigned to someone else is a
/// real 403, shown through the shared error state.
///
/// The action area offers ONLY the action the pickup's ASSIGNMENT status
/// allows (assigned → Accept, accepted → Start, en_route → Collect, each
/// behind a confirmation; collecting → Complete, which opens
/// RiderCompletePickupScreen to record the collected quantities/weights).
/// State always comes from the server (see RiderPickupDetailProvider):
/// nothing changes on screen until Laravel confirms, and a 409 re-reads
/// the pickup.
class RiderPickupDetailScreen extends StatelessWidget {
  const RiderPickupDetailScreen({super.key, required this.pickupId});

  final int pickupId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RiderPickupDetailProvider(context.read<RiderPickupRepository>(), pickupId)..load(),
      child: const _DetailScaffold(),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderPickupDetailProvider>();
    final pickup = provider.pickup;

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: EcoAppBar(title: pickup?.reference ?? 'Pickup Detail'),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: AsyncStateView<RiderPickupDetail>(
          isLoading: provider.isLoading,
          error: provider.loadError,
          data: pickup,
          onRetry: provider.load,
          builder: (context, pickup) => _DetailContent(pickup: pickup),
        ),
      ),
      bottomNavigationBar: pickup == null ? null : _ActionArea(provider: provider, pickup: pickup),
    );
  }
}

// ── Next-action area ────────────────────────────────────────────────────────

/// Offers the pickup's single next action; confirmation, submission and
/// the completion screen all go through the shared [runRiderAction].
class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.provider, required this.pickup});

  final RiderPickupDetailProvider provider;
  final RiderPickupDetail pickup;

  @override
  Widget build(BuildContext context) {
    final status = pickup.assignment?.status;
    final next = provider.nextAction;
    final error = provider.actionError;
    final Widget? main = next == null ? null : _button(context, next);

    if (main == null && error == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.n0,
        border: Border(top: BorderSide(color: AppColors.n100)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                _ErrorNote(key: const Key('rider-action-error'), text: riderActionErrorText(error), onDismiss: provider.clearActionError),
                if (main != null) const SizedBox(height: 10),
              ],
              ?main,
              if (status != null && main != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Current status: ${RiderStatusChip.styleFor(status).label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.n500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(BuildContext context, RiderPickupAction action) {
    final copy = riderActionCopy(action);
    return EcoButton(
      key: Key('rider-action-${action.path}'),
      label: copy.button,
      icon: copy.icon,
      fullWidth: true,
      pill: true,
      loading: provider.submittingAction == action,
      onPressed: provider.isSubmitting ? null : () => runRiderAction(context, provider, action),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({super.key, required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.red, height: 1.4))),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 16, color: AppColors.red),
            onPressed: onDismiss,
          ),
        ],
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
              if (pickup.isPickupNow)
                const _InfoRow(icon: Icons.bolt_outlined, text: 'Pickup Now')
              else if (pickup.pickupDate != null)
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
