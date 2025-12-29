/// API Base URL
/// ============
/// The mobile app communicates with the backend via HTTP calls.
///
/// Endpoints used:
/// - POST /api/user-login
/// - POST /api/user-location
/// - GET  /api/users/:id   (zone refresh)
///
/// IMPORTANT:
/// - This is currently a fixed LAN IP.
/// - For production, replace with a public domain (HTTPS), or make it
///   configurable (build-time --dart-define, runtime settings screen, etc.).
const String kBaseUrl = 'http://192.168.1.21:4001';
