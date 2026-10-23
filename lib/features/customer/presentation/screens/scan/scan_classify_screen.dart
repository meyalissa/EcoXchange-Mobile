import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/eco_app_bar.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../../../core/widgets/eco_card.dart';
import '../../../data/models/ai_classification.dart';
import '../../../data/models/item.dart';
import '../../../data/pending_detection_store.dart';
import '../../../data/repositories/ai_scan_repository.dart';
import '../../../data/repositories/customer_catalogue_repository.dart';
import '../../../data/repositories/customer_pickup_booking_repository.dart';
import '../../providers/ai_scan_provider.dart';
import '../../providers/item_catalogue_provider.dart';
import '../../providers/multi_image_scan_session_provider.dart';
import '../../providers/pickup_booking_provider.dart' show PrefillItemQuantity;
import '../../widgets/quantity_stepper.dart';
import '../../widgets/scan_quantity_line.dart';
import '../booking/pickup_booking_screen.dart';
import 'multi_object_result_view.dart';

/// EcoXchange Mobile — Stage 4.6 AI Scan & Classify.
///
/// Real pipeline only: Flutter -> Laravel (`POST /customer/pickup/image`
/// then `POST /customer/pickup/classify`, Stage 4.5) -> the actual
/// EfficientNet-B0 service (Stage 4.4) -> a real prediction. This screen
/// never shows a fabricated result while "loading" — the loading state
/// shows nothing but a spinner until the real response arrives.
///
/// Single pushed screen with an internal state switch, the same pattern
/// `PickupBookingScreen`/`CustomerHomeScreen` already use, rather than a
/// new navigation approach.
///
/// [onRoundComplete] (Part C — multi-image scanning) is how this SAME,
/// otherwise-unchanged single-photo screen plugs into a multi-image scan
/// session (`MultiImageScanScreen`): when provided, a completed scan pops
/// its real [ScanRoundResult] back to the caller instead of pushing
/// `PickupBookingScreen` directly, so the session screen can accumulate
/// several rounds before handing ALL of them to the booking flow together.
/// Null (the default) keeps today's exact standalone behaviour — a
/// single-image scan is simply a session with one round, never a
/// separately-maintained code path.
class ScanClassifyScreen extends StatelessWidget {
  const ScanClassifyScreen({super.key, this.scanRepository, this.detectionRepository, this.pendingStore, this.onRoundComplete});

  /// The single-object analysis. Null = the live classifier
  /// ([ClassifierScanRepository], `POST /customer/pickup/classify`).
  final AIScanRepository? scanRepository;

  /// The EXPERIMENTAL multi-object analysis. Null = the live detector
  /// ([DetectionScanRepository], `POST /customer/pickup/detect`).
  final AIDetectionRepository? detectionRepository;

  /// Where the last unfinished multi-object scan is remembered. Null = device
  /// storage ([SecurePendingDetectionStore]).
  final PendingDetectionStore? pendingStore;

  /// See the class docblock. Null = standalone (push to booking directly).
  final void Function(ScanRoundResult)? onRoundComplete;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = AIScanProvider(context.read<CustomerPickupBookingRepository>(), scanRepository: scanRepository, detectionRepository: detectionRepository, pendingStore: pendingStore);
        // A recreated STANDALONE screen reads back the last unfinished
        // multi-object scan (GET .../detect/{scanLog}) instead of running
        // the AI again — e.g. the app was restarted mid-scan. Only for the
        // standalone entry point: every round WITHIN a multi-image session
        // (onRoundComplete != null, i.e. "Add Another Photo") must always
        // start from a genuinely empty picker, never silently resume an
        // earlier, already-confirmed round's result (the real bug this
        // fixes — see AIScanProvider.forgetConfirmedScan()'s docblock).
        if (onRoundComplete == null) {
          provider.resumePendingDetection();
        }
        return provider;
      },
      child: _ScanClassifyView(onRoundComplete: onRoundComplete),
    );
  }
}

class _ScanClassifyView extends StatelessWidget {
  const _ScanClassifyView({this.onRoundComplete});

  final void Function(ScanRoundResult)? onRoundComplete;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    await context.read<AIScanProvider>().pickImage(source);
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(context: context, backgroundColor: Colors.transparent, builder: (_) => const _PhotoSourceSheet());
    if (source == null || !context.mounted) return;
    await _pickImage(context, source);
  }

  Future<void> _chooseManually(BuildContext context) async {
    final selection = await Navigator.of(context).push<PrefillItemQuantity>(MaterialPageRoute(builder: (_) => const _ManualItemPickerScreen()));
    if (selection != null && context.mounted) {
      context.read<AIScanProvider>().confirmManualItem(selection.item, quantity: selection.quantity);
    }
  }

  /// "Add an Item Manually" (Task 2): add a real catalogue item the AI
  /// didn't count or detect at all — for an object marked for manual
  /// review, a mixed-material photo the AI only partly got right, or a
  /// single-object confirmation that's missing a second item. Keeps
  /// whatever AI result already exists; never requires a new photo or a
  /// second AI inference.
  Future<void> _addItemManually(BuildContext context) async {
    final selection = await Navigator.of(context).push<PrefillItemQuantity>(MaterialPageRoute(builder: (_) => const _ManualItemPickerScreen()));
    if (selection != null && context.mounted) {
      context.read<AIScanProvider>().addManualItem(selection.item, quantity: selection.quantity);
    }
  }

  void _continueToBooking(BuildContext context) {
    final scan = context.read<AIScanProvider>();
    final item = scan.confirmedItem;
    final scanLogId = scan.scanLogId;
    if (item == null) return;

    // This scan is now confirmed/handed off — no longer "unfinished", so a
    // LATER fresh scan (standalone or another multi-image round) must never
    // read it back via resumePendingDetection(). See that method's fix note.
    scan.forgetConfirmedScan();

    // Task 2: the confirmed item plus anything added via "Add an Item
    // Manually" on this SAME photo — reviewedQuantities already tracks
    // both uniformly (confirmAiResult's/confirmManualItem's item always
    // has a quantity>0 entry; see AIScanProvider's docblocks), so this is
    // never just the single originally-confirmed item once more have been
    // added. The single-line fallback only matters for a theoretical empty
    // result and keeps prior behaviour for the common single-item case.
    final quantities = scan.reviewedQuantities.isNotEmpty ? scan.reviewedQuantities : [PrefillItemQuantity(item: item, quantity: 1)];

    if (onRoundComplete != null) {
      // scanLogId is always non-null once confirmedItem is set — both are
      // only ever reached after a real upload/classify completed.
      //
      // onRoundComplete itself already pops this screen (it hands the round
      // back to the awaited `push<ScanRoundResult>()` in
      // MultiImageScanScreen._scanAnotherPhoto, which only resolves once
      // popped) — a SEPARATE `Navigator.pop()` here used to run right after
      // it and pop a SECOND route (the caller's own MultiImageScanScreen),
      // which is the real root cause a live Chrome run confirmed: tapping
      // "Continue" silently left two screens behind instead of one, landing
      // the user wherever that happened to be instead of the booking flow
      // MultiImageScanScreen._scanAnotherPhoto immediately opens once the
      // round lands back on it. Never add a pop call here again.
      onRoundComplete!(ScanRoundResult(scanLogId: scanLogId!, imageUrl: scan.uploadedImageUrl, quantities: quantities));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupBookingScreen(prefillQuantities: quantities, prefillScanLogId: scanLogId, prefillImageUrl: scan.uploadedImageUrl, initialStep: 1),
      ),
    );
  }

  /// Multi-object hand-off: every reviewed line (AI-suggested, possibly
  /// user-corrected) is preselected in the booking flow, where Laravel
  /// computes weight and reward from these quantities.
  void _continueWithReviewedQuantities(BuildContext context) {
    final scan = context.read<AIScanProvider>();
    final lines = scan.reviewedQuantities;
    final scanLogId = scan.scanLogId;
    if (lines.isEmpty) return;

    // See the matching comment in _continueToBooking.
    scan.forgetConfirmedScan();

    if (onRoundComplete != null) {
      // See the matching comment in _continueToBooking: onRoundComplete
      // already pops this screen on its own — no separate pop here.
      onRoundComplete!(ScanRoundResult(scanLogId: scanLogId!, imageUrl: scan.uploadedImageUrl, quantities: lines));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupBookingScreen(prefillQuantities: lines, prefillScanLogId: scanLogId, prefillImageUrl: scan.uploadedImageUrl, initialStep: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<AIScanProvider>();

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Scan & Classify'),
      // Task 2 — standardized bottom actions: the two confirmation states
      // (a single confirmed item, or a multi-object result) each own a
      // fixed bottom action area for their primary/secondary buttons,
      // mirroring MultiImageScanScreen's own bottom-bar pattern (no shared
      // widget exists to reuse — this is an established inline convention
      // across several screens in this app, not a one-off). Every other
      // state (picking, previewing, loading, AI result, unsupported) is
      // unchanged: one `SafeArea` + `SingleChildScrollView`, its buttons
      // inline in the scrollable content as before — the task only asked
      // for the confirmation screens' bottom actions to be standardized.
      body: scan.confirmedItem != null
          ? SafeArea(
              child: _ConfirmedView(item: scan.confirmedItem!, imageBytes: scan.pickedImageBytes, onContinue: () => _continueToBooking(context), onScanAnother: () => context.read<AIScanProvider>().reset(), onAddItemManually: () => _addItemManually(context)),
            )
          : scan.isMultiObjectResult
          ? SafeArea(
              child: MultiObjectResultView(imageBytes: scan.pickedImageBytes, imageUrl: scan.pickedImageBytes == null ? scan.uploadedImageUrl : null, onContinue: () => _continueWithReviewedQuantities(context), onChooseManually: () => scan.scanResult!.detections.isNotEmpty ? _addItemManually(context) : _chooseManually(context), onScanAnother: () => context.read<AIScanProvider>().reset()),
            )
          : SafeArea(
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildOtherStates(context, scan)),
            ),
    );
  }

  Widget _buildOtherStates(BuildContext context, AIScanProvider scan) {
    if (scan.result != null) {
      return _ResultView(result: scan.result!, imageBytes: scan.pickedImageBytes, onConfirm: () => context.read<AIScanProvider>().confirmAiResult(), onReject: () => _chooseManually(context), fallbackNote: scan.fallbackNote);
    }

    if (scan.unsupportedAiLabel != null) {
      return _UnsupportedView(aiLabel: scan.unsupportedAiLabel!, confidence: scan.unsupportedConfidence, imageBytes: scan.pickedImageBytes, onChooseManually: () => _chooseManually(context), onScanAnother: () => context.read<AIScanProvider>().reset(), fallbackNote: scan.fallbackNote);
    }

    if (scan.isSubmitting) {
      // ONE loading message for the whole unified action (Part B) -- it
      // may do one AI call or two (detect, then a classify fallback)
      // depending on the photo, but from the user's side it's one tap.
      return const _LoadingView(title: 'Classifying with AI…', subtitle: 'Checking for multiple items, then the material — this can take a moment.');
    }

    if (scan.isRestoring) {
      return const _LoadingView(title: 'Loading your last scan…', subtitle: 'Reading the saved result — the AI is not run again.');
    }

    if (scan.pickedImageBytes != null) {
      return _PreviewView(imageBytes: scan.pickedImageBytes!, error: scan.error, onRetake: () => _showSourceSheet(context), onSubmit: () => context.read<AIScanProvider>().submit());
    }

    return _EmptyPickerView(onPick: () => _showSourceSheet(context));
  }
}

// ── Empty state: pick an image ──────────────────────────────────────────────

class _EmptyPickerView extends StatelessWidget {
  const _EmptyPickerView({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          height: 96,
          width: 96,
          decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
          child: const Icon(Icons.document_scanner_outlined, size: 44, color: AppColors.green600),
        ),
        const SizedBox(height: 20),
        const Text(
          'Scan a Recyclable Item',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.n800),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Take a photo or choose one from your gallery. Our AI will suggest what item it thinks this is — '
            'you always get to confirm or correct it before booking a pickup.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.n500, height: 1.5),
          ),
        ),
        const SizedBox(height: 28),
        EcoButton(label: 'Scan a Photo', icon: Icons.camera_alt_outlined, fullWidth: true, pill: true, onPressed: onPick),
      ],
    );
  }
}

// ── Shared photo preview — bytes, not a file path/Image.file ───────────────
//
// `Image.file`/`dart:io.File` are not supported on Flutter Web (confirmed:
// running this screen in Chrome threw "Assertion failed: Image.file is not
// supported on Flutter Web"). `XFile.readAsBytes()` (done once, in
// AIScanProvider.pickImage()) and `Image.memory()` both work identically on
// every platform, so every preview spot on this screen goes through this
// one widget — no `kIsWeb` branching anywhere. [errorBuilder] covers the
// remaining real failure mode: bytes that were read fine but don't decode
// as an image (corrupted/unsupported file) — shown as a clear local
// message rather than a crash.
class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto({required this.bytes, required this.height});

  final Uint8List bytes;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        width: double.infinity,
        color: AppColors.n100,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: AppColors.n400, size: 28),
            SizedBox(height: 6),
            Text('Couldn\'t display this photo', style: TextStyle(fontSize: 12, color: AppColors.n500)),
          ],
        ),
      ),
    );
  }
}

// ── Preview: about to submit ─────────────────────────────────────────────────

class _PreviewView extends StatelessWidget {
  const _PreviewView({required this.imageBytes, required this.error, required this.onRetake, required this.onSubmit});

  final Uint8List imageBytes;
  final Object? error;
  final VoidCallback onRetake;

  /// The ONE unified action (Part B) — runs object-counting first and
  /// falls back to whole-photo classification automatically when it isn't
  /// applicable; see `AIScanProvider.submit()`'s docblock.
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.r16),
          child: _ScanPhoto(bytes: imageBytes, height: 260),
        ),
        const SizedBox(height: 16),
        if (error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$error', style: const TextStyle(fontSize: 12, color: AppColors.red)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        EcoButton(key: const Key('ai-classify'), label: 'Classify with AI', icon: Icons.auto_awesome_outlined, fullWidth: true, pill: true, onPressed: onSubmit),
        const SizedBox(height: 4),
        const Text(
          'We\'ll check for multiple bottles first, then classify the material — one tap either way.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.n500, height: 1.4),
        ),
        const SizedBox(height: 10),
        EcoButton(label: 'Retake Photo', variant: EcoButtonVariant.ghost, fullWidth: true, pill: true, onPressed: onRetake),
      ],
    );
  }
}

// ── Loading ──────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.title = 'Classifying with AI…', this.subtitle = 'Running your photo through EcoXchange\'s AI model.'});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.green600),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.n500),
          ),
        ],
      ),
    );
  }
}

// ── Real AI result — always labelled as a suggestion, never a guarantee ────

// Shown only when the unified action (Part B) fell back from multi-item
// counting to a single whole-photo classification -- always an honest
// explanation of what actually ran, never hidden from the user.
class _FallbackNoteBanner extends StatelessWidget {
  const _FallbackNoteBanner({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ai-fallback-note'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.n50, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.n500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(note, style: const TextStyle(fontSize: 12, color: AppColors.n600, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.imageBytes, required this.onConfirm, required this.onReject, this.fallbackNote});

  final AIClassificationResult result;
  final Uint8List? imageBytes;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final String? fallbackNote;

  @override
  Widget build(BuildContext context) {
    final pct = (result.confidence * 100).toStringAsFixed(0);

    return Column(
      children: [
        if (fallbackNote != null) _FallbackNoteBanner(note: fallbackNote!),
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: _ScanPhoto(bytes: imageBytes!, height: 200),
          ),
        const SizedBox(height: 16),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.rFull)),
                    child: const Text(
                      'AI SUGGESTION',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green700),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Confidence: $pct%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.n500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.item.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.n800),
              ),
              if (result.item.category != null) ...[const SizedBox(height: 2), Text(result.item.category!, style: const TextStyle(fontSize: 13, color: AppColors.n500))],
              const SizedBox(height: 10),
              const Text('This is an AI classification, not a guarantee — please confirm it\'s correct before continuing.', style: TextStyle(fontSize: 12, color: AppColors.n500, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Is this correct?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n700),
        ),
        const SizedBox(height: 12),
        EcoButton(label: 'Yes, that\'s right', icon: Icons.check, fullWidth: true, pill: true, onPressed: onConfirm),
        const SizedBox(height: 10),
        EcoButton(label: 'No, choose manually', variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onReject),
      ],
    );
  }
}

// ── Real, honest "unsupported" outcome — never guessed into another item ───

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.aiLabel, required this.confidence, required this.imageBytes, required this.onChooseManually, required this.onScanAnother, this.fallbackNote});

  final String aiLabel;
  final double? confidence;
  final Uint8List? imageBytes;
  final VoidCallback onChooseManually;
  final VoidCallback onScanAnother;
  final String? fallbackNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (fallbackNote != null) _FallbackNoteBanner(note: fallbackNote!),
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: _ScanPhoto(bytes: imageBytes!, height: 200),
          ),
        const SizedBox(height: 16),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.n500),
                  SizedBox(width: 8),
                  Text(
                    'Not Currently Supported',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'The AI\'s best guess was "$aiLabel"'
                '${confidence != null ? ' (${(confidence! * 100).toStringAsFixed(0)}% confidence)' : ''}, '
                'but that item isn\'t currently supported by EcoXchange. You can still choose the correct item yourself.',
                style: const TextStyle(fontSize: 13, color: AppColors.n600, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EcoButton(label: 'Choose Item Manually', fullWidth: true, pill: true, onPressed: onChooseManually),
        const SizedBox(height: 10),
        EcoButton(label: 'Scan Another Photo', variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onScanAnother),
      ],
    );
  }
}

// ── Confirmed — ready to hand off to the real booking flow ─────────────────

/// Task 2 — this is "the existing Scan & Classify confirmation area" for a
/// single-object classify result (as opposed to [MultiObjectResultView],
/// the multi-object detector's own confirmation area, which already had
/// "Add an Item Manually"). A single photo can still contain mixed
/// materials the classifier only ever reports ONE guess for, so this view
/// now also lists anything added via [onAddItemManually] — reusing the
/// exact same [AIScanProvider.addManualItem]/[ScanQuantityLine] machinery
/// the multi-object screen uses, not a second, parallel one — and shows
/// [item]'s own quantity from the provider (not a hardcoded "1") since
/// adding the SAME item again merges into it rather than duplicating it.
class _ConfirmedView extends StatelessWidget {
  const _ConfirmedView({required this.item, required this.imageBytes, required this.onContinue, required this.onScanAnother, required this.onAddItemManually});

  final ItemModel item;
  final Uint8List? imageBytes;
  final VoidCallback onContinue;
  final VoidCallback onScanAnother;
  final VoidCallback onAddItemManually;

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<AIScanProvider>();
    final primaryQuantity = scan.quantityOf(item.id);
    final extras = scan.manualItems.where((m) => m.id != item.id).toList();
    final total = scan.totalReviewedQuantity;

    // Task 2 — standardized bottom actions: the scrollable content holds
    // the photo, the confirmed item(s) and "Add an Item Manually" (right
    // after that list, per the task); Continue/Scan Another Photo live in
    // their own fixed bottom action area below, the same bordered-container
    // pattern MultiImageScanScreen's bottom bar already uses, so Continue
    // stays reachable and visually dominant without the scrollable content
    // ever being obscured by it.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.r16),
                    child: _ScanPhoto(bytes: imageBytes!, height: 200),
                  ),
                const SizedBox(height: 16),
                EcoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.green600, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Item confirmed', style: TextStyle(fontSize: 12, color: AppColors.n500)),
                                Text(
                                  primaryQuantity > 1 ? '${item.name} × $primaryQuantity' : item.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      for (final extra in extras) ...[const SizedBox(height: 10), const Divider(height: 1, color: AppColors.n100), const SizedBox(height: 10), ScanQuantityLine(item: extra)],
                    ],
                  ),
                ),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Mixed materials from this one photo — $total item${total == 1 ? '' : 's'} total.', style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                  ),
                ],
                const SizedBox(height: 16),
                EcoButton(key: const Key('ai-single-add-item'), label: 'Add an Item Manually', icon: Icons.add_circle_outline, variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onAddItemManually),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: AppColors.n0,
            border: Border(top: BorderSide(color: AppColors.n100)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EcoButton(key: const Key('ai-single-continue'), label: total > 1 ? 'Continue with $total items' : 'Continue to Pickup Booking', icon: Icons.local_shipping_outlined, fullWidth: true, pill: true, onPressed: onContinue),
              const SizedBox(height: 10),
              EcoButton(label: 'Scan Another Photo', variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onScanAnother),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Camera / gallery source sheet — same pattern as the booking flow's ─────

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.green600),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green600),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manual item picker — the real catalogue, never a hardcoded list ────────
//
// Returns a [PrefillItemQuantity] (item + quantity), never a bare
// [ItemModel] — Task 2 requires an explicit quantity, chosen via
// [_ManualQuantitySheet], before the pick is treated as final. Tapping a
// catalogue row only opens that quantity sheet; the WHOLE picker screen
// only pops (with a real selection) once the user taps "Add Item" there —
// "Cancel" on the sheet just returns to the catalogue list, never
// discarding anything since nothing has been added yet at that point.

class _ManualItemPickerScreen extends StatelessWidget {
  const _ManualItemPickerScreen();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ItemCatalogueProvider(context.read<CustomerCatalogueRepository>())..load(),
      child: Scaffold(
        backgroundColor: AppColors.n50,
        appBar: const EcoAppBar(title: 'Choose the Correct Item'),
        body: Consumer<ItemCatalogueProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.green600));
            }
            if (provider.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${provider.error}', style: const TextStyle(color: AppColors.red)),
                ),
              );
            }
            final items = provider.items;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return EcoCard(
                  key: Key('manual-item-$i'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onTap: () async {
                    final selection = await showModalBottomSheet<PrefillItemQuantity>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _ManualQuantitySheet(item: item),
                    );
                    if (selection != null && context.mounted) {
                      Navigator.of(context).pop(selection);
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n800),
                            ),
                            if (item.category != null) Text(item.category!, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.n400),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Quantity picker — the second step of "Add an Item Manually" ───────────
//
// Task 2's required dialog shape: the item (already chosen from the real
// catalogue above), a quantity stepper (never free-text — a stepper can't
// produce a 0/negative/non-numeric value in the first place, which is
// simpler and just as valid as a text field with its own validation), and
// explicit Cancel/Add Item actions. [_submitted] guards a double-tap on
// "Add Item" from popping this sheet twice (the second pop would otherwise
// target whatever route is now on top — e.g. the catalogue list — closing
// it unintentionally) and from the caller ever receiving two selections
// for one tap.
class _ManualQuantitySheet extends StatefulWidget {
  const _ManualQuantitySheet({required this.item});

  final ItemModel item;

  @override
  State<_ManualQuantitySheet> createState() => _ManualQuantitySheetState();
}

class _ManualQuantitySheetState extends State<_ManualQuantitySheet> {
  int _quantity = 1;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(color: AppColors.n0, borderRadius: BorderRadius.circular(AppRadii.r20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800),
            ),
            if (widget.item.category != null) ...[const SizedBox(height: 2), Text(widget.item.category!, style: const TextStyle(fontSize: 12, color: AppColors.n500))],
            const SizedBox(height: 18),
            const Text(
              'QUANTITY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n500, letterSpacing: 0.4),
            ),
            const SizedBox(height: 8),
            Center(
              child: QuantityStepper(
                quantity: _quantity,
                // min: 1 — this sheet can never produce an invalid (0 or
                // negative) quantity; "remove" happens later via the
                // existing confirmed-item stepper, not here.
                min: 1,
                onDecrement: () => setState(() => _quantity -= 1),
                onIncrement: () => setState(() => _quantity += 1),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: EcoButton(key: const Key('manual-add-cancel'), label: 'Cancel', variant: EcoButtonVariant.outline, pill: true, fullWidth: true, onPressed: () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EcoButton(
                    key: const Key('manual-add-confirm'),
                    label: 'Add Item',
                    pill: true,
                    fullWidth: true,
                    onPressed: _submitted
                        ? null
                        : () {
                            setState(() => _submitted = true);
                            Navigator.of(context).pop(PrefillItemQuantity(item: widget.item, quantity: _quantity));
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
