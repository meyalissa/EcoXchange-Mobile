/// EcoXchange Mobile — recycling centre reference info, shaped EXACTLY like
/// `App\Http\Resources\Customer\RecyclingCentreResource` (confirmed by
/// inspection).
///
/// Deliberately has NO field for fuel price, minimum service cost, max
/// pickup distance, minimum pickup reward, verification status, or
/// registration number — the Resource excludes all of these on purpose
/// (internal operational/admin configuration), so there is nothing for
/// this model to even parse.
class RecyclingCentreModel {
  const RecyclingCentreModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.operatingHours,
  });

  factory RecyclingCentreModel.fromJson(Map<String, dynamic> json) {
    return RecyclingCentreModel(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postcode: json['postcode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      operatingHours: json['operating_hours'] as Map<String, dynamic>?,
    );
  }

  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? postcode;
  final double? latitude;
  final double? longitude;
  final String? phone;

  /// Real `recycling_center_profiles.operating_hours` (array-cast JSON
  /// column) — shape not otherwise constrained by the Resource, so this
  /// stays a raw map and the widget renders whatever keys are present
  /// rather than assuming a fixed day list.
  final Map<String, dynamic>? operatingHours;
}
