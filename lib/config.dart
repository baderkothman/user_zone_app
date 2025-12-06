// lib/config.dart
const String kBaseUrl = 'http://10.0.2.2:3000';
/// Global configuration for the mobile app → backend connection.
///
/// This file defines the **base URL** used by all HTTP requests
/// (login, location updates, alerts, etc.) to reach your Next.js
/// geofence admin backend.
///
/// Usage:
/// - All API calls build on top of [kBaseUrl], for example:
///   - `POST $kBaseUrl/api/user-login`
///   - `POST $kBaseUrl/api/user-location`
///   - `GET  $kBaseUrl/api/users/:id`
///
/// ─────────────────────────────────────────────────────────
/// Choosing the correct value for [kBaseUrl]
/// ─────────────────────────────────────────────────────────
///
/// 1) Android emulator (backend running on your PC at `localhost:3000`)
///    - Use the special host `10.0.2.2` so the emulator can see
///      your computer’s localhost:
///
///        const String kBaseUrl = 'http://10.0.2.2:3000';
///
///
/// 2) Real Android / iPhone device on the **same Wi-Fi** as your PC
///    - Find your PC’s LAN IP (e.g. `192.168.1.50`).
///    - Make sure your Next.js dev server is listening on that IP
///      (or at least not firewalled).
///    - Then use:
///
///        const String kBaseUrl = 'http://192.168.1.50:3000';
///
///
/// 3) Deployed backend (e.g. public server / VPS)
///    - When you deploy the Next.js app, replace this with your
///      public URL:
///
///        const String kBaseUrl = 'https://your-domain.com';
///
///
/// Important:
/// - Always keep exactly **one** `kBaseUrl` active at a time,
///   and comment out the others if you switch environments.
/// - If requests suddenly stop working, double-check:
///   - The device can reach the IP/domain in a browser.
///   - The port (`3000` by default) is correct and open.
///   - HTTP vs HTTPS matches your server config.

