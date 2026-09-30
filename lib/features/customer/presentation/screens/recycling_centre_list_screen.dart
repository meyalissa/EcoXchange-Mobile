import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/recycling_centre.dart';
import '../providers/recycling_centre_list_provider.dart';
import 'recycling_centre_detail_screen.dart';

/// EcoXchange Mobile — Recycling Centre List (Phase 4C.2 §10, restyled
/// Phase 4C.3 to reuse `select-recycling-center.html`'s card visual
/// language — icon box, name, address). This is a READ feature, not the
/// booking flow's picker: there is no "Select This Center" button, no
/// selection state, and — because none of it is real — no GPS distance,
/// star rating, or "Nearest" badge either. Shows only real
/// RecyclingCentreResource fields — no fuel price/min service cost/max
/// distance/minimum reward/verification status (deliberately excluded
/// server-side) and no fabricated customer-to-centre distance.
class RecyclingCentreListScreen extends StatefulWidget {
  const RecyclingCentreListScreen({super.key});

  @override
  State<RecyclingCentreListScreen> createState() => _RecyclingCentreListScreenState();
}

class _RecyclingCentreListScreenState extends State<RecyclingCentreListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RecyclingCentreListProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecyclingCentreListProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: AsyncStateView<List<RecyclingCentreModel>>(
        isLoading: provider.isLoading,
        error: provider.error,
        data: provider.centres,
        isEmpty: provider.centres.isEmpty,
        emptyMessage: 'No recycling centres available.',
        emptyIcon: Icons.storefront_outlined,
        onRetry: provider.load,
        builder: (context, centres) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: centres.length,
          itemBuilder: (context, index) {
            final centre = centres[index];
            final location = [centre.city, centre.state].whereType<String>().join(', ');
            return EcoCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RecyclingCentreDetailScreen(centreId: centre.id)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
                    child: const Icon(Icons.storefront_outlined, color: AppColors.green600, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(centre.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800)),
                        if (centre.address != null || location.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            centre.address ?? location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.n500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.n300),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
