import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// EcoXchange Mobile — matches the HTML design's `.card` (white, r16,
/// layered `--sh1` shadow, 16px padding by default). The one shared card
/// container reused across Dashboard sections, Pickup Detail sections,
/// Item Detail sections, and Centre Detail sections rather than each
/// screen hand-rolling its own `Container` decoration.
class EcoCard extends StatelessWidget {
  const EcoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? AppRadii.r16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(color: color ?? AppColors.n0, borderRadius: radius, boxShadow: AppShadows.sh1),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            )
          : Padding(padding: padding, child: child),
    );
  }
}
