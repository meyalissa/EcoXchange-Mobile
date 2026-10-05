import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/async_state_view.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../data/models/nearby_recycling_centre.dart';
import '../../../data/models/pickup_booking.dart';
import '../../providers/pickup_booking_provider.dart';
import '../recycling_centre_detail_screen.dart';

/// EcoXchange Mobile — Pickup Booking Step 3 (Stage 3). Two tabs:
///
///   * Pickup Available (default) — real eligible centres only
///     (`POST /customer/pickup/centres`), UNCHANGED from before: reuses
///     the exact same `EligibleCentre`/server eligibility logic, rates,
///     and `canProceedFromCentre` gate. Still the ONLY tab that can ever
///     set `PickupBookingProvider.selectedCentre`.
///   * All Centres — real nearby-centre DISCOVERY (the same
///     `GET /customer/recycling-centres/nearby` the Profile → Recycling
///     Centres page uses), including external Google-Places-discovered
///     businesses. Browsable (view details / open Google Maps) but NEVER
///     selectable here — tapping an external card never calls
///     `selectCentre()`, so there is no path by which this tab could let a
///     customer submit a pickup through a centre EcoXchange doesn't
///     support. `distance_label`/`recommended` on the Pickup Available tab
///     are genuine server fields (`PickupFeasibilityService::
///     findEligibleCentres()`) — never a client-computed "nearest".
class BookingCentreStep extends StatefulWidget {
  const BookingCentreStep({super.key, required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<BookingCentreStep> createState() => _BookingCentreStepState();
}

class _BookingCentreStepState extends State<BookingCentreStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PickupBookingProvider>().loadCentres());
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PickupBookingProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          // Horizontally scrollable, not a plain Row -- "Pickup Available"
          // is long enough to overflow a fixed-width Row on narrower
          // phones (same fix as recycling_centre_list_screen.dart's own
          // filter row, caught by a widget test there).
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabChip(
                  key: const Key('booking-centre-tab-pickup'),
                  label: 'Pickup Available',
                  selected: booking.centreTab == CentreTab.pickupAvailable,
                  onSelected: () => booking.setCentreTab(CentreTab.pickupAvailable),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  key: const Key('booking-centre-tab-all'),
                  label: 'All Centres',
                  selected: booking.centreTab == CentreTab.all,
                  onSelected: () => booking.setCentreTab(CentreTab.all),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: booking.centreTab == CentreTab.pickupAvailable
              ? _PickupAvailableList(booking: booking)
              : _AllCentresList(booking: booking),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: AppColors.n0, border: Border(top: BorderSide(color: AppColors.n100))),
          child: Row(
            children: [
              Expanded(child: EcoButton(label: '← Back', variant: EcoButtonVariant.outline, pill: true, fullWidth: true, onPressed: widget.onBack)),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: EcoButton(label: 'Continue →', pill: true, fullWidth: true, onPressed: booking.canProceedFromCentre ? widget.onNext : null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({super.key, required this.label, required this.selected, required this.onSelected});

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

/// Pickup Available tab — UNCHANGED behaviour from before this feature:
/// same `CentresResult`/`EligibleCentre` data, same selection rule, same
/// empty/error states.
class _PickupAvailableList extends StatelessWidget {
  const _PickupAvailableList({required this.booking});

  final PickupBookingProvider booking;

  @override
  Widget build(BuildContext context) {
    return AsyncStateView<CentresResult>(
      isLoading: booking.isLoadingCentres,
      error: booking.centresError,
      data: booking.centresResult,
      isEmpty: booking.centresResult?.centres.isEmpty ?? false,
      emptyMessage: 'No recycling centres are currently available.',
      emptyIcon: Icons.storefront_outlined,
      onRetry: () => context.read<PickupBookingProvider>().loadCentres(),
      builder: (context, result) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (result.message != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(AppRadii.r12), border: Border.all(color: const Color(0xFFF5D080))),
              child: Text(result.message!, style: const TextStyle(fontSize: 12, color: Color(0xFF7B4F00))),
            ),
            const SizedBox(height: 14),
          ],
          for (final centre in result.centres) ...[
            _CentreCard(
              centre: centre,
              selected: booking.selectedCentre?.id == centre.id,
              onTap: centre.eligible ? () => booking.selectCentre(centre) : null,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

/// All Centres tab — real nearby-centre DISCOVERY, including external
/// Google-Places-discovered businesses. Never selectable: tapping any card
/// here only opens its detail screen (view address/phone/website/Google
/// Maps), it never calls `booking.selectCentre()` — see this file's
/// top-level docblock for why that's the actual safety boundary.
class _AllCentresList extends StatefulWidget {
  const _AllCentresList({required this.booking});

  final PickupBookingProvider booking;

  @override
  State<_AllCentresList> createState() => _AllCentresListState();
}

class _AllCentresListState extends State<_AllCentresList> {
  @override
  void initState() {
    super.initState();
    if (widget.booking.nearbyCentres.isEmpty && !widget.booking.isLoadingNearby) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.booking.loadNearbyCentres());
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return AsyncStateView<List<NearbyRecyclingCentre>>(
      isLoading: booking.isLoadingNearby,
      error: booking.nearbyError,
      data: booking.nearbyCentres,
      isEmpty: booking.nearbyCentres.isEmpty,
      emptyMessage: 'No recycling centres found nearby.',
      emptyIcon: Icons.storefront_outlined,
      onRetry: booking.loadNearbyCentres,
      builder: (context, centres) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
            child: const Text(
              'These are all the real recycling centres we could find nearby. Only centres marked "Pickup available" can be selected for an EcoXchange pickup.',
              style: TextStyle(fontSize: 11, color: AppColors.n600, height: 1.3),
            ),
          ),
          const SizedBox(height: 14),
          for (final centre in centres) ...[
            _ExternalCentreCard(centre: centre),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _ExternalCentreCard extends StatelessWidget {
  const _ExternalCentreCard({required this.centre});

  final NearbyRecyclingCentre centre;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('all-centre-card-${centre.id}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecyclingCentreDetailScreen.fromNearby(centre: centre)),
        ),
        borderRadius: BorderRadius.circular(AppRadii.r16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.n0,
            borderRadius: BorderRadius.circular(AppRadii.r16),
            border: Border.all(color: AppColors.n100, width: 1.5),
            boxShadow: AppShadows.sh1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: centre.pickupSupported ? AppColors.green50 : AppColors.n100, borderRadius: BorderRadius.circular(AppRadii.r12)),
                child: Icon(Icons.storefront_outlined, color: centre.pickupSupported ? AppColors.green600 : AppColors.n400, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(centre.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.n800)),
                    if (centre.address != null) Text(centre.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                    if (centre.distanceLabel.isNotEmpty) Text('📍 ${centre.distanceLabel}', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                    const SizedBox(height: 6),
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
              ),
              const Icon(Icons.chevron_right, color: AppColors.n300),
            ],
          ),
        ),
      ),
    );
  }
}

class _CentreCard extends StatelessWidget {
  const _CentreCard({required this.centre, required this.selected, required this.onTap});

  final EligibleCentre centre;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !centre.eligible;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.r16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: disabled ? AppColors.n50 : (selected ? AppColors.green50 : AppColors.n0),
            borderRadius: BorderRadius.circular(AppRadii.r16),
            border: Border.all(color: selected ? AppColors.green400 : AppColors.n100, width: selected ? 2 : 1.5),
            boxShadow: disabled ? null : AppShadows.sh1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: disabled ? AppColors.n100 : AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
                    child: Icon(Icons.storefront_outlined, color: disabled ? AppColors.n400 : AppColors.green600, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(centre.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: disabled ? AppColors.n400 : AppColors.n800))),
                            if (centre.recommended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(AppRadii.rFull)),
                                child: const Text('RECOMMENDED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.green700)),
                              ),
                            ],
                          ],
                        ),
                        if (centre.address != null) Text(centre.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                        if (centre.distanceLabel != null) Text('📍 ${centre.distanceLabel}', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                      ],
                    ),
                  ),
                  if (!disabled)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.green500 : AppColors.n200),
                      child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (disabled)
                Text('Doesn\'t accept: ${centre.missingItems.join(', ')}', style: const TextStyle(fontSize: 11, color: AppColors.red))
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated reward', style: TextStyle(fontSize: 12, color: AppColors.n500)),
                    Text('RM ${centre.estimatedReward.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.green600)),
                  ],
                ),
                if (centre.rewardChangeNote != null) ...[
                  const SizedBox(height: 4),
                  Text(centre.rewardChangeNote!, style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
