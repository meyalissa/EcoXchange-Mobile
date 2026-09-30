import '../models/ai_scan_result.dart';
import 'customer_pickup_booking_repository.dart';

/// EcoXchange Mobile — the AI analysis step of Scan & Classify, as an
/// abstraction. [AIScanProvider] and the scan screens depend on THIS, never
/// on a specific model.
///
/// Implementations must surface failures through the normal ApiException
/// hierarchy and never fabricate a result.
abstract class AIScanRepository {
  /// Analyses an ALREADY-uploaded photo (see
  /// [CustomerPickupBookingRepository.uploadImage]).
  Future<AIScanResult> analyse(int scanLogId);
}

/// The live single-object implementation: classification through the
/// existing `POST /customer/pickup/classify` endpoint, unchanged. Throws
/// `BusinessRuleException(code: 'AI_LABEL_UNSUPPORTED')` exactly as before.
class ClassifierScanRepository implements AIScanRepository {
  ClassifierScanRepository(this._bookingRepo);

  final CustomerPickupBookingRepository _bookingRepo;

  @override
  Future<AIScanResult> analyse(int scanLogId) async {
    final classification = await _bookingRepo.classify(scanLogId);
    return AIScanResult.singleObject(classification);
  }
}

/// A multi-object analysis whose result the server stores, so it can be
/// read back later without running the AI again.
abstract class AIDetectionRepository implements AIScanRepository {
  /// The stored result of an earlier [analyse] of [scanLogId]. No inference.
  Future<AIScanResult> restore(int scanLogId);
}

/// The live, EXPERIMENTAL multi-object implementation:
/// `POST /customer/pickup/detect` to analyse, and
/// `GET /customer/pickup/detect/{scanLog}` to read the stored result back.
class DetectionScanRepository implements AIDetectionRepository {
  DetectionScanRepository(this._bookingRepo);

  final CustomerPickupBookingRepository _bookingRepo;

  @override
  Future<AIScanResult> analyse(int scanLogId) => _bookingRepo.detect(scanLogId);

  @override
  Future<AIScanResult> restore(int scanLogId) => _bookingRepo.storedDetection(scanLogId);
}
