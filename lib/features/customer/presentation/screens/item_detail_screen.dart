import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_app_bar.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/item.dart';
import '../../data/repositories/customer_catalogue_repository.dart';

/// EcoXchange Mobile — Item Detail (Phase 4C.2 §9, restyled Phase 4C.3 to
/// match `item-details.html`). Simple fetch-and-show screen — local
/// state, same rationale as PickupDetailScreen.
///
/// PRICING RULE (do not remove): [item.priceNote] is rendered VERBATIM —
/// this app never writes its own explanatory copy for the preliminary
/// rate, so the UI text can never drift from what the server actually
/// means by it.
///
/// The design also shows "Accepted"/"Not Accepted" item lists — deliberately
/// NOT reproduced here: [ItemModel] has no such fields (the real
/// `ItemResource` doesn't expose them), and this stage must not touch
/// Laravel to add them.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final int itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isLoading = true;
  ApiException? _error;
  ItemModel? _item;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = context.read<CustomerCatalogueRepository>();
      final item = await repository.getItemDetail(widget.itemId);
      if (!mounted) return;
      setState(() => _item = item);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: EcoAppBar(title: _item?.name ?? 'Item Detail'),
      body: AsyncStateView<ItemModel>(
        isLoading: _isLoading,
        error: _error,
        data: _item,
        onRetry: _load,
        builder: (context, item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Hero banner ─────────────────────────────────────────────────
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(gradient: AppColors.pickupHeaderGradient, borderRadius: BorderRadius.circular(AppRadii.r16)),
              child: Center(
                child: item.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.r12),
                        child: AppNetworkImage(url: item.image!, height: 96, width: 96, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.recycling_outlined, color: Colors.white, size: 64)),
                      )
                    : const Icon(Icons.recycling_outlined, color: Colors.white, size: 64),
              ),
            ),
            const SizedBox(height: 16),

            // ── Rate + category stat cards — never presented as guaranteed ───
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12), border: Border.all(color: AppColors.green200, width: 1.5)),
                    child: Column(
                      children: [
                        const Text('PRELIMINARY RATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.n500), textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(
                          item.preliminaryBasePricePerKg != null ? 'RM ${item.preliminaryBasePricePerKg!.toStringAsFixed(2)}' : '—',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green600),
                        ),
                        const Text('per kg', style: TextStyle(fontSize: 11, color: AppColors.n500)),
                      ],
                    ),
                  ),
                ),
                if (item.category != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(AppRadii.r12), border: Border.all(color: const Color(0xFFF5D080), width: 1.5)),
                      child: Column(
                        children: [
                          const Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.n500), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(item.category!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF7B4F00))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            if (item.priceNote != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.n500),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.priceNote!, style: const TextStyle(fontSize: 12, color: AppColors.n600))),
                  ],
                ),
              ),

            if (item.description != null) _SectionCard(title: 'DESCRIPTION', child: Text(item.description!, style: const TextStyle(fontSize: 13, color: AppColors.n700))),

            if (item.preparationSteps != null && item.preparationSteps!.isNotEmpty)
              _SectionCard(
                title: '📋 PREPARATION GUIDE',
                child: Column(
                  children: item.preparationSteps!
                      .map((step) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.n100))),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(step, style: const TextStyle(fontSize: 13, color: AppColors.n700))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),

            if (item.recyclingTips != null && item.recyclingTips!.isNotEmpty) _SectionCard(title: 'RECYCLING TIPS', child: Text(item.recyclingTips!, style: const TextStyle(fontSize: 13, color: AppColors.n700))),

            if (item.environmentalImpact != null && item.environmentalImpact!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12), border: Border.all(color: AppColors.green200, width: 1.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌍 Environmental Impact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green700)),
                    const SizedBox(height: 4),
                    Text(item.environmentalImpact!, style: const TextStyle(fontSize: 13, color: AppColors.green600, height: 1.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.4, color: AppColors.n500)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
