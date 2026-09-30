import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// EcoXchange Mobile — the +/- quantity control from the booking design's
/// item-card grid (`add-items-manual.html`), adapted to whole-unit
/// **quantity** (not a manual weight/kg value — the real backend computes
/// weight itself from `quantity × item.estimated_unit_weight_kg`; see
/// `PickupPreparationController`'s docblock). `min` prevents a
/// zero/negative quantity from ever being reachable via the `-` button
/// when `quantity` is already at the floor the caller wants enforced.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.min = 0,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final int min;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          enabled: quantity > min,
          onTap: onDecrement,
          background: AppColors.n100,
          foreground: AppColors.n700,
        ),
        SizedBox(
          width: 32,
          child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.n800)),
        ),
        _StepButton(
          icon: Icons.add,
          enabled: true,
          onTap: onIncrement,
          background: AppColors.green100,
          foreground: AppColors.green700,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onTap, required this.background, required this.foreground});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: enabled ? background : AppColors.n100, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: enabled ? foreground : AppColors.n300),
        ),
      ),
    );
  }
}
