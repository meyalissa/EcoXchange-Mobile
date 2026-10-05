import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/eco_card.dart';
import '../../data/models/nearby_recycling_centre.dart';
import '../providers/recycling_centre_list_provider.dart';
import '../widgets/nearby_centres_map.dart';
import 'recycling_centre_detail_screen.dart';

/// EcoXchange Mobile — Profile → Recycling Centres: real nearby-centre
/// DISCOVERY. Shows every real centre near the customer (device GPS, else
/// their saved address) — EcoXchange partners AND Google-Places-discovered
/// external businesses alike — sorted by real server-computed distance,
/// with a map, search, and an All / Pickup Available filter (default:
/// All). An external centre is clearly labelled "Does not support
/// EcoXchange pickup" and is still fully viewable (address/phone/website/
/// Google Maps), just never selectable for an actual EcoXchange pickup —
/// that selection only ever happens in the separate booking flow
/// (BookingCentreStep), which this screen has no connection to.
class RecyclingCentreListScreen extends StatefulWidget {
  const RecyclingCentreListScreen({super.key, this.mapBuilder = defaultNearbyCentresMapBuilder});

  /// Injectable so widget tests never create the native map view.
  final NearbyCentresMapBuilder mapBuilder;

  @override
  State<RecyclingCentreListScreen> createState() => _RecyclingCentreListScreenState();
}

class _RecyclingCentreListScreenState extends State<RecyclingCentreListScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => context.read<RecyclingCentreListProvider>().setSearchQuery(_search.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RecyclingCentreListProvider>().load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecyclingCentreListProvider>();

    if (provider.locationState == CentreLocationState.unavailable && !provider.isLoading) {
      return _LocationUnavailable(onRetry: provider.load);
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: AsyncStateView<List<NearbyRecyclingCentre>>(
        isLoading: provider.isLoading && provider.allCentres.isEmpty,
        error: provider.error,
        data: provider.allCentres,
        onRetry: provider.load,
        builder: (context, _) => _Content(provider: provider, searchController: _search, mapBuilder: widget.mapBuilder),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.provider, required this.searchController, required this.mapBuilder});

  final RecyclingCentreListProvider provider;
  final TextEditingController searchController;
  final NearbyCentresMapBuilder mapBuilder;

  @override
  Widget build(BuildContext context) {
    final visible = provider.centres;
    final selected = provider.selectedCentreId != null
        ? visible.where((c) => c.id == provider.selectedCentreId).toList()
        : const <NearbyRecyclingCentre>[];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            key: const Key('centre-search'),
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search recycling centres...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.n0,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.rFull), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          // Horizontally scrollable, not a plain Row -- "Pickup Available"
          // is long enough to overflow a fixed-width Row on narrower
          // phones (caught by a widget test at a realistic 432-logical-px
          // width); scrolling is the same overflow-proof treatment
          // FilterChipRow already uses elsewhere in this app.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  key: const Key('centre-filter-all'),
                  label: 'All Centres',
                  selected: provider.filter == CentreFilter.all,
                  onSelected: () => provider.setFilter(CentreFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  key: const Key('centre-filter-pickup'),
                  label: 'Pickup Available',
                  selected: provider.filter == CentreFilter.pickupAvailable,
                  onSelected: () => provider.setFilter(CentreFilter.pickupAvailable),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 240,
          child: mapBuilder(
            context,
            centres: visible,
            userLocation: provider.origin,
            selectedCentreId: provider.selectedCentreId,
            onMarkerTap: provider.selectCentre,
          ),
        ),
        if (selected.isNotEmpty) _CentreInfoPanel(centre: selected.first, onClose: () => provider.selectCentre(null)),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No recycling centres found nearby.', style: TextStyle(fontSize: 13, color: AppColors.n500)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final centre in visible) ...[
                  _CentreCard(
                    centre: centre,
                    selected: provider.selectedCentreId == centre.id,
                    onTap: () => provider.selectCentre(centre.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.green500,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.n700),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CentreInfoPanel extends StatelessWidget {
  const _CentreInfoPanel({required this.centre, required this.onClose});

  final NearbyRecyclingCentre centre;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: EcoCard(
        key: const Key('centre-info-panel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(centre.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800))),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose, visualDensity: VisualDensity.compact),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (centre.distanceLabel.isNotEmpty) Text('📍 ${centre.distanceLabel}', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                if (centre.rating != null) Text('${centre.rating!.toStringAsFixed(1)} ★', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
              ],
            ),
            if (centre.address != null) Text(centre.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: centre.pickupSupported ? AppColors.green50 : AppColors.n100,
                borderRadius: BorderRadius.circular(AppRadii.rFull),
              ),
              child: Text(
                centre.pickupSupported ? 'Supports EcoXchange pickup' : 'Does not support EcoXchange pickup',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: centre.pickupSupported ? AppColors.green700 : AppColors.n600),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('centre-view-details'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RecyclingCentreDetailScreen.fromNearby(centre: centre)),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CentreCard extends StatelessWidget {
  const _CentreCard({required this.centre, required this.selected, required this.onTap});

  final NearbyRecyclingCentre centre;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      key: Key('centre-card-${centre.id}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: centre.pickupSupported ? AppColors.green50 : AppColors.n100,
              borderRadius: BorderRadius.circular(AppRadii.r12),
            ),
            child: Icon(Icons.storefront_outlined, color: centre.pickupSupported ? AppColors.green600 : AppColors.n500, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(centre.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800)),
                const SizedBox(height: 3),
                if (centre.address != null)
                  Text(centre.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (centre.distanceLabel.isNotEmpty) Text('📍 ${centre.distanceLabel}', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: centre.pickupSupported ? AppColors.green100 : AppColors.n100,
                        borderRadius: BorderRadius.circular(AppRadii.rFull),
                      ),
                      child: Text(
                        centre.pickupSupported ? 'Pickup available' : 'Does not support EcoXchange pickup',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: centre.pickupSupported ? AppColors.green700 : AppColors.n600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.n300),
        ],
      ),
    );
  }
}

class _LocationUnavailable extends StatelessWidget {
  const _LocationUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('centre-location-unavailable'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 56, color: AppColors.n300),
            const SizedBox(height: 12),
            const Text(
              'We need your location to find nearby recycling centres.\nEnable location access, or add a saved address with coordinates.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.n600, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
