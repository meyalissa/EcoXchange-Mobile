import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'gradient_header.dart';

/// EcoXchange Mobile — the tall green page hero used across the Customer and
/// Rider tabs (Pickup Hub, AI Scan, Rewards, Collection History, profiles):
/// a small [subtitle] over a large display [title], an optional round
/// [trailing] action, and optional [child] content below. Built on
/// [GradientHeader] so the decorative circles and safe area stay identical.
class EcoHeroHeader extends StatelessWidget {
  const EcoHeroHeader({
    super.key,
    this.subtitle,
    required this.title,
    this.trailing,
    this.child,
    this.gradient = AppColors.homeHeroGradient,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 24),
  });

  final String? subtitle;
  final String title;
  final Widget? trailing;
  final Widget? child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      gradient: gradient,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(title, style: AppTheme.displayFont(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (child != null) ...[const SizedBox(height: 18), child!],
        ],
      ),
    );
  }
}

/// A translucent round icon button for the hero's top-right corner.
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({super.key, required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.16)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// White rounded section title row used under the hero ("Recent Pickups"
/// … "View All").
class SectionTitleRow extends StatelessWidget {
  const SectionTitleRow({super.key, required this.title, this.actionLabel, this.onAction, this.trailing});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTheme.displayFont(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.n800))),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.green600)),
          ),
        ?trailing,
      ],
    );
  }
}
