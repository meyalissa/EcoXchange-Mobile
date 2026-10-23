import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/models/pickup_booking.dart';

/// EcoXchange Mobile — compact gallery of every real photo in this pickup's
/// scan session (Task 1), fed by `ReviewResult.images` —
/// `POST /customer/pickup/review`'s own `images` array
/// (`PickupPreparationController::review()`), already returning one entry
/// per scan_log_id in this session. Nothing here re-derives or guesses
/// which photos belong to this pickup; it only renders what the server
/// already said.
///
/// Read-only by design: by the time a pickup reaches Review & Submit, its
/// scan session's photo-to-item attribution has already been flattened
/// into one combined quantity map (see `PickupBookingProvider`/
/// `MultiImageScanSessionProvider.combinedQuantities`) — there is no
/// reliable way left to know which confirmed item(s) came from which
/// specific photo, so removing an individual scan-session photo here could
/// silently invalidate an item the user already confirmed. Rather than
/// guess, these images are simply preserved and shown, exactly as Task 1's
/// own data-integrity note allows ("preserve those items safely"). The
/// pre-existing separate single "Add a Photo" control (for a pickup with no
/// scan session at all) is unaffected and keeps its own add/remove.
class ScanPhotoGallery extends StatefulWidget {
  const ScanPhotoGallery({super.key, required this.images, this.initialVisibleCount = 3});

  final List<ReviewImage> images;
  final int initialVisibleCount;

  @override
  State<ScanPhotoGallery> createState() => _ScanPhotoGalleryState();
}

class _ScanPhotoGalleryState extends State<ScanPhotoGallery> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) return const SizedBox.shrink();

    final hasMore = images.length > widget.initialVisibleCount;
    final visible = _expanded || !hasMore ? images : images.take(widget.initialVisibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${images.length} photo${images.length == 1 ? '' : 's'} from your scan',
          style: const TextStyle(fontSize: 12, color: AppColors.n500),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final image in visible)
              _Thumbnail(key: Key('scan-photo-${image.scanLogId}'), image: image, onTap: () => _openPreview(context, image)),
          ],
        ),
        if (hasMore) ...[
          const SizedBox(height: 10),
          InkWell(
            key: const Key('scan-gallery-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadii.r8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Show less' : 'View all (${images.length})',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.green700),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.green700),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openPreview(BuildContext context, ReviewImage image) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _PhotoPreviewDialog(image: image),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({super.key, required this.image, required this.onTap});

  final ReviewImage image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.r12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.r12),
        child: AppNetworkImage(
          url: image.imageUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 64,
            height: 64,
            color: AppColors.n100,
            child: const Icon(Icons.broken_image_outlined, color: AppColors.n400, size: 20),
          ),
        ),
      ),
    );
  }
}

/// A near-fullscreen preview — obvious close action via the visible X
/// button, tapping the dark backdrop, or the system back gesture (a
/// [Dialog] already pops on back by default).
class _PhotoPreviewDialog extends StatelessWidget {
  const _PhotoPreviewDialog({required this.image});

  final ReviewImage image;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r16),
            child: AppNetworkImage(
              url: image.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                height: 300,
                color: AppColors.n800,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.n0, size: 36),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('scan-photo-preview-close'),
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.close, size: 20, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
