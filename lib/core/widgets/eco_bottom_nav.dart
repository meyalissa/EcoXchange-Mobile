import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// One destination in [EcoBottomNav] — mirrors the HTML design's `.bn-item`
/// (outline icon that swaps to a filled icon when active, 10px bold label).
class EcoNavItem {
  const EcoNavItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// EcoXchange Mobile — custom bottom navigation bar restyled (Phase 4C.3
/// §2/§11) to match `app.css`'s `.bottom-nav`/`.bn-item` exactly: 72px tall,
/// white background, a soft upward shadow, outline icons that turn
/// `green500` + a 2px top indicator bar when active. Built as a plain
/// `Container`/`Row` rather than Material's stock `NavigationBar` because
/// the design's active-state treatment (top bar + icon-only colour swap,
/// no pill background) doesn't map onto `NavigationBar`'s indicator model.
/// Still carries exactly the 5 real functional tabs — see
/// `CustomerHomeScreen` for the approved tab set.
class EcoBottomNav extends StatelessWidget {
  const EcoBottomNav({super.key, required this.currentIndex, required this.onTap, required this.items});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<EcoNavItem> items;

  @override
  Widget build(BuildContext context) {
    // 72px is the design's bar height for its CONTENT — on a device with a
    // gesture nav bar / 3-button nav inset, that inset needs to be extra
    // height on top of the 72, not squeezed out of it (SafeArea's bottom
    // padding was previously eating into a hard-fixed 72px Container,
    // overflowing the Row by exactly the inset amount — a genuine Stage 2
    // bug found during Stage 2.1 device verification, fixed here only).
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 72 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.n0,
        border: Border(top: BorderSide(color: AppColors.n100)),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(child: _NavItemButton(item: items[i], active: i == currentIndex, onTap: () => onTap(i))),
        ],
      ),
    );
  }
}

class _NavItemButton extends StatelessWidget {
  const _NavItemButton({required this.item, required this.active, required this.onTap});

  final EcoNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green500 : AppColors.n400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.r12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -6,
                    child: AnimatedOpacity(
                      opacity: active ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 22,
                        height: 2,
                        decoration: const BoxDecoration(color: AppColors.green500, borderRadius: BorderRadius.vertical(bottom: Radius.circular(3))),
                      ),
                    ),
                  ),
                  Icon(active ? item.activeIcon : item.icon, size: 22, color: color),
                ],
              ),
              const SizedBox(height: 4),
              Text(item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
