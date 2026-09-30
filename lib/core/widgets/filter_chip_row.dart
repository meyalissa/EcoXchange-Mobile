import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// EcoXchange Mobile — the horizontal scrollable pill filter row from the
/// HTML design's `.filter-row`/`.filter-chip` (status filter on Pickup
/// List, category filter on Items). One generic widget over a caller-
/// supplied `<String, String>` entries map (value → label) plus the
/// currently-selected value, so both screens share the exact same visual
/// treatment instead of two separate `ChoiceChip` rows.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// value → label, in display order.
  final Map<String?, String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.entries.map((entry) {
          final isActive = entry.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.green500 : AppColors.n0,
                  borderRadius: BorderRadius.circular(AppRadii.rFull),
                  border: Border.all(color: isActive ? AppColors.green500 : AppColors.n200, width: 1.5),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.n600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
