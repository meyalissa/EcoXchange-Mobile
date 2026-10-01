import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/models/rider_pickup_summary.dart';
import 'rider_status_chip.dart';

/// EcoXchange Mobile — one tappable rider job row (dashboard and My
/// Pickups): reference, date/time, customer, short address, centre, status
/// and weight. Same layout language as the Customer PickupSummaryCard;
/// every field is a real RiderPickupSummaryResource field.
class RiderPickupCard extends StatelessWidget {
  const RiderPickupCard({super.key, required this.pickup, required this.onTap});

  final RiderPickupSummary pickup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weight = pickup.actualWeightKg ?? pickup.estimatedWeightKg;
    final cancelled = pickup.displayStatus == 'cancelled';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('rider-pickup-${pickup.id}'),
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
                  color: cancelled ? AppColors.redLight : AppColors.green50,
                  borderRadius: BorderRadius.circular(AppRadii.r12),
                ),
                child: Icon(Icons.two_wheeler_outlined, size: 20, color: cancelled ? AppColors.red : AppColors.green600),
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
                    if (pickup.customerName != null) ...[
                      const SizedBox(height: 3),
                      Text(pickup.customerName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.n700)),
                    ],
                    if (pickup.addressSummary != null)
                      Text(pickup.addressSummary!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.n600)),
                    if (pickup.centreName != null)
                      Text('→ ${pickup.centreName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RiderStatusChip(status: pickup.displayStatus),
                        if (weight != null) ...[
                          const SizedBox(width: 6),
                          Text('⚖️ ${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.n400),
            ],
          ),
        ),
      ),
    );
  }
}
