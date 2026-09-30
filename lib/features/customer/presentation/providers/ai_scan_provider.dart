import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/ai_classification.dart';
import '../../data/models/ai_scan_result.dart';
import '../../data/models/item.dart';
import '../../data/pending_detection_store.dart';
import '../../data/repositories/ai_scan_repository.dart';
import '../../data/repositories/customer_pickup_booking_repository.dart';
import 'pickup_booking_provider.dart';

/// EcoXchange Mobile — Stage 4.6 AI Scan & Classify state.
///
/// Flow: pick an image -> upload it (reuses the exact same
/// `POST /customer/pickup/image` endpoint the booking flow's optional
/// photo already uses — no second upload mechanism) -> classify it
/// (`POST /customer/pickup/classify`, Stage 4.5) -> show the REAL model
/// result -> the user confirms it or picks a different real, active item
/// from the catalogue. This provider never invents a prediction and never
/// silently falls back to a guessed item on any failure.
///
/// Deliberately holds NO pickup business logic (weight/reward/eligibility)
/// — [confirmedItem] is only ever handed off to [PickupBookingProvider] via
/// an explicit prefill, exactly the same real item-selection path manual
/// booking already uses (see booking_items_step.dart's `setQuantity`).
///
/// Two analysis paths, both on the same uploaded photo:
///   * [submit] — the live single-object classifier ([AIScanRepository],
///     default [ClassifierScanRepository]), unchanged.
///   * [submitMultiObject] — the EXPERIMENTAL multi-object detector
///     ([AIDetectionRepository], default [DetectionScanRepository]:
///     `POST /customer/pickup/detect`). The server stores that result, so
///     [resumePendingDetection] can read it back (`GET .../detect/{scanLog}`)
///     after the screen is recreated or the app restarts, without running the
///     AI again.
/// In multi-object mode the provider holds the AI-SUGGESTED quantity per
/// resolved item plus the user's corrections and manually added items; a
/// correction is kept until the user resets it or scans again.
class AIScanProvider extends ChangeNotifier {
  AIScanProvider(
    this._repository, {
    AIScanRepository? scanRepository,
    AIDetectionRepository? detectionRepository,
    PendingDetectionStore? pendingStore,
  })  : _scanRepository = scanRepository ?? ClassifierScanRepository(_repository),
        _detectionRepository = detectionRepository ?? DetectionScanRepository(_repository),
        _pendingStore = pendingStore ?? SecurePendingDetectionStore();

  /// Shown instead of the raw server message when the AI service is down
  /// (HTTP 503) during a multi-object scan. Nothing is shown in its place.
  static const aiUnavailableMessage =
      'AI classification is temporarily unavailable. Please try again or use manual selection.';

  final CustomerPickupBookingRepository _repository;
  final AIScanRepository _scanRepository;
  final AIDetectionRepository _detectionRepository;
  final PendingDetectionStore _pendingStore;

  File? _pickedImage;
  bool _isSubmitting = false;
  bool _isMultiObjectRequest = false;
  bool _isRestoring = false;
  bool _isRestoredResult = false;
  ApiException? _error;

  AIScanResult? _scanResult;
  final Map<int, int> _quantityCorrections = {};
  final Map<int, ItemModel> _manualItems = {};
  String? _unsupportedAiLabel;
  double? _unsupportedConfidence;

  ItemModel? _confirmedItem;

  File? get pickedImage => _pickedImage;
  bool get isSubmitting => _isSubmitting;

  /// True while [submitMultiObject] is the request in flight (loading copy).
  bool get isMultiObjectRequest => _isMultiObjectRequest;

  /// True while a stored multi-object result is being read back.
  bool get isRestoring => _isRestoring;

  /// True when [scanResult] was read back from the server rather than
  /// produced by a scan in this session.
  bool get isRestoredResult => _isRestoredResult;
  ApiException? get error => _error;

  /// The single-object classifier result (unchanged API). Null in
  /// multi-object mode — use [scanResult] there.
  AIClassificationResult? get result => _scanResult?.classification;

  /// The unified result for either mode.
  AIScanResult? get scanResult => _scanResult;
  bool get isMultiObjectResult => _scanResult?.isMultiObject ?? false;

  /// Non-null only when the model's real prediction doesn't map to any
  /// active EcoXchange item (`AI_LABEL_UNSUPPORTED`) — a real, honest
  /// outcome, never hidden behind a generic error.
  String? get unsupportedAiLabel => _unsupportedAiLabel;
  double? get unsupportedConfidence => _unsupportedConfidence;

  ItemModel? get confirmedItem => _confirmedItem;

  /// The real, server-assigned scan_log_id from the upload step — carried
  /// into the booking flow so its optional photo is this SAME image
  /// (reusing the existing image lifecycle), never a second upload.
  int? get scanLogId => _scanResult?.scanLogId;
  String? get uploadedImageUrl => _uploadedImageUrl;
  String? _uploadedImageUrl;

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    } catch (_) {
      // Cancelled, or the platform picker itself failed (e.g. no camera
      // app available) — treated identically and quietly, exactly as the
      // existing booking-photo picker already does. No fake image, no crash.
      return;
    }
    if (file == null) return;

    _pickedImage = File(file.path);
    _scanResult = null;
    _isRestoredResult = false;
    _quantityCorrections.clear();
    _manualItems.clear();
    _forgetPendingDetection(); // a new photo replaces any unfinished multi-object scan
    _unsupportedAiLabel = null;
    _unsupportedConfidence = null;
    _confirmedItem = null;
    _error = null;
    notifyListeners();
  }

  void clearPickedImage() {
    _pickedImage = null;
    notifyListeners();
  }

  /// Test-only seam: `image_picker`'s real platform channel can't be
  /// driven from a plain unit test, so this lets ai_scan_provider_test.dart
  /// exercise the real submit()/error/unsupported/confirm state machine
  /// (everything AFTER an image is picked) against a stub repository,
  /// without touching production call sites — [pickImage] itself is
  /// exercised for real in Stage 4.7's interactive verification instead.
  @visibleForTesting
  void debugSetPickedImage(File file) {
    _pickedImage = file;
    notifyListeners();
  }

  /// Uploads the picked image, then runs the REAL classification. Every
  /// branch is real: success -> [result] holds the model's actual
  /// prediction + the real matched item; `AI_LABEL_UNSUPPORTED` ->
  /// [unsupportedAiLabel]/[unsupportedConfidence] hold exactly what the
  /// model said, with no matching item guessed; any other failure ->
  /// [error], and nothing is fabricated.
  Future<void> submit() async {
    final image = _pickedImage;
    if (image == null || _isSubmitting) return;

    _isSubmitting = true;
    _isMultiObjectRequest = false;
    _error = null;
    notifyListeners();

    try {
      final upload = await _repository.uploadImage(image.path);
      _uploadedImageUrl = upload.imageUrl;
      _scanResult = await _scanRepository.analyse(upload.scanLogId);
      _isRestoredResult = false;
      _quantityCorrections.clear();
      _manualItems.clear();
      _unsupportedAiLabel = null;
      _unsupportedConfidence = null;
    } on BusinessRuleException catch (e) {
      if (e.code == 'AI_LABEL_UNSUPPORTED') {
        _unsupportedAiLabel = e.details['ai_label'] as String?;
        _unsupportedConfidence = (e.details['confidence'] as num?)?.toDouble();
        _scanResult = null;
      } else {
        _error = e;
      }
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// EXPERIMENTAL multi-object scan of the picked image: upload (the same
  /// endpoint as [submit]) -> `POST /customer/pickup/detect`. The uploaded
  /// scan is remembered BEFORE detection, so if the app loses the response
  /// (timeout, restart) the result Laravel stored can still be recovered by
  /// [resumePendingDetection]. Failures leave no result: a 503 becomes
  /// [aiUnavailableMessage]; everything else keeps the real server message.
  Future<void> submitMultiObject() async {
    final image = _pickedImage;
    if (image == null || _isSubmitting) return;

    _isSubmitting = true;
    _isMultiObjectRequest = true;
    _error = null;
    notifyListeners();

    try {
      final upload = await _repository.uploadImage(image.path);
      _uploadedImageUrl = upload.imageUrl;
      await _safely(() => _pendingStore.save(PendingDetection(scanLogId: upload.scanLogId, imageUrl: upload.imageUrl)));
      _scanResult = await _detectionRepository.analyse(upload.scanLogId);
      _isRestoredResult = false;
      _quantityCorrections.clear();
      _manualItems.clear();
      _unsupportedAiLabel = null;
      _unsupportedConfidence = null;
    } on ServerException catch (e) {
      _error = e.statusCode == 503 ? ServerException(aiUnavailableMessage, statusCode: 503, code: e.code) : e;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Recovers the last unfinished multi-object scan (if any) from the result
  /// Laravel stored — `GET /customer/pickup/detect/{scanLog}`, never a new
  /// inference. Called when the Scan screen is created. A scan that no
  /// longer has a readable result (404 `DETECTION_NOT_FOUND`, or
  /// `IMAGE_INVALID` because it was used by a pickup / isn't this user's) is
  /// forgotten quietly; any other failure keeps it for a later attempt.
  Future<void> resumePendingDetection() async {
    if (_scanResult != null || _isSubmitting || _isRestoring || _pickedImage != null) return;

    final pending = await _safely(_pendingStore.read);
    if (pending == null) return;

    _isRestoring = true;
    notifyListeners();

    try {
      final result = await _detectionRepository.restore(pending.scanLogId);
      if (_scanResult == null && _pickedImage == null) {
        _scanResult = result;
        _uploadedImageUrl = pending.imageUrl;
        _isRestoredResult = true;
        _quantityCorrections.clear();
        _manualItems.clear();
      }
    } on ServerException catch (e) {
      if (e.statusCode == 404) await _safely(_pendingStore.clear);
    } on ApiException {
      // Network/auth/etc.: nothing restored, nothing invented; try next time.
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  void _forgetPendingDetection() => _safely(_pendingStore.clear);

  /// Device storage is a convenience only — a storage failure must never
  /// break scanning.
  static Future<T?> _safely<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  /// User tapped "Yes, this is correct" — the AI's own matched item becomes
  /// the verified choice. Does not alter the recorded prediction itself.
  void confirmAiResult() {
    final classification = result;
    if (classification != null) {
      _confirmedItem = classification.item;
      notifyListeners();
    }
  }

  // ── Multi-object: AI-suggested quantities + user corrections ───────────

  /// The quantity the AI suggested for [itemId] (0 if not detected). Only
  /// RESOLVED materials count; an unresolved material or an unclassified
  /// object never contributes to any item's suggestion.
  int suggestedQuantityOf(int itemId) {
    for (final line in _scanResult?.lines ?? const <AIScanLine>[]) {
      if (line.item!.id == itemId) return line.suggestedQuantity;
    }
    return 0;
  }

  /// Items the user added themselves in multi-object review (e.g. for an
  /// object the AI could not classify). AI suggestion for these is 0.
  List<ItemModel> get manualItems => List.unmodifiable(_manualItems.values);

  bool isManuallyAdded(int itemId) => _manualItems.containsKey(itemId);

  /// Adds a real catalogue item picked by the user to the multi-object
  /// review (quantity +1). An item the AI already suggested is incremented
  /// instead of duplicated.
  void addManualItem(ItemModel item) {
    final aiSuggested = _scanResult?.lines.any((l) => l.item!.id == item.id) ?? false;
    if (!aiSuggested) _manualItems.putIfAbsent(item.id, () => item);
    setQuantity(item.id, quantityOf(item.id) + 1);
  }

  /// The quantity that will be booked: the user's correction if any,
  /// otherwise the AI suggestion.
  int quantityOf(int itemId) => _quantityCorrections[itemId] ?? suggestedQuantityOf(itemId);

  bool isQuantityCorrected(int itemId) => _quantityCorrections.containsKey(itemId);

  /// Records a user correction (never below 0; 0 excludes the item). Setting
  /// it back to the AI suggestion clears the "edited" state.
  void setQuantity(int itemId, int quantity) {
    final value = quantity < 0 ? 0 : quantity;
    if (value == suggestedQuantityOf(itemId)) {
      _quantityCorrections.remove(itemId);
    } else {
      _quantityCorrections[itemId] = value;
    }
    notifyListeners();
  }

  void incrementQuantity(int itemId) => setQuantity(itemId, quantityOf(itemId) + 1);

  void decrementQuantity(int itemId) => setQuantity(itemId, quantityOf(itemId) - 1);

  void resetQuantityToSuggestion(int itemId) {
    if (_quantityCorrections.remove(itemId) != null) notifyListeners();
  }

  /// The reviewed lines to hand to the booking flow (quantity > 0 only):
  /// the USER-CONFIRMED quantities (AI suggestion unless corrected), plus
  /// items the user added manually.
  List<PrefillItemQuantity> get reviewedQuantities => [
        for (final line in _scanResult?.lines ?? const <AIScanLine>[])
          if (quantityOf(line.item!.id) > 0) PrefillItemQuantity(item: line.item!, quantity: quantityOf(line.item!.id)),
        for (final item in _manualItems.values)
          if (quantityOf(item.id) > 0) PrefillItemQuantity(item: item, quantity: quantityOf(item.id)),
      ];

  int get totalReviewedQuantity => reviewedQuantities.fold(0, (sum, l) => sum + l.quantity);

  /// User tapped "No, choose manually" (or the AI result was unsupported)
  /// and picked a real, active item from the catalogue themselves — never
  /// a hardcoded/invented item, always whatever [ItemCatalogueProvider]'s
  /// real API-backed list actually contains.
  void confirmManualItem(ItemModel item) {
    _confirmedItem = item;
    notifyListeners();
  }

  /// "Scan another photo": clears everything, including the remembered
  /// unfinished multi-object scan (so it is not restored next time).
  void reset() {
    _pickedImage = null;
    _isSubmitting = false;
    _isMultiObjectRequest = false;
    _isRestoredResult = false;
    _error = null;
    _scanResult = null;
    _quantityCorrections.clear();
    _manualItems.clear();
    _forgetPendingDetection();
    _unsupportedAiLabel = null;
    _unsupportedConfidence = null;
    _confirmedItem = null;
    _uploadedImageUrl = null;
    notifyListeners();
  }
}
