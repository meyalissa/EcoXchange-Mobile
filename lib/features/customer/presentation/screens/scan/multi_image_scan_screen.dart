import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_app_bar.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../../../core/widgets/eco_card.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../data/pending_detection_store.dart';
import '../../../data/repositories/ai_scan_repository.dart';
import '../../providers/multi_image_scan_session_provider.dart';
import '../booking/pickup_booking_screen.dart';
import 'scan_classify_screen.dart';

/// EcoXchange Mobile — Part C: multiple photos in one scan session.
///
/// Each "Scan a Photo" tap pushes the EXISTING, otherwise-unchanged
/// [ScanClassifyScreen] for ONE photo (so single-object classify, the beta
/// multi-object-in-one-photo detector, the unsupported-item fallback and
/// the manual item picker all keep working exactly as before, per photo).
/// When that photo's result is confirmed, it pops back here as a real
/// [ScanRoundResult] and is added to the running list — a genuine single-
/// image scan is just the case where the user stops after one round, so
/// there is nothing separate to keep correct for it.
///
/// "Continue to Booking" hands every round's real `scan_log_id` and
/// combined confirmed quantities to [PickupBookingScreen] together, via
/// the booking provider's `prefillScanLogIds`/`prefillQuantities` — the
/// server still computes weight/reward itself from those quantities.
class MultiImageScanScreen extends StatelessWidget {
  const MultiImageScanScreen({
    super.key,
    this.onBookingComplete,
    this.scanRepository,
    this.detectionRepository,
    this.pendingStore,
  });

  /// Passed straight through to the [PickupBookingScreen] this session
  /// eventually hands off to, so a caller (e.g. the Pickup Hub/List "Request
  /// New Pickup" entry point) can still refresh itself after a booking made
  /// through this scan-first flow completes — see that screen's docblock.
  final VoidCallback? onBookingComplete;

  /// Test-only seams, forwarded unchanged to every [ScanClassifyScreen] this
  /// screen pushes (see that screen's own docblock) — null in production,
  /// letting widget tests drive a real scan round, including the real
  /// "Continue" tap, without a real AI service or `image_picker` platform
  /// channel.
  final AIScanRepository? scanRepository;
  final AIDetectionRepository? detectionRepository;
  final PendingDetectionStore? pendingStore;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MultiImageScanSessionProvider(),
      child: _MultiImageScanView(
        onBookingComplete: onBookingComplete,
        scanRepository: scanRepository,
        detectionRepository: detectionRepository,
        pendingStore: pendingStore,
      ),
    );
  }
}

class _MultiImageScanView extends StatefulWidget {
  const _MultiImageScanView({
    this.onBookingComplete,
    this.scanRepository,
    this.detectionRepository,
    this.pendingStore,
  });

  final VoidCallback? onBookingComplete;
  final AIScanRepository? scanRepository;
  final AIDetectionRepository? detectionRepository;
  final PendingDetectionStore? pendingStore;

  @override
  State<_MultiImageScanView> createState() => _MultiImageScanViewState();
}

class _MultiImageScanViewState extends State<_MultiImageScanView> {
  VoidCallback? get onBookingComplete => widget.onBookingComplete;
  AIScanRepository? get scanRepository => widget.scanRepository;
  AIDetectionRepository? get detectionRepository => widget.detectionRepository;
  PendingDetectionStore? get pendingStore => widget.pendingStore;

  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    // Task 1: "AI Scan" and "Request Pickup" both land here with an empty
    // session (no photo scanned yet) — rather than making the user tap
    // "Scan a Photo" on this screen's own empty state first, open the
    // existing Scan & Classify picker immediately, exactly as if they had
    // tapped it themselves. This screen (and its session) still exist
    // underneath — nothing new is created, no route is duplicated — so a
    // session that already has a round (e.g. the user backed out of
    // booking and returned here) is left exactly as it is: the auto-open
    // only ever fires for a genuinely empty, just-opened session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoStarted || !mounted) return;
      final session = context.read<MultiImageScanSessionProvider>();
      if (session.isEmpty) {
        _autoStarted = true;
        _scanAnotherPhoto(context);
      }
    });
  }

  /// Scans one round and returns to THIS screen's own summary — every
  /// round, including the first, behaves identically (the "standardize
  /// navigation" fix): no round silently skips the summary and jumps
  /// straight to booking. A confirmed round never re-triggers the empty-
  /// session auto-open in [initState] either, since [_autoStarted] is
  /// already true and `session.isEmpty` is false by the time this returns.
  ///
  /// (History: an earlier version special-cased the FIRST round to push
  /// booking immediately, to avoid a confusing "it sent me back to AI
  /// Scan" feeling when this screen's own empty state was the first thing
  /// shown. That confusion no longer applies — [initState] now opens
  /// Scan & Classify immediately on a fresh session, so landing on this
  /// summary after confirming is an expected forward step, not a bounce
  /// back — and the special case made the first round behave visibly
  /// differently from every later one, which is the bug this fixes.)
  Future<void> _scanAnotherPhoto(BuildContext context) async {
    final session = context.read<MultiImageScanSessionProvider>();
    final result = await Navigator.of(context).push<ScanRoundResult>(
      MaterialPageRoute(
        builder: (_) => ScanClassifyScreen(
          scanRepository: scanRepository,
          detectionRepository: detectionRepository,
          pendingStore: pendingStore,
          onRoundComplete: (round) => Navigator.of(context).pop(round),
        ),
      ),
    );
    if (result == null) return;
    session.addRound(result);
  }

  void _continueToBooking(BuildContext context) {
    final session = context.read<MultiImageScanSessionProvider>();
    if (session.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupBookingScreen(
          prefillQuantities: session.combinedQuantities,
          prefillScanLogIds: session.scanLogIds,
          prefillImageUrl: session.representativeImageUrl,
          initialStep: 1,
          onBookingComplete: onBookingComplete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MultiImageScanSessionProvider>();

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Scan Multiple Items'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: session.isEmpty
                  ? _EmptySessionView(onScan: () => _scanAnotherPhoto(context))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '${session.roundCount} photo${session.roundCount == 1 ? '' : 's'} scanned',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n600),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < session.rounds.length; i++) ...[
                          _RoundCard(
                            key: Key('scan-round-$i'),
                            round: session.rounds[i],
                            onRemove: () => context.read<MultiImageScanSessionProvider>().removeRoundAt(i),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 10),
                        const Text('COMBINED SO FAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.n500, letterSpacing: 0.4)),
                        const SizedBox(height: 8),
                        EcoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final line in session.combinedQuantities)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(line.item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800))),
                                      Text('× ${line.quantity}', style: const TextStyle(fontSize: 13, color: AppColors.n500)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
            ),
            // Stacked full-width, not side-by-side: at half-width each,
            // "Add Another Photo" + its icon never fit — EcoButton's label
            // is a single, ellipsis-truncating line by design (shared by
            // every button in the app), so the fix is this screen's layout,
            // not EcoButton itself. Stacking also keeps "Continue" as the
            // visually dominant (lower, filled) action once it appears.
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(color: AppColors.n0, border: Border(top: BorderSide(color: AppColors.n100))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EcoButton(
                    label: session.isEmpty ? 'Scan a Photo' : 'Add Another Photo',
                    icon: session.isEmpty ? Icons.add_a_photo_outlined : Icons.photo_library_outlined,
                    variant: session.isEmpty ? EcoButtonVariant.primary : EcoButtonVariant.outline,
                    pill: true,
                    fullWidth: true,
                    onPressed: session.isFull ? null : () => _scanAnotherPhoto(context),
                  ),
                  if (!session.isEmpty) ...[
                    const SizedBox(height: 10),
                    EcoButton(
                      key: const Key('multi-scan-continue'),
                      label: 'Continue →',
                      icon: Icons.local_shipping_outlined,
                      pill: true,
                      fullWidth: true,
                      onPressed: () => _continueToBooking(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySessionView extends StatelessWidget {
  const _EmptySessionView({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
              child: const Icon(Icons.photo_library_outlined, size: 44, color: AppColors.green600),
            ),
            const SizedBox(height: 20),
            const Text('Scan One or More Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.n800)),
            const SizedBox(height: 8),
            const Text(
              'Scan a single photo, or keep adding photos for every recyclable you have — each one is classified '
              'by the AI and you confirm it before booking a pickup for all of them together.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.n500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({super.key, required this.round, required this.onRemove});

  final ScanRoundResult round;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final summary = round.quantities.map((l) => '${l.item.name} × ${l.quantity}').join(', ');

    final placeholder = Container(width: 52, height: 52, color: AppColors.n100, child: const Icon(Icons.image_outlined, color: AppColors.n400));

    return EcoCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r12),
            child: round.imageUrl != null
                ? AppNetworkImage(
                    url: round.imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : placeholder,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              summary.isEmpty ? 'No item confirmed' : summary,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.n400), onPressed: onRemove),
        ],
      ),
    );
  }
}
