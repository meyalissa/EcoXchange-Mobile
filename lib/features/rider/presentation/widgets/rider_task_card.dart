import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/rider_pickup_summary.dart';
import 'rider_status_chip.dart';

/// EcoXchange Mobile — the white job card of My Tasks and Job History
/// (02_rider_tasks / 04_rider_history designs). Every line is a real field
/// of the pickup summary; lines without data are left out. [actions] are
/// the card's buttons (none for history).
class RiderTaskCard extends StatelessWidget {
  const RiderTaskCard({super.key, required this.pickup, required this.onTap, this.actions = const []});

  final RiderPickupSummary pickup;
  final VoidCallback onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final weight = pickup.actualWeightKg ?? pickup.estimatedWeightKg;
    final weightLabel = weight == null ? null : '${pickup.actualWeightKg != null ? '' : '~'}${weight.toStringAsFixed(1)} kg';

    return Material(
      color: AppColors.n0,
      borderRadius: BorderRadius.circular(AppRadii.r20),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.r20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.r20), boxShadow: AppShadows.sh1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(pickup.reference, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.green600)),
                  const Spacer(),
                  RiderStatusChip(status: pickup.displayStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(pickup.customerName ?? '—', style: AppTheme.displayFont(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.n800)),
              if (pickup.addressSummary != null) _Line(icon: Icons.location_on_outlined, text: pickup.addressSummary!),
              if (pickup.isPickupNow)
                const _Line(icon: Icons.bolt_outlined, text: 'Pickup Now')
              else if (pickup.pickupDate != null || pickup.pickupTime != null)
                _Line(icon: Icons.schedule, text: [pickup.pickupDate, pickup.pickupTime].whereType<String>().join(' · ')),
              if (pickup.itemNames.isNotEmpty || weightLabel != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in pickup.itemNames) _Tag(text: name),
                    if (weightLabel != null) _Tag(text: weightLabel, strong: true),
                  ],
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.n400),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.n600))),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: strong ? AppColors.green50 : AppColors.n50, borderRadius: BorderRadius.circular(AppRadii.rFull)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: strong ? AppColors.green700 : AppColors.n600)),
    );
  }
}
