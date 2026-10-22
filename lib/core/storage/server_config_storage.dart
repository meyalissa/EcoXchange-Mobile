import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// EcoXchange Mobile — persists the user's chosen runtime API server URL
/// (Settings → Server Connection) so it survives an app restart without a
/// rebuild/reinstall.
///
/// Reuses [FlutterSecureStorage] — the same dependency [TokenStorage]
/// already uses — rather than adding a new persistence package. The saved
/// value isn't secret, but there is no existing plain-storage dependency
/// in this app (see pubspec.yaml) and a second storage package just for
/// one string isn't warranted when one is already wired up, trusted, and
/// working.
class ServerConfigStorage {
  ServerConfigStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _baseUrlKey = 'runtime_api_base_url';

  /// [url] is expected to already be [ApiConfig.normalizeBaseUrl]-clean —
  /// this class only persists/retrieves, it never validates.
  Future<void> saveBaseUrl(String url) => _storage.write(key: _baseUrlKey, value: url);

  Future<String?> readBaseUrl() => _storage.read(key: _baseUrlKey);

  Future<void> clearBaseUrl() => _storage.delete(key: _baseUrlKey);
}
