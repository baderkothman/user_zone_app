/// Represents a single authenticated **mobile user** in the geofencing system.
///
/// This model is the bridge between:
/// - The **Next.js backend** (`/api/user-login`, `/api/users/:id`)
/// - The **Flutter app** (login + user zone screen)
///
/// It holds:
/// - Identity: [id], [username], [role]
/// - Geofence configuration (if any):
///   - [zoneLat] / [zoneLng] → zone center coordinates
///   - [zoneRadiusMeters]   → radius in meters
///
/// Notes:
/// - All zone fields are nullable because a user might not have a zone assigned yet.
/// - Numeric fields are parsed defensively from `int` / `double` / `String` to avoid
///   runtime type issues when the backend or database returns mixed types.
class AppUser {
  /// Database ID of the user (primary key).
  final int id;

  /// Unique username used for login and display.
  final String username;

  /// Role for this user.
  ///
  /// On the mobile side this will almost always be `"user"`,
  /// but the field is kept generic to stay aligned with the backend.
  final String role;

  /// Latitude of the geofence center, if a zone has been assigned.
  ///
  /// `null` means no zone has been configured for this user yet.
  final double? zoneLat;

  /// Longitude of the geofence center, if a zone has been assigned.
  ///
  /// `null` means no zone has been configured for this user yet.
  final double? zoneLng;

  /// Radius of the geofence in **meters**, if a zone has been assigned.
  ///
  /// `null` means no zone has been configured for this user yet.
  final double? zoneRadiusMeters;

  /// Creates an immutable [AppUser] instance.
  ///
  /// The [id], [username] and [role] are required; zone-related fields are
  /// optional and will typically be `null` for users without an assigned zone.
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.zoneLat,
    this.zoneLng,
    this.zoneRadiusMeters,
  });

  /// Safely converts a dynamic value into a nullable [double].
  ///
  /// Accepts:
  /// - `null` → returns `null`
  /// - `num` (`int` / `double`) → converted via `.toDouble()`
  /// - `String` → parsed via `double.tryParse`
  ///
  /// Anything else returns `null` to avoid throwing at runtime.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely converts a dynamic value into an [int].
  ///
  /// Accepts:
  /// - `int` → returned as-is
  /// - `String` → parsed via `int.tryParse`
  /// - `num` → converted via `.toInt()`
  ///
  /// If none of the above succeed, returns `0` as a safe fallback.
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is num) return value.toInt();
    return 0;
  }

  /// Creates an [AppUser] instance from a JSON map.
  ///
  /// This factory is intentionally flexible to match both:
  /// - API responses from the backend (`zone_center_lat`, `zone_radius_m`, …)
  /// - Any local/offline representations that may use camelCase names
  ///   (`zoneLat`, `zoneRadiusMeters`, …).
  ///
  /// Expected keys (backend-style):
  /// - `"id"` (int / string / number)
  /// - `"username"` (string)
  /// - `"role"` (string, e.g. `"user"`)
  /// - `"zone_center_lat"` (nullable, numeric or string)
  /// - `"zone_center_lng"` (nullable, numeric or string)
  /// - `"zone_radius_m"` (nullable, numeric or string)
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _toInt(json['id']),
      username: (json['username'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
      // Accept both API-style and local field names.
      zoneLat: _toDouble(json['zone_center_lat'] ?? json['zoneLat']),
      zoneLng: _toDouble(json['zone_center_lng'] ?? json['zoneLng']),
      zoneRadiusMeters: _toDouble(
        json['zone_radius_m'] ?? json['zoneRadiusMeters'],
      ),
    );
  }

  /// Serializes this [AppUser] to a JSON map compatible with the backend API.
  ///
  /// Keys intentionally mirror the Next.js API responses:
  /// - `"id"`
  /// - `"username"`
  /// - `"role"`
  /// - `"zone_center_lat"`
  /// - `"zone_center_lng"`
  /// - `"zone_radius_m"`
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

  /// Returns a copy of this [AppUser] with the given fields overridden.
  ///
  /// This is helpful when:
  /// - Updating zone info after a `/api/users/:id` refresh.
  /// - Tweaking only part of the user while keeping the rest immutable.
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
