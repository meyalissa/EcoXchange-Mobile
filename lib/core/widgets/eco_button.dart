import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

enum EcoButtonVariant { primary, secondary, outline, ghost }

/// EcoXchange Mobile — the four button styles from the HTML design's
/// `.btn-primary/.btn-secondary/.btn-outline/.btn-ghost`. Reused instead of
/// styling `ElevatedButton`/`OutlinedButton` ad hoc per screen.
class EcoButton extends StatelessWidget {
  const EcoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EcoButtonVariant.primary,
    this.fullWidth = false,
    this.pill = false,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final EcoButtonVariant variant;
  final bool fullWidth;
  final bool pill;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(pill ? AppRadii.rFull : AppRadii.r12);
    final content = loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 7)],
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          );

    final Widget button = switch (variant) {
      EcoButtonVariant.primary => ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green500,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.green500.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: radius),
            elevation: 0,
            shadowColor: AppColors.green500.withValues(alpha: 0.35),
          ),
          child: content,
        ),
      EcoButtonVariant.secondary => ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green50,
            foregroundColor: AppColors.green600,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.green200, width: 1.5)),
            elevation: 0,
          ),
          child: content,
        ),
      EcoButtonVariant.outline => OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.green600,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            side: const BorderSide(color: AppColors.green500, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        ),
      EcoButtonVariant.ghost => TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.n600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
