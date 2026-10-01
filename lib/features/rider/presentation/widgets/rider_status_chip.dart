import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../customer/presentation/widgets/pickup_status_style.dart';

/// EcoXchange Mobile — status pill for a rider's job. Reuses the Customer
/// app's [PickupStatusStyle] for every shared token, and adds only the two
/// assignment states that exist for riders alone (`accepted`, `en_route`),
/// so both apps show the same colour for the same state. Presentation only.
class RiderStatusChip extends StatelessWidget {
  const RiderStatusChip({super.key, required this.status});

  final String status;

  static ({String label, Color background, Color foreground}) styleFor(String status) {
    switch (status) {
      case 'accepted':
        return (label: 'Accepted', background: AppColors.blueLight, foreground: AppColors.blue);
      case 'en_route':
        return (label: 'On the Way', background: AppColors.goldLight, foreground: const Color(0xFF9B6800));
      default:
        final s = PickupStatusStyle.forStatus(status);
        return (label: s.label, background: s.background, foreground: s.foreground);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(AppRadii.rFull)),
      child: Text(style.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: style.foreground)),
    );
  }
}
