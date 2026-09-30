import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/async_state_view.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../data/models/pickup_booking.dart';
import '../../providers/pickup_booking_provider.dart';

/// EcoXchange Mobile — Pickup Booking Step 3 (Stage 3). Real eligible
/// centres only (`POST /customer/pickup/centres`), reusing the card visual
/// language from the Recycling Centres tab. `distance_label`/`recommended`
/// are genuine server fields (`PickupFeasibilityService::
/// findEligibleCentres()`) — never a client-computed "nearest"; no star
/// rating/ETA is shown because the API returns neither.
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
        Expanded(
          child: AsyncStateView<CentresResult>(
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
          ),
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
