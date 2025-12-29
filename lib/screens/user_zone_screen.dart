import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/app_user.dart';
import '../routes.dart';
import '../services/session_manager.dart';

/// UserZoneScreen
/// ==============
/// Main screen after login. Shows:
/// - The assigned geofence circle (center + radius) if available
/// - The user's live GPS marker
/// - A status chip: inside zone / outside zone
///
/// Backend communication:
/// 1) Periodically refresh zone config from:
///    GET {kBaseUrl}/api/users/:id
///    This allows the admin to update zone center/radius and the mobile UI
///    reflects the changes without requiring logout/login.
///
/// 2) Send live location updates to:
///    POST {kBaseUrl}/api/user-location
///    Request includes:
///    - userId
///    - latitude
///    - longitude
///    - insideZone (bool?):
///        - true / false when zone exists
///        - null if no zone is assigned (no inside/outside concept yet)
///
/// How alerts are created:
/// - The server inserts alerts (enter/exit) ONLY when insideZone changes compared
///   to the previously stored state in user_locations.
class UserZoneScreen extends StatefulWidget {
  final AppUser user;

  const UserZoneScreen({super.key, required this.user});

  @override
  State<UserZoneScreen> createState() => _UserZoneScreenState();
}

class _UserZoneScreenState extends State<UserZoneScreen> {
  final MapController _mapController = MapController();

  /// Mutable copy of the user model.
  /// Zone config can change server-side; this lets us update the UI in place.
  late AppUser _user;

  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  Timer? _zoneRefreshTimer;

  /// Local UI state only (the authoritative alert logic is on the server).
  bool _insideZone = true;

  /// User-facing status message for location permission/service problems.
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initLocationTracking();
    _startZoneRefreshTimer();
  }

  /// Refresh zone configuration on a fixed interval.
  ///
  /// This supports a common scenario:
  /// - Admin updates zone center/radius
  /// - User keeps the app open
  /// - User sees zone changes without logging out
  void _startZoneRefreshTimer() {
    _zoneRefreshTimer?.cancel();
    _zoneRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshUserZone();
    });
  }

  /// Pulls the latest user info from the API, and updates the map center if needed.
  ///
  /// Endpoint:
  /// - GET /api/users/:id
  ///
  /// Note:
  /// - This endpoint is typically an admin endpoint.
  /// - If you plan to deploy publicly, consider creating a user-safe endpoint
  ///   that returns only allowed fields for the authenticated user.
  Future<void> _refreshUserZone() async {
    try {
      final uri = Uri.parse('$kBaseUrl/api/users/${_user.id}');
      final res = await http.get(uri);

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final updated = AppUser.fromJson(data);

      if (!mounted) return;

      setState(() {
        _user = updated;
      });

      if (_user.zoneLat != null && _user.zoneLng != null) {
        _mapController.move(
          LatLng(_user.zoneLat!, _user.zoneLng!),
          _mapController.camera.zoom,
        );
      }
    } catch (e) {
      debugPrint('Failed to refresh user zone: $e');
    }
  }

  /// Requests location permission and starts listening to location updates.
  ///
  /// Behavior:
  /// - If location services are disabled -> shows message
  /// - If permission denied -> requests once -> shows message if denied
  /// - If denied forever -> shows message instructing user to enable in settings
  ///
  /// Streaming updates:
  /// - accuracy: high
  /// - distanceFilter: 5 meters (reduces excessive updates)
  Future<void> _initLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Location services are disabled.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Location permission denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage =
            'Location permission permanently denied. Enable it from settings.';
      });
      return;
    }

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );

    _positionSub = stream.listen((pos) {
      setState(() {
        _currentPosition = pos;
        _statusMessage = null;
      });
      _handlePositionUpdate(pos);
    });
  }

  /// Computes inside/outside zone locally and forwards the update to the server.
  ///
  /// Local computation is used only for UI feedback and for sending insideZone
  /// to the backend so it can create alerts consistently (enter/exit).
  ///
  /// If no zone exists, insideZone is sent as null.
  void _handlePositionUpdate(Position pos) {
    final user = _user;

    final bool hasZone =
        user.zoneLat != null &&
        user.zoneLng != null &&
        user.zoneRadiusMeters != null;

    bool isInside = false;

    if (hasZone) {
      final distance = Geolocator.distanceBetween(
        user.zoneLat!,
        user.zoneLng!,
        pos.latitude,
        pos.longitude,
      );
      isInside = distance <= user.zoneRadiusMeters!;
    }

    // Update the UI chip only when a zone exists.
    if (hasZone) {
      if (isInside && !_insideZone) {
        setState(() => _insideZone = true);
      } else if (!isInside && _insideZone) {
        setState(() => _insideZone = false);
      }
    }

    // Send update to the server.
    _updateLocationOnServer(pos, hasZone ? isInside : null);
  }

  /// Posts the current position (and optional insideZone state) to the backend.
  ///
  /// Endpoint:
  /// - POST /api/user-location
  ///
  /// Server behavior (important):
  /// - Upserts into user_locations
  /// - Creates an alert only when the inside_zone state transitions
  Future<void> _updateLocationOnServer(Position pos, bool? isInside) async {
    try {
      final uri = Uri.parse('$kBaseUrl/api/user-location');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _user.id,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'insideZone': isInside,
        }),
      );
    } catch (e) {
      debugPrint('Failed to update location: $e');
    }
  }

  /// Clears local session and returns to the Login screen.
  ///
  /// This app uses local persistence only; there is no server session to invalidate.
  Future<void> _handleLogout() async {
    await _positionSub?.cancel();
    _zoneRefreshTimer?.cancel();
    await SessionManager.clear();

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _zoneRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final user = _user;

    /// A fallback center for the map when no zone is assigned yet.
    /// (You can set this to your preferred default region.)
    final LatLng defaultCenter = const LatLng(34.4367, 35.8362);

    final bool hasZone =
        user.zoneLat != null &&
        user.zoneLng != null &&
        user.zoneRadiusMeters != null;

    final LatLng zoneCenter = hasZone
        ? LatLng(user.zoneLat!, user.zoneLng!)
        : defaultCenter;

    // Visual markers:
    // - Zone center marker (when zone exists)
    // - Current user marker (when GPS data exists)
    final markers = <Marker>[
      if (hasZone)
        Marker(
          point: zoneCenter,
          width: 40,
          height: 40,
          child: Icon(
            Icons.location_on,
            color: Colors.redAccent.shade200,
            size: 32,
          ),
        ),
      if (_currentPosition != null)
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 30,
          height: 30,
          child: Icon(
            Icons.person_pin_circle,
            color: colorScheme.primary,
            size: 30,
          ),
        ),
    ];

    // Zone circle overlay:
    // - Radius is provided in meters
    // - flutter_map CircleMarker supports meter-based radius when enabled
    final circles = <CircleMarker>[
      if (hasZone)
        CircleMarker(
          point: zoneCenter,
          radius: user.zoneRadiusMeters!,
          useRadiusInMeter: true,
          color: colorScheme.primary.withValues(alpha: 0.2),
          borderColor: colorScheme.primary,
          borderStrokeWidth: 2,
        ),
    ];

    final statusColor = _insideZone ? Colors.green : Colors.redAccent;
    final statusText = _insideZone ? 'Inside zone' : 'Outside zone';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hello, ${user.username}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade700),
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: Text(
              user.role,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: zoneCenter,
              initialZoom: hasZone ? 15 : 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.user_zone_app',
              ),
              if (circles.isNotEmpty) CircleLayer(circles: circles),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),

          // Top overlays:
          // - Status chip when zone exists
          // - “No zone assigned” card otherwise
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasZone)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: statusColor.withValues(alpha: 0.9),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (!hasZone)
                  Card(
                    color: Colors.black.withValues(alpha: 0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No zone assigned to your account yet.\n'
                        'Please contact the administrator.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom overlay:
          // - Permission/service message (highest priority)
          // - Otherwise, show live coordinates when available and zone exists
          if (_statusMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                color: Colors.black.withValues(alpha: 0.88),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ),
            )
          else if (_currentPosition != null && hasZone)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                color: Colors.black.withValues(alpha: 0.85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live location',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade300,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, '
                        'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
