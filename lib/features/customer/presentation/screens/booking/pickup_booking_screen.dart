import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_app_bar.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/customer_address_repository.dart';
import '../../../data/repositories/customer_catalogue_repository.dart';
import '../../../data/repositories/customer_pickup_booking_repository.dart';
import '../../../data/repositories/customer_recycling_centre_repository.dart';
import '../../providers/item_catalogue_provider.dart';
import '../../providers/pickup_booking_provider.dart';
import '../../widgets/booking_step_header.dart';
import 'booking_address_step.dart';
import 'booking_centre_step.dart';
import 'booking_items_step.dart';
import 'booking_review_step.dart';
import 'booking_schedule_step.dart';

/// EcoXchange Mobile — Customer Pickup Booking (Stage 3). A single pushed
/// screen that owns its own step index and swaps between 5 step widgets
/// directly (no nested per-step `Navigator.push`) — the same pattern
/// `CustomerHomeScreen` already uses for its own tabs (`IndexedStack` over
/// an internal index), reused here instead of inventing a second
/// navigation approach.
///
/// `PickupBookingProvider` (and a booking-local `ItemCatalogueProvider`
/// instance — the tab shell's own instance lives inside
/// `CustomerHomeScreen`'s `MultiProvider`, which this pushed route's
/// widget tree is NOT a descendant of, so a fresh instance is created here
/// exactly the way `CustomerHomeScreen` itself already constructs its 5
/// screen-level providers) are scoped to this screen's own lifetime via a
/// local `MultiProvider` — created fresh every time "Request New Pickup"
/// is tapped, and discarded (state cleanly gone, nothing to reset by hand)
/// the moment this screen is popped.
class PickupBookingScreen extends StatefulWidget {
  const PickupBookingScreen({
    super.key,
    this.onBookingComplete,
    this.prefillItem,
    this.prefillQuantities,
    this.prefillScanLogId,
    this.prefillImageUrl,
  });

  /// Called once, right before returning to the Pickups tab after a
  /// successful submission — lets the caller refresh its own already-
  /// loaded pickup list (the same cross-tab-callback pattern the Dashboard
  /// already uses for its "See All Items" action; see
  /// `CustomerHomeScreen`'s docblock) rather than this pushed flow reaching
  /// into a provider scope it isn't part of.
  final VoidCallback? onBookingComplete;

  /// Stage 4.6 — AI Scan & Classify hand-off. When set, the Items step
  /// opens with this item already selected (quantity 1, still fully
  /// editable) and, if [prefillScanLogId]/[prefillImageUrl] are also set,
  /// the Review step's optional photo is already the scanned image —
  /// reusing that one real upload rather than asking for a second photo.
  /// Both remain entirely optional; manual booking (Stage 3) passes none
  /// of these and behaves exactly as before.
  final ItemModel? prefillItem;

  /// Multi-object AI scan hand-off: the reviewed (AI-suggested, possibly
  /// user-corrected) quantity per item. Still fully editable in the Items step.
  final List<PrefillItemQuantity>? prefillQuantities;
  final int? prefillScanLogId;
  final String? prefillImageUrl;

  @override
  State<PickupBookingScreen> createState() => _PickupBookingScreenState();
}

class _PickupBookingScreenState extends State<PickupBookingScreen> {
  int _step = 0;

  static const _titles = ['Select Items', 'Pickup Address', 'Recycling Centre', 'Schedule Pickup', 'Review & Submit'];

  void _goToStep(int step) => setState(() => _step = step.clamp(0, 4));

  void _next() => _goToStep(_step + 1);

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      _goToStep(_step - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => PickupBookingProvider(
            context.read<CustomerPickupBookingRepository>(),
            context.read<CustomerAddressRepository>(),
            context.read<CustomerRecyclingCentreRepository>(),
            prefillItem: widget.prefillItem,
            prefillQuantities: widget.prefillQuantities,
            prefillScanLogId: widget.prefillScanLogId,
            prefillImageUrl: widget.prefillImageUrl,
          ),
        ),
        ChangeNotifierProvider(create: (context) => ItemCatalogueProvider(context.read<CustomerCatalogueRepository>())),
      ],
      child: PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.n50,
          appBar: EcoAppBar(
            title: _titles[_step],
            onBack: _back,
          ),
          body: Column(
            children: [
              BookingStepHeader(currentStep: _step),
              Expanded(
                child: switch (_step) {
                  0 => BookingItemsStep(onNext: _next),
                  1 => BookingAddressStep(onNext: _next, onBack: _back),
                  2 => BookingCentreStep(onNext: _next, onBack: _back),
                  3 => BookingScheduleStep(onNext: _next, onBack: _back),
                  _ => BookingReviewStep(onBack: _back, onBookingComplete: widget.onBookingComplete),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
