import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The last multi-object scan that has not been finished yet: enough to read
/// its stored result back (`GET /customer/pickup/detect/{scanLog}`) and show
/// its photo, after the Scan screen is reopened or the app restarts.
class PendingDetection {
  const PendingDetection({required this.scanLogId, required this.imageUrl});

  final int scanLogId;
  final String imageUrl;
}

/// Remembers at most ONE [PendingDetection]. Only ids and the server's own
/// image URL are kept — never the AI result itself, which the server stores.
abstract class PendingDetectionStore {
  Future<PendingDetection?> read();
  Future<void> save(PendingDetection pending);
  Future<void> clear();
}

/// Device storage, via the flutter_secure_storage dependency the app
/// already uses for its token (no new dependency).
class SecurePendingDetectionStore implements PendingDetectionStore {
  SecurePendingDetectionStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _scanLogIdKey = 'pending_detection_scan_log_id';
  static const _imageUrlKey = 'pending_detection_image_url';

  @override
  Future<PendingDetection?> read() async {
    final id = int.tryParse(await _storage.read(key: _scanLogIdKey) ?? '');
    final url = await _storage.read(key: _imageUrlKey);
    return id == null || url == null ? null : PendingDetection(scanLogId: id, imageUrl: url);
  }

  @override
  Future<void> save(PendingDetection pending) async {
    await _storage.write(key: _scanLogIdKey, value: '${pending.scanLogId}');
    await _storage.write(key: _imageUrlKey, value: pending.imageUrl);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _scanLogIdKey);
    await _storage.delete(key: _imageUrlKey);
  }
}

/// In-memory store (tests, or anywhere persistence isn't wanted).
class InMemoryPendingDetectionStore implements PendingDetectionStore {
  InMemoryPendingDetectionStore([this._pending]);

  PendingDetection? _pending;

  @override
  Future<PendingDetection?> read() async => _pending;

  @override
  Future<void> save(PendingDetection pending) async => _pending = pending;

  @override
  Future<void> clear() async => _pending = null;
}
