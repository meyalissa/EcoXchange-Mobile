import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import 'models/user_model.dart';

/// EcoXchange Mobile — Personal Information self-service
/// (`PUT /api/v1/profile`, `POST /api/v1/profile/photo`), shaped exactly
/// like `Api\ProfileController` (confirmed by inspection).
///
/// Deliberately shared across Customer AND Rider — both edit the same
/// underlying `users` row (name/email/phone_number/user_pict), and the
/// backend endpoint is equally shared (see ProfileController's own
/// docblock). Never role-specific; never touches rider_profiles/
/// customer_profiles at all (vehicle, rider_type, centre assignment, etc.
/// remain the Rider/Staff management domain's own, separate endpoints).
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserModel> updateProfile({
    required String name,
    required String email,
    String? phoneNumber,
  }) async {
    final data = await _api.put('/profile', data: {
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
    });
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// [bytes] + [filename] from `image_picker`'s `XFile.readAsBytes()` —
  /// reuses [ApiClient.postMultipart] exactly as the AI Scan photo upload
  /// already does, never a second multipart-upload implementation. Bytes,
  /// not a file path, because Flutter Web has no usable file path for a
  /// picked image (see `ApiClient.postMultipart()`'s docblock).
  Future<UserModel> updatePhoto(Uint8List bytes, String filename) async {
    final data = await _api.postMultipart('/profile/photo', fileField: 'photo', bytes: bytes, filename: filename);
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }
}
