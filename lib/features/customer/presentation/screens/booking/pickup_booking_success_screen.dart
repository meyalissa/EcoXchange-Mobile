import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../../../core/widgets/eco_card.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../data/models/pickup_detail.dart';
import '../pickup_detail_screen.dart';

/// EcoXchange Mobile — Pickup Booking success (Stage 3). Shown only after a
/// genuine `POST /customer/pickup` success — every value here is the real
/// [PickupDetail] the server returned (its own `id`/`reference`/`status`/
/// `pickup_date`/`pickup_time`/`estimated_reward`), not a value carried
/// over from an earlier client-side step. "What Happens Next" is static,
/// generic informational copy (no points/CO₂ claims — see Stage 2/3's
/// no-fabrication rules).
class PickupBookingSuccessScreen extends StatelessWidget {
  const PickupBookingSuccessScreen({super.key, required this.pickup, this.onDone});

  final PickupDetail pickup;
  final VoidCallback? onDone;

  void _backToPickups(BuildContext context) {
    onDone?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reward = pickup.actualReward ?? pickup.estimatedReward;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToPickups(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.n50,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              gradient: AppColors.homeHeroGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Pickup Requested!', style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Reference ${pickup.reference}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (reward != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadii.r20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESTIMATED REWARD', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('RM ${reward.toStringAsFixed(2)}', style: AppTheme.displayFont(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EcoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PICKUP SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green600, letterSpacing: 0.4)),
                        const SizedBox(height: 10),
                        _Row(label: 'Status', value: _statusLabel(pickup.status)),
                        _Row(label: 'Date', value: pickup.pickupDate ?? '—'),
                        _Row(label: 'Time', value: pickup.pickupTime ?? '—'),
                        if (pickup.centre != null) _Row(label: 'Centre', value: pickup.centre!.name),
                        if (pickup.estimatedWeightKg != null) _Row(label: 'Est. weight', value: '${pickup.estimatedWeightKg!.toStringAsFixed(2)} kg'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  EcoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WHAT HAPPENS NEXT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green600, letterSpacing: 0.4)),
                        const SizedBox(height: 10),
                        const _NextStep(number: 1, text: 'Your request is submitted for approval'),
                        const _NextStep(number: 2, text: 'A rider is assigned to your pickup'),
                        const _NextStep(number: 3, text: 'Track progress from Pickup Details'),
                        const _NextStep(number: 4, text: 'Your reward is credited after collection'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  EcoButton(
                    label: 'View Pickup Details',
                    pill: true,
                    fullWidth: true,
                    onPressed: () {
                      onDone?.call();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => PickupDetailScreen(pickupId: pickup.id)),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  EcoButton(
                    label: 'Back to Pickups',
                    variant: EcoButtonVariant.outline,
                    pill: true,
                    fullWidth: true,
                    onPressed: () => _backToPickups(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => status.isEmpty ? '—' : (status[0].toUpperCase() + status.substring(1));
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.n500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.n800))),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.rFull), border: Border.all(color: AppColors.green200, width: 1.5)),
            alignment: Alignment.center,
            child: Text('$number', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.n700))),
        ],
      ),
    );
  }
}
