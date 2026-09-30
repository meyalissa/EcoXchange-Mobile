import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/filter_chip_row.dart';
import '../../data/models/item.dart';
import '../providers/item_catalogue_provider.dart';
import 'item_detail_screen.dart';

/// EcoXchange Mobile — Item Catalogue (Phase 4C.2 §9, restyled Phase 4C.3
/// to match `items-guide.html`'s `.item-card` grid). Category filter is
/// the real `category` query param ItemController::index() supports —
/// nothing else. Every item's price is explicitly labelled preliminary
/// (see _ItemCard) using the server's own `preliminary_base_price_per_kg`
/// field name/wording, never "Guaranteed Reward". The design's free-text
/// search bar isn't backed by any endpoint, so it's deliberately not
/// reproduced here.
class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ItemCatalogueProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemCatalogueProvider>();

    return Column(
      children: [
        if (provider.categories.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(color: AppColors.n0, border: Border(bottom: BorderSide(color: AppColors.n100))),
            child: FilterChipRow(
              options: {
                null: 'All',
                for (final category in provider.categories) category.name: '${category.name} (${category.itemCount})',
              },
              selected: provider.selectedCategory,
              onSelected: provider.selectCategory,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: AsyncStateView<List<ItemModel>>(
              isLoading: provider.isLoading,
              error: provider.error,
              data: provider.items,
              isEmpty: provider.items.isEmpty,
              emptyMessage: 'No items found for this category.',
              emptyIcon: Icons.recycling_outlined,
              onRetry: provider.load,
              builder: (context, items) => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ItemCard(
                    item: item,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});

  final ItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The white fill lives on this plain Container (not on the Material
    // below) — same technique as EcoCard. Painting white via Material's
    // own `color` instead let Material 3's surface-tint/elevation layer
    // wash the card grey on a real device (a genuine Stage 2 bug found
    // and fixed during Stage 2.1 device verification); Material here only
    // supplies the transparent ink layer for the tap splash.
    final radius = BorderRadius.circular(AppRadii.r16);
    return Container(
      decoration: BoxDecoration(color: AppColors.n0, borderRadius: radius, boxShadow: AppShadows.sh1),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.r12),
                  child: item.image != null
                      ? AppNetworkImage(url: item.image!, height: 44, width: 44, fit: BoxFit.cover, errorBuilder: (_, _, _) => _iconFallback())
                      : _iconFallback(),
                ),
                const SizedBox(height: 8),
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.n800)),
                const SizedBox(height: 3),
                if (item.preliminaryBasePricePerKg != null)
                  Text('RM ${item.preliminaryBasePricePerKg!.toStringAsFixed(2)}/kg · est.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green600)),
                if (item.category != null) ...[
                  const SizedBox(height: 2),
                  Text(item.category!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.n400)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconFallback() {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: const Icon(Icons.recycling_outlined, color: AppColors.green600, size: 22),
    );
  }
}
