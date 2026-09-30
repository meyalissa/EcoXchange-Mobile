import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// EcoXchange Mobile — secure storage for the Sanctum Bearer token.
///
/// Backed by Android Keystore / iOS Keychain via flutter_secure_storage —
/// deliberately never SharedPreferences (plain XML on disk) or a Dart
/// constant. The token itself is the only thing persisted here; the
/// authenticated user is never cached locally — every app launch
/// re-verifies the token against GET /auth/me before trusting it (see
/// AuthProvider.bootstrap()), so a token revoked/expired server-side can
/// never grant stale access.
class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'sanctum_token';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
