import 'dart:typed_data';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/api/api_exception.dart';
import '../models/ai_classification.dart';
import '../models/ai_scan_result.dart';
import '../models/pickup_booking.dart';
import '../models/pickup_detail.dart';

/// EcoXchange Mobile — Pickup Booking PREPARATION + SUBMISSION (Stage 3).
/// Every method here maps 1:1 to a real `Api\Customer\
/// PickupPreparationController` endpoint (confirmed by inspection — see
/// that controller's docblock). This repository NEVER sends a client-
/// computed reward/rate/feasibility/weight-total field — only the raw
/// selection (`item_id`/`quantity`, optionally a real per-line
/// `weight_kg` override) the server itself asks for; every number shown to
/// the customer is the server's own response, never re-derived here.
class CustomerPickupBookingRepository {
  CustomerPickupBookingRepository(this._api);

  final ApiClient _api;

  /// Real `items[].item_id`/`items[].quantity` only — no client weight/
  /// reward is ever attached (the optional per-line `weight_kg` override
  /// the backend accepts is deliberately never used by this app; see Stage
  /// 3 report §12 for why quantity-based server estimation is preferred).
  List<Map<String, dynamic>> _itemsPayload(Map<int, int> quantities) {
    return quantities.entries.map((e) => {'item_id': e.key, 'quantity': e.value}).toList();
  }

  Future<PickupEstimate> estimate(Map<int, int> quantities) async {
    final data = await _api.post('/customer/pickup/estimate', data: {'items': _itemsPayload(quantities)});
    return PickupEstimate.fromJson(data);
  }

  /// Manual reward calculator: the same `POST /customer/pickup/estimate`, but
  /// with a weight the customer entered per item (`weight_kg`, which the
  /// endpoint validates and uses instead of quantity × unit weight). Laravel
  /// returns the weight and preliminary reward; nothing is computed here. The
  /// booking flow keeps using [estimate].
  Future<PickupEstimate> estimateByWeight(Map<int, double> weightsKg) async {
    final data = await _api.post('/customer/pickup/estimate', data: {
      'items': [
        for (final e in weightsKg.entries) {'item_id': e.key, 'quantity': 1, 'weight_kg': e.value},
      ],
    });
    return PickupEstimate.fromJson(data);
  }

  Future<CentresResult> centres({required Map<int, int> quantities, required int addressId}) async {
    final data = await _api.post('/customer/pickup/centres', data: {
      'items': _itemsPayload(quantities),
      'address_id': addressId,
    });
    return CentresResult.fromJson(data);
  }

  /// [bytes] + [filename] rather than a filesystem path — see
  /// `ApiClient.postMultipart()`'s docblock for why (Flutter Web has no
  /// usable file path for a picked image).
  Future<ScanUploadResult> uploadImage(Uint8List bytes, String filename) async {
    final data = await _api.postMultipart('/customer/pickup/image', fileField: 'photo', bytes: bytes, filename: filename);
    return ScanUploadResult.fromJson(data);
  }

  /// Stage 4.6 — AI Scan & Classify. Runs the ALREADY-uploaded temporary
  /// photo (from [uploadImage] above — this method never uploads a second
  /// copy) through the real EfficientNet-B0 pipeline
  /// (Flutter → Laravel → Python, see Stage 4.5's AIInferenceService).
  /// Throws [BusinessRuleException] with `code == 'AI_LABEL_UNSUPPORTED'`
  /// when the model's real prediction doesn't map to any active EcoXchange
  /// item — the caller must show that honestly, never invent a fallback
  /// item. Every other failure (AI service down/timeout/invalid response)
  /// surfaces as the normal [ApiException] hierarchy — nothing here
  /// fabricates a result on any error path.
  Future<AIClassificationResult> classify(int scanLogId) async {
    final data = await _api.post('/customer/pickup/classify', data: {'scan_log_id': scanLogId});
    return AIClassificationResult.fromJson(data);
  }

  /// EXPERIMENTAL multi-object scan: runs the ALREADY-uploaded photo through
  /// `POST /customer/pickup/detect` (RetinaNet `bottle` detector +
  /// EfficientNet-B0 per crop). Laravel stores the result on the same
  /// ScanLog. Failures surface as the normal [ApiException] hierarchy; a body
  /// that doesn't match the contract is rejected, never partially trusted.
  Future<AIScanResult> detect(int scanLogId) async {
    final data = await _api.post(
      '/customer/pickup/detect',
      data: {'scan_log_id': scanLogId},
      receiveTimeout: ApiConfig.detectReceiveTimeout,
    );
    return _parseDetection(data);
  }

  /// `GET /customer/pickup/detect/{scanLog}` — the result an earlier
  /// [detect] stored, WITHOUT running the AI again. 404 `DETECTION_NOT_FOUND`
  /// (never detected) or `IMAGE_INVALID` (not yours, or already used by a
  /// pickup) arrive as [ServerException] with that [ServerException.code].
  Future<AIScanResult> storedDetection(int scanLogId) async {
    final data = await _api.get('/customer/pickup/detect/$scanLogId');
    return _parseDetection(data);
  }

  AIScanResult _parseDetection(Map<String, dynamic> data) {
    try {
      final result = AIScanResult.fromJson(data);
      if (!result.isMultiObject) throw const FormatException('Expected mode "multi_object".');
      return result;
    } on FormatException {
      throw const ServerException(malformedDetectionMessage, code: 'AI_INVALID_RESPONSE');
    } on TypeError {
      throw const ServerException(malformedDetectionMessage, code: 'AI_INVALID_RESPONSE');
    }
  }

  static const malformedDetectionMessage =
      'The AI scan result could not be read. Please try again or use manual selection.';

  Future<ReviewResult> review({
    required Map<int, int> quantities,
    required int addressId,
    required int centerId,
    int? scanLogId,
    List<int>? scanLogIds,
  }) async {
    final data = await _api.post('/customer/pickup/review', data: {
      'items': _itemsPayload(quantities),
      'address_id': addressId,
      'center_id': centerId,
      if (scanLogId != null) 'scan_log_id': scanLogId,
      if (scanLogIds != null && scanLogIds.isNotEmpty) 'scan_log_ids': scanLogIds,
    });
    return ReviewResult.fromJson(data);
  }

  /// POST /customer/pickup — the real final submission.
  ///
  /// `bookingMode` is `'now'` or `'scheduled'` (see
  /// `PickupPreparationController::store()`'s validation — Grab-style exact
  /// time booking, Part A). For `'now'`, the server resolves the actual
  /// requested instant itself from its own Asia/Kuala_Lumpur clock — a
  /// client-supplied date/time is never trusted for that mode, so
  /// [pickupDate]/[pickupTime] are optional and simply omitted from the
  /// request when absent. For `'scheduled'`, `pickup_date` is `YYYY-MM-DD`
  /// and `pickup_time` is one EXACT time in `"h:mm a"` 12-hour format
  /// (e.g. `"10:00 AM"`) on a 15-minute increment — not a range — matching
  /// `PickupTimeService::normalizeExactTime()` server-side exactly.
  ///
  /// [scanLogIds] (Part C — multi-image scanning) is the full list of scan
  /// log ids from every image in this booking's scan session; the legacy
  /// singular [scanLogId] is still accepted on its own for a single-image
  /// booking and the two can be combined without double-counting (the
  /// server de-duplicates).
  Future<PickupDetail> submit({
    required Map<int, int> quantities,
    required int addressId,
    required int centerId,
    required String bookingMode,
    String? pickupDate,
    String? pickupTime,
    String? notes,
    int? scanLogId,
    List<int>? scanLogIds,
  }) async {
    final data = await _api.post('/customer/pickup', data: {
      'items': _itemsPayload(quantities),
      'address_id': addressId,
      'center_id': centerId,
      'booking_mode': bookingMode,
      if (pickupDate != null) 'pickup_date': pickupDate,
      if (pickupTime != null) 'pickup_time': pickupTime,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (scanLogId != null) 'scan_log_id': scanLogId,
      if (scanLogIds != null && scanLogIds.isNotEmpty) 'scan_log_ids': scanLogIds,
    });
    return PickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }
}
