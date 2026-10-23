import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../data/models/item.dart';
import '../providers/ai_scan_provider.dart';
import 'quantity_stepper.dart';

/// EcoXchange Mobile — one confirmed-item row with its quantity stepper,
/// shared by the multi-object result screen and the single-object
/// confirmed view's manually-added items (Task 2: "Add an Item Manually").
/// Reads [AIScanProvider] directly rather than taking every value as a
/// parameter, so both call sites stay in sync with the exact same
/// suggested/corrected/manual state with no risk of drifting apart.
class ScanQuantityLine extends StatelessWidget {
  const ScanQuantityLine({super.key, required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<AIScanProvider>();
    final itemId = item.id;
    final suggested = scan.suggestedQuantityOf(itemId);
    final manual = scan.isManuallyAdded(itemId);
    final corrected = scan.isQuantityCorrected(itemId);

    return Column(
      key: Key('ai-qty-$itemId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n800)),
                  const SizedBox(height: 2),
                  Text(
                    manual ? 'Added by you (not detected by AI)' : 'AI suggested quantity: $suggested',
                    style: const TextStyle(fontSize: 12, color: AppColors.n500),
                  ),
                ],
              ),
            ),
            QuantityStepper(
              quantity: scan.quantityOf(itemId),
              onDecrement: () => scan.decrementQuantity(itemId),
              onIncrement: () => scan.incrementQuantity(itemId),
            ),
          ],
        ),
        if (corrected && !manual)
          Row(
            children: [
              const Icon(Icons.edit_outlined, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
              const Text('Edited by you', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
              const Spacer(),
              TextButton(
                onPressed: () => scan.resetQuantityToSuggestion(itemId),
                child: const Text('Use AI suggestion', style: TextStyle(fontSize: 12, color: AppColors.green700)),
              ),
            ],
          ),
      ],
    );
  }
}
