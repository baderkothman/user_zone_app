/// AppUser
/// =======
/// Represents the authenticated “normal user” (mobile-side).
///
/// This model is designed to match the backend response shape from:
/// - POST /api/user-login   (returns `user` object)
/// - GET  /api/users/:id    (admin API, but reused here for zone refresh)
///
/// Zone fields:
/// - zone_center_lat / zone_center_lng / zone_radius_m are returned by the API
///   and define the circular geofence.
/// - Any of these may be null if the admin has not assigned a zone yet.
class AppUser {
  final int id;
  final String username;
  final String role;

  /// Zone center latitude (nullable when no zone is assigned)
  final double? zoneLat;

  /// Zone center longitude (nullable when no zone is assigned)
  final double? zoneLng;

  /// Zone radius in meters (nullable when no zone is assigned)
  final double? zoneRadiusMeters;

  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.zoneLat,
    this.zoneLng,
    this.zoneRadiusMeters,
  });

  /// Safely converts dynamic JSON values into double.
  ///
  /// Why needed:
  /// - Some backends send numeric fields as strings (e.g., "35.123")
  /// - Some packages decode JSON numbers as int or double
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely converts dynamic JSON values into int.
  ///
  /// If the value is invalid or missing, this returns 0 (non-valid user id).
  /// In production, you might prefer throwing or making this nullable.
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is num) return value.toInt();
    return 0;
  }

  /// Builds an AppUser from JSON.
  ///
  /// Supported keys:
  /// - Primary API keys:
  ///   - id, username, role
  ///   - zone_center_lat, zone_center_lng, zone_radius_m
  /// - Optional fallback keys (if any older client formats exist):
  ///   - zoneLat, zoneLng, zoneRadiusMeters
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _toInt(json['id']),
      username: (json['username'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
      zoneLat: _toDouble(json['zone_center_lat'] ?? json['zoneLat']),
      zoneLng: _toDouble(json['zone_center_lng'] ?? json['zoneLng']),
      zoneRadiusMeters: _toDouble(
        json['zone_radius_m'] ?? json['zoneRadiusMeters'],
      ),
    );
  }

  /// Serializes the user into the backend-compatible key names.
  ///
  /// Used for:
  /// - Persisting session locally (SharedPreferences)
  /// - Passing the model around between screens/routes
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'zone_center_lat': zoneLat,
      'zone_center_lng': zoneLng,
      'zone_radius_m': zoneRadiusMeters,
    };
  }

  /// Returns a new instance of AppUser with selected fields overridden.
  /// Useful when the server updates the zone and the app wants a mutable copy.
  AppUser copyWith({
    int? id,
    String? username,
    String? role,
    double? zoneLat,
    double? zoneLng,
    double? zoneRadiusMeters,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      zoneLat: zoneLat ?? this.zoneLat,
      zoneLng: zoneLng ?? this.zoneLng,
      zoneRadiusMeters: zoneRadiusMeters ?? this.zoneRadiusMeters,
    );
  }
}
