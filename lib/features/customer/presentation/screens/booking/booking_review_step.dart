import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/async_state_view.dart';
import '../../../../../core/widgets/eco_button.dart';
import '../../../../../core/widgets/eco_card.dart';
import '../../../data/models/pickup_booking.dart';
import '../../providers/pickup_booking_provider.dart';
import '../../widgets/scan_photo_gallery.dart';
import 'pickup_booking_success_screen.dart';

/// EcoXchange Mobile — Pickup Booking Step 5 (Stage 3): real revalidation
/// (`POST /customer/pickup/review`) before an optional photo and the real
/// final submission (`POST /customer/pickup`). `ready_to_submit`/`reasons`
/// are the one real gate — this screen can never let a customer submit a
/// pickup the server itself says isn't ready, and never rewrites a
/// [ReviewReason.message] (already a complete, server-authored sentence).
class BookingReviewStep extends StatefulWidget {
  const BookingReviewStep({super.key, required this.onBack, this.onBookingComplete});

  final VoidCallback onBack;
  final VoidCallback? onBookingComplete;

  @override
  State<BookingReviewStep> createState() => _BookingReviewStepState();
}

class _BookingReviewStepState extends State<BookingReviewStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PickupBookingProvider>().loadReview());
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhotoSourceSheet(),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    } catch (_) {
      // Cancelled or the platform picker itself failed (e.g. no camera
      // app) — handled the same, honestly, as "nothing picked".
      return;
    }
    if (file == null || !mounted) return;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      // Could not read the picked file (corrupted/unsupported) — handled
      // the same, honestly, as "nothing picked"; no crash, no fake upload.
      return;
    }
    if (!mounted) return;

    final booking = context.read<PickupBookingProvider>();
    final ok = await booking.uploadImage(bytes, file.name);
    if (ok && mounted) {
      await booking.loadReview();
    }
  }

  Future<void> _removePhoto() async {
    final booking = context.read<PickupBookingProvider>();
    booking.clearImage();
    await booking.loadReview();
  }

  Future<void> _submit() async {
    final booking = context.read<PickupBookingProvider>();
    final pickup = await booking.submit();
    if (pickup != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PickupBookingSuccessScreen(pickup: pickup, onDone: widget.onBookingComplete)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PickupBookingProvider>();

    return Column(
      children: [
        Expanded(
          child: AsyncStateView<ReviewResult>(
            isLoading: booking.isReviewing,
            error: booking.reviewError,
            data: booking.reviewResult,
            onRetry: () => context.read<PickupBookingProvider>().loadReview(),
            builder: (context, review) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!review.readyToSubmit) _NotReadyBanner(reasons: review.reasons) else _ReadyBanner(review: review),
                const SizedBox(height: 14),
                EcoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green600, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      for (final item in review.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(child: Text('${item.name ?? 'Item'} × ${item.quantity}', style: const TextStyle(fontSize: 13, color: AppColors.n800))),
                              Text('${item.weightKg.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                            ],
                          ),
                        ),
                      const Divider(height: 18, color: AppColors.n100),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total weight', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n700)),
                          Text('${review.totalWeightKg.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.n800)),
                        ],
                      ),
                      if (review.feasibility?.estimatedReward != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated reward', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.n700)),
                            Text('RM ${review.feasibility!.estimatedReward!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.green600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                EcoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PICKUP DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green600, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      _DetailRow(icon: Icons.location_on_outlined, label: 'Address', value: review.address.formatted),
                      _DetailRow(icon: Icons.storefront_outlined, label: 'Centre', value: review.centre?.name ?? '—'),
                      if (booking.isPickupNow)
                        _DetailRow(icon: Icons.bolt_outlined, label: 'Pickup', value: 'As soon as possible')
                      else ...[
                        _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: booking.pickupDate != null ? _formatDate(booking.pickupDate!) : '—'),
                        _DetailRow(icon: Icons.access_time, label: 'Time', value: booking.pickupTimeLabel ?? '—'),
                      ],
                      if (booking.notes != null && booking.notes!.trim().isNotEmpty) _DetailRow(icon: Icons.notes, label: 'Notes', value: booking.notes!.trim()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                EcoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.images.isNotEmpty ? 'PHOTOS' : 'PHOTO (OPTIONAL)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green600, letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 10),
                      if (review.images.isNotEmpty)
                        // The real scan-session photos (Task 1) — read-only
                        // here; see ScanPhotoGallery's own docblock for why.
                        ScanPhotoGallery(images: review.images)
                      else ...[
                        if (booking.imageError != null) ...[
                          Text(booking.imageError!.message, style: const TextStyle(fontSize: 12, color: AppColors.red)),
                          const SizedBox(height: 8),
                        ],
                        if (booking.uploadedImageUrl != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadii.r12),
                                child: AppNetworkImage(url: booking.uploadedImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: booking.isUploadingImage ? null : _removePhoto,
                                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 16, color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: booking.isUploadingImage ? null : _pickPhoto,
                            icon: booking.isUploadingImage
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.add_a_photo_outlined, size: 18),
                            label: Text(booking.isUploadingImage ? 'Uploading…' : 'Add a Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green600,
                              side: const BorderSide(color: AppColors.green300, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r12)),
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (booking.submitError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(booking.submitError!.message, style: const TextStyle(fontSize: 12, color: AppColors.red))),
                      ],
                    ),
                  ),
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
                child: EcoButton(
                  label: 'Submit Pickup',
                  pill: true,
                  fullWidth: true,
                  loading: booking.isSubmitting,
                  onPressed: (booking.reviewResult?.readyToSubmit ?? false) && booking.canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _NotReadyBanner extends StatelessWidget {
  const _NotReadyBanner({required this.reasons});

  final List<ReviewReason> reasons;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(AppRadii.r16), border: Border.all(color: const Color(0xFFF5C6C0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: AppColors.red),
              SizedBox(width: 8),
              Text('Not Ready to Submit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 8),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${reason.message}', style: const TextStyle(fontSize: 12, color: AppColors.red)),
            ),
        ],
      ),
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  const _ReadyBanner({required this.review});

  final ReviewResult review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: AppColors.walletCardGradient, borderRadius: BorderRadius.circular(AppRadii.r16)),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Ready for Pickup — review the details below and submit.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.n400),
          const SizedBox(width: 10),
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.n500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.n800))),
        ],
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
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
