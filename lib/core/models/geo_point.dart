/// EcoXchange Mobile — one stored latitude/longitude coordinate pair.
///
/// Shared across the rider (route markers) and customer (live tracking)
/// features — a single definition so neither duplicates the other.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  static GeoPoint? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    return lat == null || lng == null ? null : GeoPoint(lat, lng);
  }

  final double latitude;
  final double longitude;
}
