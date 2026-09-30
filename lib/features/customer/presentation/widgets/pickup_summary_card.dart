import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/models/pickup_summary.dart';
import 'pickup_status_style.dart';

/// EcoXchange Mobile — one tappable pickup row, restyled (Phase 4C.3) to
/// match `pickup-history.html`'s list rows: a 44px icon box (colour-coded
/// by status), reference + date/time, a comma-joined item summary line,
/// status pill + weight, and the reward amount at trailing edge. Shared by
/// the Dashboard (active/recent pickups) and the Pickup List screen so
/// both present the exact same real fields identically. Tapping requires
/// [onTap] — callers always have a real `PickupSummary.id` to navigate
/// with (Phase 4C.2 §6).
class PickupSummaryCard extends StatelessWidget {
  const PickupSummaryCard({super.key, required this.pickup, required this.onTap});

  final PickupSummary pickup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = PickupStatusStyle.forStatus(pickup.status);
    final reward = pickup.actualReward ?? pickup.estimatedReward;
    final weight = pickup.actualWeightKg ?? pickup.estimatedWeightKg;
    final itemsLine = pickup.itemSummaries.map((e) => e.itemName).join(', ');
    final isCancelled = pickup.isCancelled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCancelled ? AppColors.redLight : AppColors.green50,
                  borderRadius: BorderRadius.circular(AppRadii.r12),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: isCancelled ? AppColors.red : AppColors.green600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pickup.reference, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.n800)),
                    if (pickup.pickupDate != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        [pickup.pickupDate, pickup.pickupTime].whereType<String>().join(' · '),
                        style: const TextStyle(fontSize: 11, color: AppColors.n500),
                      ),
                    ],
                    if (itemsLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(itemsLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.n600)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(AppRadii.rFull)),
                          child: Text(style.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: style.foreground)),
                        ),
                        if (weight != null) ...[
                          const SizedBox(width: 6),
                          Text('⚖️ ${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                reward != null ? 'RM ${reward.toStringAsFixed(2)}' : '–',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: reward != null ? AppColors.green600 : AppColors.n400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
