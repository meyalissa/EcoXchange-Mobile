import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// EcoXchange Mobile — app bar matching the HTML design's `.app-bar`
/// (56px content height, circular back button, 17px/800 title). Unlike
/// the static HTML mockup (which hardcodes a fixed status-bar height),
/// this relies on Flutter's own `SafeArea`/`Scaffold` handling for the
/// real device's notch/status bar — the 56px here is content height only.
///
/// Two variants used across the app: `elevated` (white background, subtle
/// shadow/border — used on Pickup List/Detail, Items, Item Detail,
/// Centres, Centre Detail) and transparent-on-gradient (Login/Dashboard/
/// Rewards render their own hero header instead of using this bar at all).
class EcoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EcoAppBar({
    super.key,
    required this.title,
    this.backgroundColor,
    this.foregroundColor,
    this.elevated = true,
    this.actions,
    this.showBackButton = true,
    this.onBack,
  });

  final String title;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool elevated;
  final List<Widget>? actions;
  final bool showBackButton;

  /// Overrides the back button's default `Navigator.maybePop()` — e.g. a
  /// multi-step flow (see `PickupBookingScreen`) where "back" means "go to
  /// the previous step", only popping the route once already on step 0.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? AppColors.n800;
    final bg = backgroundColor ?? AppColors.n0;

    // The visible background is painted by this Container, not by
    // Material's own `color` below — Material's `color` renders a few
    // percent darker than the value it's given (a genuine Stage 2 bug
    // found and fixed during Stage 2.1 device verification: any surface
    // painted directly via `Material.color` came out visibly greyed,
    // while the identical colour painted via a plain Container did not).
    // Material is kept only as the ink-hosting ancestor the back/action
    // buttons' InkResponse splashes need.
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: elevated ? const Border(bottom: BorderSide(color: AppColors.n100)) : null,
        boxShadow: elevated ? AppShadows.sh1 : null,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                if (showBackButton)
                  _CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    color: fg,
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 36),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) ...actions!,
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
