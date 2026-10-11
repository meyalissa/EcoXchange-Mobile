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

  /// [filePath] is a local file path from `image_picker` — reuses
  /// [ApiClient.postMultipart] exactly as the AI Scan photo upload already
  /// does, never a second multipart-upload implementation.
  Future<UserModel> updatePhoto(String filePath) async {
    final data = await _api.postMultipart('/profile/photo', fileField: 'photo', filePath: filePath);
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }
}
