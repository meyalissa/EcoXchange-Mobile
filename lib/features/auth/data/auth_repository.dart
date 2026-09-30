import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/user_model.dart';

/// EcoXchange Mobile — thin wrapper around the three real auth endpoints
/// (`POST /auth/login`, `GET /auth/me`, `POST /auth/logout`, confirmed by
/// inspecting AuthController). Owns writing/clearing the token in secure
/// storage; every other concern (parsing, error mapping) is ApiClient's.
class AuthRepository {
  AuthRepository({required ApiClient apiClient, required TokenStorage tokenStorage})
      : _api = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  /// Throws ValidationException (422 — wrong email/password, the real
  /// AuthController behaviour) or ForbiddenException (403 — a Staff/RC/
  /// Admin account, which the backend deliberately excludes from mobile).
  Future<UserModel> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', data: {'email': email, 'password': password});

    final token = data['token'] as String;
    await _tokenStorage.saveToken(token);

    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// The one call that genuinely verifies a stored token is still valid —
  /// see AuthProvider.bootstrap()'s docblock for why a locally-present
  /// token is never trusted on its own.
  Future<UserModel> me() async {
    final data = await _api.get('/auth/me');
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Revokes the token server-side THEN clears it locally — if the network
  /// call fails, the local token is still cleared (see AuthProvider) so the
  /// user is never stuck unable to log out, but the server-side revoke is
  /// always attempted first, per the real /auth/logout endpoint's purpose.
  Future<void> logout() async {
    await _api.post('/auth/logout');
  }

  Future<void> clearLocalSession() => _tokenStorage.deleteToken();

  Future<bool> hasStoredToken() async => (await _tokenStorage.readToken()) != null;
}
