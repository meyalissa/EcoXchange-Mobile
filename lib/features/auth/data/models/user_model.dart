/// EcoXchange Mobile — the authenticated user, shaped EXACTLY like
/// `App\Http\Resources\UserResource` (confirmed by inspection) — no field
/// exists here that the API doesn't genuinely return. In particular:
///   - `role` is the server's own value; nothing in this app lets a user
///     pick "I am a Customer/Rider" — see AuthProvider/LoginScreen.
///   - `riderProfile` is null for a customer, and for a rider only carries
///     the handful of fields UserResource actually includes (rider_type,
///     vehicle_type, rider_status, current lat/lng) — not the full
///     RiderProfile row (no IC number, license, etc. — that's Phase 4A's
///     dedicated /rider/profile endpoint, not this one).
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.phoneNumber,
    required this.profilePhotoUrl,
    this.riderProfile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phoneNumber: json['phone_number'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      riderProfile: json['rider_profile'] != null
          ? RiderProfileSummary.fromJson(json['rider_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phoneNumber;

  /// A full, directly-usable URL — straight from the server's own
  /// `UserResource::profile_photo_url` (never built client-side from a raw
  /// disk path). Null when the user has no photo.
  final String? profilePhotoUrl;

  final RiderProfileSummary? riderProfile;

  bool get isCustomer => role == 'customer';
  bool get isRider => role == 'rider';
}

/// The lightweight rider snapshot UserResource embeds — see UserModel's
/// docblock for why this deliberately isn't the full rider profile.
class RiderProfileSummary {
  const RiderProfileSummary({
    required this.riderType,
    required this.vehicleType,
    required this.riderStatus,
  });

  factory RiderProfileSummary.fromJson(Map<String, dynamic> json) {
    return RiderProfileSummary(
      riderType: json['rider_type'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      riderStatus: json['rider_status'] as String?,
    );
  }

  final String? riderType;
  final String? vehicleType;
  final String? riderStatus;
}
