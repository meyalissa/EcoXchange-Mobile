import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/profile_repository.dart';
import '../auth_provider.dart';

/// EcoXchange Mobile — Edit Personal Information (Customer + Rider,
/// shared — see EditPersonalInfoScreen's docblock for why this one
/// provider/screen pair serves both roles).
///
/// Two independent save actions, matching the real UX and the two separate
/// backend endpoints:
///   - the photo uploads immediately on picking (no second "confirm photo"
///     tap — standard mobile avatar-edit UX), via [pickAndUploadPhoto];
///   - name/email/phone are staged locally and only sent on an explicit
///     [save] (the "Save Changes" button).
/// Both paths push the fresh, real, server-returned user into
/// [AuthProvider.applyUpdatedUser] on success, so every screen watching it
/// (header, profile) reflects the change immediately.
class EditPersonalInfoProvider extends ChangeNotifier {
  EditPersonalInfoProvider(
    this._repository,
    this._authProvider, {
    required String initialName,
    required String initialEmail,
    required String? initialPhoneNumber,
    required String? initialPhotoUrl,
  })  : _name = initialName,
        _email = initialEmail,
        _phoneNumber = initialPhoneNumber ?? '',
        _photoUrl = initialPhotoUrl;

  final ProfileRepository _repository;
  final AuthProvider _authProvider;

  String _name;
  String _email;
  String _phoneNumber;
  String? _photoUrl;

  /// The newly-picked photo's raw bytes while it's uploading — lets the
  /// screen show an immediate preview (via `Image.memory`) instead of a
  /// blank/stale avatar during the network round-trip. Cleared on both
  /// success and failure. Bytes, not a file path: Flutter Web has no
  /// usable file path for a picked image (`XFile.path` is a blob URL
  /// there), and `Image.file`/`dart:io.File` don't work on web at all.
  Uint8List? _pickedImageBytes;
  bool _isUploadingPhoto = false;
  ApiException? _photoError;

  bool _isSaving = false;
  ApiException? _saveError;

  String get name => _name;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String? get photoUrl => _photoUrl;
  Uint8List? get pickedImageBytes => _pickedImageBytes;
  bool get isUploadingPhoto => _isUploadingPhoto;
  ApiException? get photoError => _photoError;
  bool get isSaving => _isSaving;
  ApiException? get saveError => _saveError;

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setEmail(String value) {
    _email = value;
    notifyListeners();
  }

  void setPhoneNumber(String value) {
    _phoneNumber = value;
    notifyListeners();
  }

  Future<void> pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    } catch (_) {
      // Cancelled, or the platform picker itself failed (e.g. no camera
      // app) — treated the same, honestly, as "nothing picked". Mirrors
      // the existing pickup-photo/AI-scan pickers exactly.
      return;
    }
    if (file == null) return;

    final bytes = await file.readAsBytes();
    await _uploadPickedFile(bytes, file.name);
  }

  /// Test-only seam: `image_picker`'s real platform channel can't be driven
  /// from a plain unit test — mirrors AiScanProvider.debugSetPickedImage()'s
  /// exact convention. [pickAndUploadPhoto] itself is exercised for real in
  /// manual device verification instead.
  @visibleForTesting
  Future<void> debugUploadPhotoAt(Uint8List bytes, String filename) => _uploadPickedFile(bytes, filename);

  Future<void> _uploadPickedFile(Uint8List bytes, String filename) async {
    _pickedImageBytes = bytes;
    _isUploadingPhoto = true;
    _photoError = null;
    notifyListeners();

    try {
      final updated = await _repository.updatePhoto(bytes, filename);
      _photoUrl = updated.profilePhotoUrl;
      _authProvider.applyUpdatedUser(updated);
    } on ApiException catch (e) {
      _photoError = e;
    } finally {
      _pickedImageBytes = null;
      _isUploadingPhoto = false;
      notifyListeners();
    }
  }

  /// Local validation only — the server re-validates everything regardless
  /// (uniqueness in particular can never be verified client-side), but
  /// catching an empty name/obviously-malformed email here avoids a pointless
  /// round-trip. Returns the first problem found, or null if the form looks
  /// submittable.
  String? localValidationError() {
    if (_name.trim().isEmpty) return 'Name cannot be empty.';
    final email = _email.trim();
    final looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (email.isEmpty || !looksLikeEmail) return 'Enter a valid email address.';
    return null;
  }

  /// Returns the updated user on success, null on any failure (see
  /// [saveError] for why). Guards against a double-tap firing two
  /// concurrent submissions while the first is still in flight.
  Future<UserModel?> save() async {
    if (_isSaving) return null;

    final localError = localValidationError();
    if (localError != null) {
      _saveError = ValidationException(localError, {});
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final updated = await _repository.updateProfile(
        name: _name.trim(),
        email: _email.trim(),
        phoneNumber: _phoneNumber.trim().isEmpty ? null : _phoneNumber.trim(),
      );
      _authProvider.applyUpdatedUser(updated);
      return updated;
    } on ApiException catch (e) {
      _saveError = e;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
