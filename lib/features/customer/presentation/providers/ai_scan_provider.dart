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
/// ONE unified action, [submit] (Part B of the overnight task): tries the
/// object-counting detector first ([AIDetectionRepository], default
/// [DetectionScanRepository]: `POST /customer/pickup/detect`) — it is the
/// more general of the two real pipelines, since it ALSO classifies each
/// found object's material via the same EfficientNet-B0 model the plain
/// classifier uses. When detection finds nothing countable in this photo,
/// or the detector specifically is unavailable/can't read the image, this
/// falls back to the plain whole-photo classifier ([AIScanRepository],
/// default [ClassifierScanRepository]: `POST /customer/pickup/classify`)
/// on the SAME already-uploaded `scan_log_id` — never a second upload,
/// never a duplicate `ScanLog` row (confirmed server-side: both endpoints
/// key off the one `scan_log_id` and write to disjoint columns — see
/// `PickupDetectionController`'s docblock). [fallbackNote] explains
/// WHICH of those two things happened, honestly, whenever it did.
///
/// [submitMultiObject] (detector only, no fallback) remains a separate,
/// directly-callable primitive that [submit] does not call internally
/// (each does its own upload — calling both back-to-back would be the
/// double-upload this design explicitly avoids) — kept because it is
/// still real, working functionality worth testing/reusing in isolation,
/// even though no button calls it directly anymore (see
/// `ScanClassifyScreen`'s docblock).
///
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

  /// Raw bytes of the picked photo, not a [File]/path — `dart:io.File` and
  /// `Image.file` are not supported on Flutter Web (`XFile.path` there is a
  /// blob URL, and `Image.file` asserts outright). `XFile.readAsBytes()` and
  /// `Image.memory()` both work identically on every platform, so this is
  /// the one representation the whole provider/UI/upload pipeline uses,
  /// with no platform branching anywhere.
  Uint8List? _pickedImageBytes;
  String _pickedImageName = 'photo.jpg';
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
  String? _fallbackNote;

  Uint8List? get pickedImageBytes => _pickedImageBytes;
  bool get isSubmitting => _isSubmitting;

  /// True while the detector specifically is the request in flight (loading
  /// copy) — i.e. always true at the start of [submit], and for the rest of
  /// it only if detection actually found something countable.
  bool get isMultiObjectRequest => _isMultiObjectRequest;

  /// Set by [submit] only when it fell back to the plain classifier instead
  /// of showing a multi-object result — either because detection genuinely
  /// found nothing countable in this photo, or because the detector itself
  /// was unavailable/couldn't read the image. Null whenever a multi-object
  /// result IS shown, or there's no result yet. A real, honest explanation
  /// of what happened — never silently hidden.
  String? get fallbackNote => _fallbackNote;

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

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      // The platform handed back a file reference it then couldn't read
      // (corrupted/unsupported file, revoked permission, etc.) — a real,
      // honest failure shown to the user, never a crash and never silently
      // treated as "nothing picked".
      _error = const ValidationException('Could not read the selected photo. Please choose a different image.', {});
      notifyListeners();
      return;
    }

    _pickedImageBytes = bytes;
    _pickedImageName = file.name.isNotEmpty ? file.name : 'photo.jpg';
    _scanResult = null;
    _isRestoredResult = false;
    _quantityCorrections.clear();
    _manualItems.clear();
    _forgetPendingDetection(); // a new photo replaces any unfinished multi-object scan
    _unsupportedAiLabel = null;
    _unsupportedConfidence = null;
    _confirmedItem = null;
    _fallbackNote = null;
    _error = null;
    notifyListeners();
  }

  void clearPickedImage() {
    _pickedImageBytes = null;
    notifyListeners();
  }

  /// Test-only seam: `image_picker`'s real platform channel can't be
  /// driven from a plain unit test, so this lets ai_scan_provider_test.dart
  /// exercise the real submit()/error/unsupported/confirm state machine
  /// (everything AFTER an image is picked) against a stub repository,
  /// without touching production call sites — [pickImage] itself is
  /// exercised for real in Stage 4.7's interactive verification instead.
  @visibleForTesting
  void debugSetPickedImage(Uint8List bytes, {String filename = 'photo.jpg'}) {
    _pickedImageBytes = bytes;
    _pickedImageName = filename;
    notifyListeners();
  }

  /// Unified AI Scan & Classify action — see the class docblock for the
  /// full detect-then-maybe-fall-back-to-classify design. Uploads ONCE,
  /// then:
  ///   1. tries the detector ([_detectionRepository]) on that one
  ///      `scan_log_id`;
  ///   2. if it finds ≥1 object, that multi-object result IS the result;
  ///   3. otherwise (zero objects, or the detector itself failed in a
  ///      recoverable way) falls back to the plain classifier
  ///      ([_scanRepository]) on the SAME `scan_log_id` — no re-upload.
  /// Every branch is a REAL server response; nothing is fabricated on any
  /// failure. `AI_LABEL_UNSUPPORTED` (from the classify fallback, or from
  /// an injected classify-only [_scanRepository] in tests) still surfaces
  /// honestly via [unsupportedAiLabel]/[unsupportedConfidence]. [isSubmitting]
  /// guards against a second concurrent tap for the whole operation.
  Future<void> submit() async {
    final bytes = _pickedImageBytes;
    if (bytes == null || _isSubmitting) return;

    _isSubmitting = true;
    _isMultiObjectRequest = true; // detection is attempted first
    _error = null;
    _fallbackNote = null;
    notifyListeners();

    try {
      final upload = await _repository.uploadImage(bytes, _pickedImageName);
      _uploadedImageUrl = upload.imageUrl;
      final scanLogId = upload.scanLogId;
      await _safely(() => _pendingStore.save(PendingDetection(scanLogId: scanLogId, imageUrl: upload.imageUrl)));

      AIScanResult? detection;
      try {
        detection = await _detectionRepository.analyse(scanLogId);
      } on ServerException catch (e) {
        // The detector specifically being unavailable (503) or erroring
        // unexpectedly is a real, recoverable reason to fall back to plain
        // classification on the same photo — never silently hidden, see
        // [fallbackNote]. A network/timeout/auth failure is NOT caught
        // here: it would almost certainly break the classify() fallback
        // identically, so it propagates to the outer catch below instead
        // of masking a connectivity problem as an "AI limitation".
        _fallbackNote = e.statusCode == 503
            ? aiUnavailableMessage
            : 'Multi-item counting hit an unexpected error, so we classified the whole photo instead.';
      } on BusinessRuleException catch (e) {
        if (e.code == 'AI_INVALID_IMAGE' || e.code == 'IMAGE_UNREADABLE') {
          _fallbackNote = 'Multi-item counting could not read this photo, so we classified the whole photo instead.';
        } else {
          rethrow; // e.g. IMAGE_INVALID -- a real failure shared by both pipelines, not an "unavailable detector"
        }
      }

      if (detection != null && detection.detections.isNotEmpty) {
        _scanResult = detection;
        _isMultiObjectRequest = true;
      } else {
        if (detection != null) {
          // A genuine, successful detector run that just found nothing
          // countable in THIS photo -- not a failure, not hidden.
          _fallbackNote = 'No countable bottles were detected, so we classified the whole photo instead.';
        }
        await _safely(_pendingStore.clear); // nothing multi-object to resume; avoid restoring a stale/irrelevant result later
        _isMultiObjectRequest = false;
        _scanResult = await _scanRepository.analyse(scanLogId);
      }

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
    final bytes = _pickedImageBytes;
    if (bytes == null || _isSubmitting) return;

    _isSubmitting = true;
    _isMultiObjectRequest = true;
    _error = null;
    notifyListeners();

    try {
      final upload = await _repository.uploadImage(bytes, _pickedImageName);
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
    if (_scanResult != null || _isSubmitting || _isRestoring || _pickedImageBytes != null) return;

    final pending = await _safely(_pendingStore.read);
    if (pending == null) return;

    _isRestoring = true;
    notifyListeners();

    try {
      final result = await _detectionRepository.restore(pending.scanLogId);
      if (_scanResult == null && _pickedImageBytes == null) {
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

  /// Marks this scan as no longer "unfinished" once its result has actually
  /// been handed off (confirmed and added to a round, or sent to booking) —
  /// called right before that hand-off. Without this, [resumePendingDetection]
  /// on a LATER, brand-new scan (e.g. "Add Another Photo" opening a fresh
  /// `ScanClassifyScreen`/`AIScanProvider`) would read this already-finished
  /// scan back from device storage and silently show it again instead of an
  /// empty picker — a real bug this fixes (see `ScanClassifyScreen`'s
  /// `_continueToBooking`/`_continueWithReviewedQuantities`).
  void forgetConfirmedScan() => _forgetPendingDetection();

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

  /// Adds a real catalogue item picked by the user to the current
  /// confirmation (default +1, or a caller-chosen [quantity] from the
  /// "Add an Item Manually" quantity picker). An item already present —
  /// whether AI-suggested or already manually added — is MERGED (its
  /// quantity increased) rather than duplicated as a second row, in either
  /// single- or multi-object mode (both key off the same `_scanResult?.lines`
  /// + `_manualItems` + quantity maps, so there is only ever one tracking
  /// path, never a parallel one per mode).
  void addManualItem(ItemModel item, {int quantity = 1}) {
    assert(quantity > 0);
    final aiSuggested = _scanResult?.lines.any((l) => l.item!.id == item.id) ?? false;
    if (!aiSuggested) _manualItems.putIfAbsent(item.id, () => item);
    setQuantity(item.id, quantityOf(item.id) + quantity);
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
  ///
  /// Unlike [confirmAiResult] (whose item already has an AI-suggested line
  /// in `_scanResult.lines`, so [quantityOf] already resolves it), this
  /// item has no such line — so it's registered through [addManualItem],
  /// the exact same tracking "Add an Item Manually" uses, ensuring
  /// [reviewedQuantities] includes it and a later "Add an Item Manually"
  /// pick of this SAME item merges into it instead of double-counting.
  void confirmManualItem(ItemModel item, {int quantity = 1}) {
    _confirmedItem = item;
    addManualItem(item, quantity: quantity);
  }

  /// "Scan another photo": clears everything, including the remembered
  /// unfinished multi-object scan (so it is not restored next time).
  void reset() {
    _pickedImageBytes = null;
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
    _fallbackNote = null;
    _uploadedImageUrl = null;
    notifyListeners();
  }
}
