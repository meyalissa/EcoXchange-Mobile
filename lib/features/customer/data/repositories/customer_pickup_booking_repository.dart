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

  Future<ScanUploadResult> uploadImage(String filePath) async {
    final data = await _api.postMultipart('/customer/pickup/image', fileField: 'photo', filePath: filePath);
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
  }) async {
    final data = await _api.post('/customer/pickup/review', data: {
      'items': _itemsPayload(quantities),
      'address_id': addressId,
      'center_id': centerId,
      if (scanLogId != null) 'scan_log_id': scanLogId,
    });
    return ReviewResult.fromJson(data);
  }

  /// POST /customer/pickup — the real final submission. `pickup_date` is
  /// sent as `YYYY-MM-DD` (the exact format `Request::validate(['pickup_date'
  /// => 'date', ...])` accepts); `pickup_time` is one of the real slot
  /// strings the web wizard's own `<select>` uses (`"08:00-10:00"` etc — see
  /// Stage 3 report §14 for why this app reuses those exact values instead
  /// of inventing its own).
  Future<PickupDetail> submit({
    required Map<int, int> quantities,
    required int addressId,
    required int centerId,
    required String pickupDate,
    required String pickupTime,
    String? notes,
    int? scanLogId,
  }) async {
    final data = await _api.post('/customer/pickup', data: {
      'items': _itemsPayload(quantities),
      'address_id': addressId,
      'center_id': centerId,
      'pickup_date': pickupDate,
      'pickup_time': pickupTime,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (scanLogId != null) 'scan_log_id': scanLogId,
    });
    return PickupDetail.fromJson(data['pickup'] as Map<String, dynamic>);
  }
}
