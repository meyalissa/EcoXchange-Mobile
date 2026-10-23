import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../../../core/widgets/eco_card.dart';
import '../../../data/models/ai_scan_result.dart';
import '../../providers/ai_scan_provider.dart';
import '../../widgets/scan_quantity_line.dart';

/// EcoXchange Mobile — review screen for an EXPERIMENTAL multi-object AI scan
/// (`POST /customer/pickup/detect`, or its stored read-back).
///
/// Lists every detected object — the detector only ever says `bottle`; the
/// material shown is EfficientNet-B0's classification of that object's crop,
/// never inferred from the detector label. Objects Laravel could not resolve
/// to an item (unsupported or unclassified material) are marked for manual
/// review and are NOT counted. Then the AI-SUGGESTED quantity per resolved
/// item, with a stepper so the user can correct it. No weight or reward is
/// shown or computed here: the confirmed quantities go to the booking flow,
/// where Laravel calculates both.
class MultiObjectResultView extends StatelessWidget {
  const MultiObjectResultView({super.key, required this.imageBytes, this.imageUrl, required this.onContinue, required this.onChooseManually, required this.onScanAnother});

  /// The photo taken in this session; null for a restored result, which then
  /// shows [imageUrl] (the server copy of the same upload). Bytes, not a
  /// file path — `Image.file`/`dart:io.File` are not supported on Flutter
  /// Web (see scan_classify_screen.dart's `_ScanPhoto` docblock).
  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onContinue;

  /// Multi-object: add a catalogue item the AI didn't count.
  final VoidCallback onChooseManually;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<AIScanProvider>();
    final result = scan.scanResult!;

    if (result.detections.isEmpty) {
      return _NoObjectsView(imageBytes: imageBytes, imageUrl: imageUrl, onChooseManually: onChooseManually, onScanAnother: onScanAnother);
    }

    final counted = result.resolvedDetections.length;
    final review = result.reviewDetections.length;
    final total = scan.totalReviewedQuantity;

    // Task 2 — standardized bottom actions: same split as the single-object
    // _ConfirmedView — scrollable content ends with "Add an Item Manually"
    // (right after the confirm-quantities list), and Continue/Scan Another
    // Photo live in their own fixed bottom action area, the same bordered-
    // container pattern MultiImageScanScreen's bottom bar already uses.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: _ScrollableContent(scan: scan, result: result, imageBytes: imageBytes, imageUrl: imageUrl, counted: counted, review: review, onChooseManually: onChooseManually),
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
              EcoButton(key: const Key('ai-multi-continue'), label: total > 0 ? 'Continue with $total item${total == 1 ? '' : 's'}' : 'Set at least 1 item', icon: Icons.local_shipping_outlined, fullWidth: true, pill: true, onPressed: total > 0 ? onContinue : null),
              const SizedBox(height: 10),
              EcoButton(label: 'Scan Another Photo', variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onScanAnother),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({required this.scan, required this.result, required this.imageBytes, required this.imageUrl, required this.counted, required this.review, required this.onChooseManually});

  final AIScanProvider scan;
  final AIScanResult result;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final int counted;
  final int review;
  final VoidCallback onChooseManually;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scan.isRestoredResult) ...[const _Notice(key: Key('ai-restored-notice'), icon: Icons.history, text: 'Showing your last scan, saved on EcoXchange. The AI was not run again.'), const SizedBox(height: 12)],
          _DetectionImage(imageBytes: imageBytes, imageUrl: imageUrl, result: result),
          const SizedBox(height: 16),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Pill(label: 'AI DETECTED OBJECTS'),
                    const Spacer(),
                    Text(
                      'Detected: ${result.totalDetected} object${result.totalDetected == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.n500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final detection in result.detections) ...[if (detection != result.detections.first) const Divider(height: 1, color: AppColors.n100), _DetectionRow(detection: detection)],
                if (review > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$counted counted · $review need${review == 1 ? 's' : ''} manual review',
                    key: const Key('ai-review-count'),
                    style: const TextStyle(fontSize: 12, color: AppColors.n500),
                  ),
                ],
              ],
            ),
          ),
          if (result.needsManualReview) ...[const SizedBox(height: 12), const _Notice(key: Key('ai-manual-review-notice'), icon: Icons.rate_review_outlined, text: 'Some objects need your review. They are not counted — add the correct item yourself if needed.', warning: true)],
          const SizedBox(height: 12),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm quantities',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800),
                ),
                const SizedBox(height: 4),
                const Text('Counted from your photo by AI — a suggestion, not a guarantee. Check each number and correct it if needed.', style: TextStyle(fontSize: 12, color: AppColors.n500, height: 1.4)),
                if (result.lines.isEmpty && scan.manualItems.isEmpty) ...[const SizedBox(height: 12), const Text('None of the detected objects could be counted as a supported item.', style: TextStyle(fontSize: 13, color: AppColors.n600))],
                for (final line in result.lines) ...[const SizedBox(height: 10), const Divider(height: 1, color: AppColors.n100), const SizedBox(height: 10), ScanQuantityLine(item: line.item!)],
                for (final item in scan.manualItems) ...[const SizedBox(height: 10), const Divider(height: 1, color: AppColors.n100), const SizedBox(height: 10), ScanQuantityLine(item: item)],
                for (final material in result.unresolvedMaterials) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.n100),
                  const SizedBox(height: 10),
                  Text(
                    '${_humanise(material.aiLabel)} × ${material.suggestedQuantity} — not available on EcoXchange, not counted',
                    key: Key('ai-unresolved-${material.aiLabel}'),
                    style: const TextStyle(fontSize: 12, color: AppColors.n500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Final weight and reward are calculated by EcoXchange from the quantities you confirm.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.n500, height: 1.4),
          ),
          const SizedBox(height: 16),
          EcoButton(key: const Key('ai-multi-add-item'), label: 'Add an Item Manually', variant: EcoButtonVariant.outline, fullWidth: true, pill: true, onPressed: onChooseManually),
        ],
      ),
    );
  }
}

String _humanise(String label) {
  final words = label.replaceAll('_', ' ').trim();
  return words.isEmpty ? label : words[0].toUpperCase() + words.substring(1);
}

String _pct(double value) => '${(value * 100).toStringAsFixed(0)}%';

String _reviewReason(AIDetectedObject d) {
  if (d.itemStatus == AIItemStatus.unresolved) return 'Not available on EcoXchange · needs manual review';
  return switch (d.unclassifiedReason) {
    'low_classification_confidence' => 'Material unclear · needs manual review',
    'classification_error' => 'Material could not be classified · needs manual review',
    _ => 'Unclassified · needs manual review',
  };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.rFull)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green700),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text, this.warning = false});

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final fg = warning ? AppColors.n800 : AppColors.green700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: warning ? AppColors.goldLight : AppColors.green50, borderRadius: BorderRadius.circular(AppRadii.r12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: warning ? AppColors.gold : AppColors.green600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: fg, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _DetectionRow extends StatelessWidget {
  const _DetectionRow({required this.detection});

  final AIDetectedObject detection;

  @override
  Widget build(BuildContext context) {
    final resolved = detection.isResolved;
    // Material comes ONLY from the classifier; the generic detector label is
    // shown separately and never turned into a material.
    final material = detection.item?.name ?? (detection.aiLabel != null ? _humanise(detection.aiLabel!) : 'Unclassified');

    return Padding(
      key: Key('ai-detection-${detection.index}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 26,
            width: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: resolved ? AppColors.green100 : AppColors.goldLight, shape: BoxShape.circle),
            child: Text(
              '${detection.index}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: resolved ? AppColors.green700 : AppColors.gold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Object ${detection.index} · detected as "${detection.detectorLabel}" (${_pct(detection.detectorConfidence)})', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                Text(
                  material,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: resolved ? AppColors.n800 : AppColors.n500),
                ),
                if (detection.classificationConfidence != null) Text('Material confidence: ${_pct(detection.classificationConfidence!)}', style: const TextStyle(fontSize: 11, color: AppColors.n500)),
                if (!resolved)
                  Text(
                    _reviewReason(detection),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _photo({Uint8List? imageBytes, String? imageUrl, double? height, BoxFit fit = BoxFit.cover}) {
  if (imageBytes != null) {
    return Image.memory(
      imageBytes,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => Container(
        height: height ?? 200,
        color: AppColors.n100,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.n400),
      ),
    );
  }
  if (imageUrl != null) {
    return AppNetworkImage(
      url: imageUrl,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => Container(height: height ?? 200, color: AppColors.n100),
    );
  }
  return const SizedBox.shrink();
}

/// The photo with each detection's box drawn on top. The server's boxes are
/// in original-image pixels, so they are scaled by the reported image size.
class _DetectionImage extends StatelessWidget {
  const _DetectionImage({required this.imageBytes, required this.imageUrl, required this.result});

  final Uint8List? imageBytes;
  final String? imageUrl;
  final AIScanResult result;

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null && imageUrl == null) return const SizedBox.shrink();
    final w = result.imageWidth;
    final h = result.imageHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.r16),
        child: _photo(imageBytes: imageBytes, imageUrl: imageUrl, height: 220),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Center(
        child: AspectRatio(
          aspectRatio: w / h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _photo(imageBytes: imageBytes, imageUrl: imageUrl, fit: BoxFit.fill),
                CustomPaint(key: const Key('ai-detection-overlay'), painter: _DetectionBoxPainter(result.detections, w.toDouble(), h.toDouble())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectionBoxPainter extends CustomPainter {
  _DetectionBoxPainter(this.detections, this.imageWidth, this.imageHeight);

  final List<AIDetectedObject> detections;
  final double imageWidth;
  final double imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / imageWidth;
    final sy = size.height / imageHeight;
    for (final d in detections) {
      final color = d.isResolved ? AppColors.green400 : AppColors.gold;
      final rect = Rect.fromLTWH(d.boundingBox.x * sx, d.boundingBox.y * sy, d.boundingBox.width * sx, d.boundingBox.height * sy);
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: ' ${d.index} ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.n0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, label.width, label.height), Paint()..color = color);
      label.paint(canvas, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(_DetectionBoxPainter oldDelegate) => oldDelegate.detections != detections;
}

class _NoObjectsView extends StatelessWidget {
  const _NoObjectsView({required this.imageBytes, required this.imageUrl, required this.onChooseManually, required this.onScanAnother});

  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onChooseManually;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (imageBytes != null || imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: _photo(imageBytes: imageBytes, imageUrl: imageUrl, height: 200),
          ),
        const SizedBox(height: 16),
        const EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.n500),
                  SizedBox(width: 8),
                  Text(
                    'No Items Detected',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.n800),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'The AI couldn\'t find any bottles in this photo. Try another photo with the items '
                'clearly visible, or choose the item yourself.',
                style: TextStyle(fontSize: 13, color: AppColors.n600, height: 1.5),
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
