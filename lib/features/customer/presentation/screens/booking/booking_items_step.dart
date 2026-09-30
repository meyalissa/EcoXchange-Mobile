import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/async_state_view.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../../../core/widgets/filter_chip_row.dart';
import '../../../data/models/item.dart';
import '../../providers/item_catalogue_provider.dart';
import '../../providers/pickup_booking_provider.dart';
import '../../widgets/quantity_stepper.dart';

/// EcoXchange Mobile — Pickup Booking Step 1 (Stage 3). Real catalogue
/// (reuses `ItemCatalogueProvider`/`CustomerCatalogueRepository` exactly as
/// the Items tab does — no separate item data source), a quantity stepper
/// per item (never a manual weight field — see `PickupBookingProvider`
/// docblock for why quantity-based server estimation is the only input
/// this app sends), and a "Selected Items" summary. "Continue" calls the
/// real `/pickup/estimate` endpoint and only advances on success — the
/// per-item weight/reward shown afterwards is 100% server-computed.
class BookingItemsStep extends StatefulWidget {
  const BookingItemsStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<BookingItemsStep> createState() => _BookingItemsStepState();
}

class _BookingItemsStepState extends State<BookingItemsStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ItemCatalogueProvider>().load());
  }

  Future<void> _continue() async {
    final booking = context.read<PickupBookingProvider>();
    final ok = await booking.loadEstimate();
    if (ok && mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = context.watch<ItemCatalogueProvider>();
    final booking = context.watch<PickupBookingProvider>();

    return Column(
      children: [
        if (catalogue.categories.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(color: AppColors.n0, border: Border(bottom: BorderSide(color: AppColors.n100))),
            child: FilterChipRow(
              options: {
                null: 'All',
                for (final category in catalogue.categories) category.name: '${category.name} (${category.itemCount})',
              },
              selected: catalogue.selectedCategory,
              onSelected: catalogue.selectCategory,
            ),
          ),
        Expanded(
          child: AsyncStateView<List<ItemModel>>(
            isLoading: catalogue.isLoading,
            error: catalogue.error,
            data: catalogue.items,
            isEmpty: catalogue.items.isEmpty,
            emptyMessage: 'No items found for this category.',
            emptyIcon: Icons.recycling_outlined,
            onRetry: catalogue.load,
            builder: (context, items) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (booking.hasAiSuggestedQuantities) ...[
                  const _AiSuggestedNotice(),
                  const SizedBox(height: 12),
                ],
                Text('Choose what you\'re recycling and how many.', style: const TextStyle(fontSize: 13, color: AppColors.n500)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.86),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _ItemPickCard(item: items[index]),
                ),
                if (booking.hasSelectedItems) ...[
                  const SizedBox(height: 20),
                  const Text('Selected Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r16), boxShadow: AppShadows.sh1),
                    child: Column(
                      children: [
                        for (final item in booking.selectedItems) ...[
                          if (item != booking.selectedItems.first) const Divider(height: 1, color: AppColors.n100),
                          _SelectedItemRow(item: item),
                        ],
                      ],
                    ),
                  ),
                  if (booking.estimateError != null) ...[
                    const SizedBox(height: 10),
                    _InlineError(message: booking.estimateError!.message),
                  ],
                ],
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
        _BottomBar(
          child: EcoButton(
            label: booking.hasSelectedItems
                ? 'Continue with ${booking.totalSelectedQuantity} item${booking.totalSelectedQuantity == 1 ? '' : 's'}'
                : 'Select at least 1 item',
            fullWidth: true,
            pill: true,
            loading: booking.isEstimating,
            onPressed: booking.hasSelectedItems ? _continue : null,
          ),
        ),
      ],
    );
  }
}

class _ItemPickCard extends StatelessWidget {
  const _ItemPickCard({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PickupBookingProvider>();
    final qty = booking.quantityOf(item.id);
    final selected = qty > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(AppRadii.r16),
        boxShadow: AppShadows.sh1,
        border: Border.all(color: selected ? AppColors.green400 : Colors.transparent, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r12),
            child: item.image != null
                ? AppNetworkImage(url: item.image!, height: 40, width: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => _iconFallback())
                : _iconFallback(),
          ),
          const SizedBox(height: 6),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.n800)),
          if (item.preliminaryBasePricePerKg != null)
            Text('RM ${item.preliminaryBasePricePerKg!.toStringAsFixed(2)}/kg', style: const TextStyle(fontSize: 10, color: AppColors.green600)),
          const SizedBox(height: 8),
          QuantityStepper(
            quantity: qty,
            onDecrement: () => booking.decrementQuantity(item),
            onIncrement: () => booking.incrementQuantity(item),
          ),
        ],
      ),
    );
  }

  Widget _iconFallback() {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: const Icon(Icons.recycling_outlined, color: AppColors.green600, size: 20),
    );
  }
}

class _SelectedItemRow extends StatelessWidget {
  const _SelectedItemRow({required this.item});

  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PickupBookingProvider>();
    final qty = booking.quantityOf(item.id);
    final line = booking.estimate?.items.where((l) => l.itemId == item.id).firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800)),
                Text(
                  line != null ? '${line.quantity} × · ${line.weightKg.toStringAsFixed(2)} kg' : '$qty ×',
                  style: const TextStyle(fontSize: 11, color: AppColors.n500),
                ),
              ],
            ),
          ),
          if (line?.preliminaryLineReward != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text('RM ${line!.preliminaryLineReward!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.green600)),
            ),
          InkResponse(
            onTap: () => booking.removeItem(item.id),
            radius: 18,
            child: const Icon(Icons.close, size: 18, color: AppColors.n400),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: AppColors.n0, border: Border(top: BorderSide(color: AppColors.n100))),
      child: child,
    );
  }
}

class _AiSuggestedNotice extends StatelessWidget {
  const _AiSuggestedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.green700),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quantities below were suggested by AI from your photo. Adjust them if they don\'t match — '
              'weight and reward are calculated by EcoXchange from the quantities you confirm.',
              style: TextStyle(fontSize: 12, color: AppColors.green800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.red))),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
