import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';

enum AuthStatus {
  /// App just launched — session restoration (bootstrap) is in progress.
  unknown,
  authenticating,
  authenticated,
  unauthenticated,
}

/// EcoXchange Mobile — the single source of truth for auth state, exposed
/// via `provider` (ChangeNotifier + Consumer/context.watch) — the whole
/// app's chosen state-management approach (see Phase 4C.1 report §4 for
/// why). Screens never call AuthRepository/ApiClient directly; they call
/// this and read [status]/[user]/[errorMessage].
class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository authRepository}) : _repository = authRepository;

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;
  bool _isSubmitting = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;

  /// Guards the login button — prevents a double-tap firing two concurrent
  /// login requests while the first is still in flight.
  bool get isSubmitting => _isSubmitting;

  /// Runs once at app launch. A token merely being PRESENT in secure
  /// storage is never trusted — GET /auth/me is the one call that proves
  /// it's still valid server-side (not expired/revoked), exactly per the
  /// backend's real session-restoration contract (Phase 1). Only a genuine
  /// 401 clears the stored token; a network/server failure here leaves the
  /// token untouched so a later retry (or the next launch, once
  /// connectivity returns) can still succeed without forcing a fresh login.
  Future<void> bootstrap() async {
    final hasToken = await _repository.hasStoredToken();
    if (!hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      _user = await _repository.me();
      _status = AuthStatus.authenticated;
    } on UnauthorizedException {
      await _repository.clearLocalSession();
      _status = AuthStatus.unauthenticated;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Role is never chosen by the user — [UserModel.role] is whatever the
  /// server returned, and LoginScreen/AppRouter branch on that alone.
  Future<void> login({required String email, required String password}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _repository.login(email: email, password: password);
      _status = AuthStatus.authenticated;
    } on ValidationException catch (e) {
      _errorMessage = e.firstError ?? e.message;
    } on ApiException catch (e) {
      // Covers ForbiddenException (Staff/RC/Admin — real backend rule) and
      // RateLimitedException/NetworkException/etc. with their real message.
      _errorMessage = e.message;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Revokes the token server-side (POST /auth/logout) THEN clears local
  /// state — if the network call itself fails, local state is still
  /// cleared so the user is never stuck unable to sign out on this device.
  Future<void> logout() async {
    try {
      await _repository.logout();
    } on ApiException {
      // Best-effort — local session is cleared regardless (see docblock).
    } finally {
      await _repository.clearLocalSession();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Registered with ApiClient.onUnauthorized (see main.dart) — fired when
  /// ANY authenticated request gets a real 401 (expired/revoked token),
  /// not only from an explicit logout action. Clears local state and
  /// surfaces a clear reason; never makes an HTTP call itself, so it can't
  /// trigger another 401/loop.
  Future<void> forceLogout({String? reason}) async {
    await _repository.clearLocalSession();
    _user = null;
    _errorMessage = reason ?? 'Your session has expired. Please log in again.';
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Replaces the in-memory user with a fresh, real, server-returned one —
  /// called after a successful Personal Information edit (name/email/
  /// phone/photo) so every screen watching [user] (header, profile) reflects
  /// the change immediately, without a second `/auth/me` round-trip. Never
  /// called with anything but a genuine API response.
  void applyUpdatedUser(UserModel updated) {
    _user = updated;
    notifyListeners();
  }
}
