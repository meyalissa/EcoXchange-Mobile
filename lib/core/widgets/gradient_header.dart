import 'package:flutter/material.dart';

/// EcoXchange Mobile — the recurring dark-green diagonal gradient header
/// block used on Login/Dashboard/Pickup Detail/Rewards, including the two
/// soft decorative circles every one of those HTML sections has. `gradient`
/// is supplied by the caller (each screen uses a different one from
/// [AppColors] — see design_tokens.dart) so this stays a pure layout
/// component, not a colour decision.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.gradient,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.borderRadius,
  });

  final Gradient gradient;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: gradient, borderRadius: borderRadius),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: _decorativeCircle(180, 0.05),
            ),
            Positioned(
              bottom: -60,
              left: -20,
              child: _decorativeCircle(160, 0.04),
            ),
            SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );
  }

  Widget _decorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }
}
