class AppUser {
  final int id;
  final String username;
  final String role;
  final double? zoneLat;
  final double? zoneLng;
  final double? zoneRadiusMeters;
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.zoneLat,
    this.zoneLng,
    this.zoneRadiusMeters,
  });
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is num) return value.toInt();
    return 0;
  }

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
