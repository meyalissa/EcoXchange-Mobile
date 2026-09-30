import 'dart:io';

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
class ScanClassifyScreen extends StatelessWidget {
  const ScanClassifyScreen({super.key, this.scanRepository, this.detectionRepository, this.pendingStore});

  /// The single-object analysis. Null = the live classifier
  /// ([ClassifierScanRepository], `POST /customer/pickup/classify`).
  final AIScanRepository? scanRepository;

  /// The EXPERIMENTAL multi-object analysis. Null = the live detector
  /// ([DetectionScanRepository], `POST /customer/pickup/detect`).
  final AIDetectionRepository? detectionRepository;

  /// Where the last unfinished multi-object scan is remembered. Null = device
  /// storage ([SecurePendingDetectionStore]).
  final PendingDetectionStore? pendingStore;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // A recreated screen reads back the last unfinished multi-object scan
      // (GET .../detect/{scanLog}) instead of running the AI again.
      create: (context) => AIScanProvider(
        context.read<CustomerPickupBookingRepository>(),
        scanRepository: scanRepository,
        detectionRepository: detectionRepository,
        pendingStore: pendingStore,
      )..resumePendingDetection(),
      child: const _ScanClassifyView(),
    );
  }
}

class _ScanClassifyView extends StatelessWidget {
  const _ScanClassifyView();

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    await context.read<AIScanProvider>().pickImage(source);
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PhotoSourceSheet(),
    );
    if (source == null || !context.mounted) return;
    await _pickImage(context, source);
  }

  Future<void> _chooseManually(BuildContext context) async {
    final item = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(builder: (_) => const _ManualItemPickerScreen()),
    );
    if (item != null && context.mounted) {
      context.read<AIScanProvider>().confirmManualItem(item);
    }
  }

  /// Multi-object review: add a real catalogue item the AI didn't count
  /// (e.g. for an object marked for manual review). Keeps the AI result.
  Future<void> _addItemManually(BuildContext context) async {
    final item = await Navigator.of(context).push<ItemModel>(
      MaterialPageRoute(builder: (_) => const _ManualItemPickerScreen()),
    );
    if (item != null && context.mounted) {
      context.read<AIScanProvider>().addManualItem(item);
    }
  }

  void _continueToBooking(BuildContext context) {
    final scan = context.read<AIScanProvider>();
    final item = scan.confirmedItem;
    if (item == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupBookingScreen(
          prefillItem: item,
          prefillScanLogId: scan.scanLogId,
          prefillImageUrl: scan.uploadedImageUrl,
        ),
      ),
    );
  }

  /// Multi-object hand-off: every reviewed line (AI-suggested, possibly
  /// user-corrected) is preselected in the booking flow, where Laravel
  /// computes weight and reward from these quantities.
  void _continueWithReviewedQuantities(BuildContext context) {
    final scan = context.read<AIScanProvider>();
    final lines = scan.reviewedQuantities;
    if (lines.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickupBookingScreen(
          prefillQuantities: lines,
          prefillScanLogId: scan.scanLogId,
          prefillImageUrl: scan.uploadedImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<AIScanProvider>();

    return Scaffold(
      backgroundColor: AppColors.n50,
      appBar: const EcoAppBar(title: 'Scan & Classify'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildBody(context, scan),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AIScanProvider scan) {
    if (scan.confirmedItem != null) {
      return _ConfirmedView(
        item: scan.confirmedItem!,
        image: scan.pickedImage,
        onContinue: () => _continueToBooking(context),
        onScanAnother: () => context.read<AIScanProvider>().reset(),
      );
    }

    // Multi-object detector result (fresh, or read back after a restart).
    if (scan.isMultiObjectResult) {
      final hasObjects = scan.scanResult!.detections.isNotEmpty;
      return MultiObjectResultView(
        image: scan.pickedImage,
        imageUrl: scan.pickedImage == null ? scan.uploadedImageUrl : null,
        onContinue: () => _continueWithReviewedQuantities(context),
        onChooseManually: () => hasObjects ? _addItemManually(context) : _chooseManually(context),
        onScanAnother: () => context.read<AIScanProvider>().reset(),
      );
    }

    if (scan.result != null) {
      return _ResultView(
        result: scan.result!,
        image: scan.pickedImage,
        onConfirm: () => context.read<AIScanProvider>().confirmAiResult(),
        onReject: () => _chooseManually(context),
      );
    }

    if (scan.unsupportedAiLabel != null) {
      return _UnsupportedView(
        aiLabel: scan.unsupportedAiLabel!,
        confidence: scan.unsupportedConfidence,
        image: scan.pickedImage,
        onChooseManually: () => _chooseManually(context),
        onScanAnother: () => context.read<AIScanProvider>().reset(),
      );
    }

    if (scan.isSubmitting) {
      return scan.isMultiObjectRequest
          ? const _LoadingView(
              title: 'Detecting items with AI…',
              subtitle: 'Finding each bottle in your photo and classifying its material.',
            )
          : const _LoadingView();
    }

    if (scan.isRestoring) {
      return const _LoadingView(
        title: 'Loading your last scan…',
        subtitle: 'Reading the saved result — the AI is not run again.',
      );
    }

    if (scan.pickedImage != null) {
      return _PreviewView(
        image: scan.pickedImage!,
        error: scan.error,
        onRetake: () => _showSourceSheet(context),
        onSubmit: () => context.read<AIScanProvider>().submit(),
        onSubmitMultiObject: () => context.read<AIScanProvider>().submitMultiObject(),
      );
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
        const Text('Scan a Recyclable Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.n800)),
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

// ── Preview: about to submit ─────────────────────────────────────────────────

class _PreviewView extends StatelessWidget {
  const _PreviewView({
    required this.image,
    required this.error,
    required this.onRetake,
    required this.onSubmit,
    required this.onSubmitMultiObject,
  });

  final File image;
  final Object? error;
  final VoidCallback onRetake;
  final VoidCallback onSubmit;
  final VoidCallback onSubmitMultiObject;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.r16),
          child: Image.file(image, height: 260, width: double.infinity, fit: BoxFit.cover),
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
                Expanded(child: Text('$error', style: const TextStyle(fontSize: 12, color: AppColors.red))),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        EcoButton(label: 'Classify with AI', icon: Icons.auto_awesome_outlined, fullWidth: true, pill: true, onPressed: onSubmit),
        const SizedBox(height: 10),
        EcoButton(
          key: const Key('ai-detect-multiple'),
          label: 'Count Multiple Bottles (Beta)',
          icon: Icons.grid_view_outlined,
          variant: EcoButtonVariant.outline,
          fullWidth: true,
          pill: true,
          onPressed: onSubmitMultiObject,
        ),
        const SizedBox(height: 4),
        const Text(
          'Beta: finds each bottle in the photo and suggests how many of each material. You confirm the numbers.',
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
  const _LoadingView({
    this.title = 'Classifying with AI…',
    this.subtitle = 'Running your photo through EcoXchange\'s AI model.',
  });

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
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n700)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
        ],
      ),
    );
  }
}

// ── Real AI result — always labelled as a suggestion, never a guarantee ────

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.image, required this.onConfirm, required this.onReject});

  final AIClassificationResult result;
  final File? image;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pct = (result.confidence * 100).toStringAsFixed(0);

    return Column(
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: Image.file(image!, height: 200, width: double.infinity, fit: BoxFit.cover),
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
                    child: const Text('AI SUGGESTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green700)),
                  ),
                  const Spacer(),
                  Text('Confidence: $pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.n500)),
                ],
              ),
              const SizedBox(height: 12),
              Text(result.item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.n800)),
              if (result.item.category != null) ...[
                const SizedBox(height: 2),
                Text(result.item.category!, style: const TextStyle(fontSize: 13, color: AppColors.n500)),
              ],
              const SizedBox(height: 10),
              const Text(
                'This is an AI classification, not a guarantee — please confirm it\'s correct before continuing.',
                style: TextStyle(fontSize: 12, color: AppColors.n500, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Is this correct?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n700)),
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
  const _UnsupportedView({
    required this.aiLabel,
    required this.confidence,
    required this.image,
    required this.onChooseManually,
    required this.onScanAnother,
  });

  final String aiLabel;
  final double? confidence;
  final File? image;
  final VoidCallback onChooseManually;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: Image.file(image!, height: 200, width: double.infinity, fit: BoxFit.cover),
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
                  Text('Not Currently Supported', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800)),
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

class _ConfirmedView extends StatelessWidget {
  const _ConfirmedView({required this.item, required this.image, required this.onContinue, required this.onScanAnother});

  final ItemModel item;
  final File? image;
  final VoidCallback onContinue;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: Image.file(image!, height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        EcoCard(
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.green600, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Item confirmed', style: TextStyle(fontSize: 12, color: AppColors.n500)),
                    Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.n800)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        EcoButton(label: 'Continue to Pickup Booking', icon: Icons.local_shipping_outlined, fullWidth: true, pill: true, onPressed: onContinue),
        const SizedBox(height: 10),
        EcoButton(label: 'Scan Another Photo', variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onScanAnother),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onTap: () => Navigator.of(context).pop(item),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.n800)),
                            if (item.category != null)
                              Text(item.category!, style: const TextStyle(fontSize: 12, color: AppColors.n500)),
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
