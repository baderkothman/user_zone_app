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

class UserZoneScreen extends StatefulWidget {
  final AppUser user;

  const UserZoneScreen({super.key, required this.user});

  @override
  State<UserZoneScreen> createState() => _UserZoneScreenState();
}

class _UserZoneScreenState extends State<UserZoneScreen> {
  final MapController _mapController = MapController();

  late AppUser _user; // mutable copy (zone can be updated server-side)

  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  Timer? _zoneRefreshTimer;

  bool _insideZone = true; // only for UI chip
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initLocationTracking();
    _startZoneRefreshTimer();
  }

  void _startZoneRefreshTimer() {
    _zoneRefreshTimer?.cancel();
    _zoneRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshUserZone();
    });
  }

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
    if (hasZone) {
      if (isInside && !_insideZone) {
        setState(() {
          _insideZone = true;
        });
      } else if (!isInside && _insideZone) {
        setState(() {
          _insideZone = false;
        });
      }
    }
    _updateLocationOnServer(pos, hasZone ? isInside : null);
  }

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
    final LatLng defaultCenter = const LatLng(34.4367, 35.8362);

    final bool hasZone =
        user.zoneLat != null &&
        user.zoneLng != null &&
        user.zoneRadiusMeters != null;

    final LatLng zoneCenter = hasZone
        ? LatLng(user.zoneLat!, user.zoneLng!)
        : defaultCenter;

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
