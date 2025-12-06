# User Zone App (Flutter)

Mobile client for the **Geofence Admin Dashboard** system.

- **Normal users** log in on this Flutter app.
- The app:
  - Shows the geofence zone assigned to the user (circle on a map).
  - Tracks the user’s live location.
  - Sends location updates and ENTER/EXIT events to the backend.
- The **Next.js admin dashboard** is used by admins to:
  - Create users and assign zones.
  - Monitor alerts and export logs.

This app talks to the same backend used by the admin dashboard.

---

## Tech Stack

- **Framework:** Flutter (Dart, Material 3, dark theme)
- **Networking:** [`http`](https://pub.dev/packages/http)
- **Maps:** [`flutter_map`](https://pub.dev/packages/flutter_map) + OpenStreetMap tiles
- **Geo / distance:** [`geolocator`](https://pub.dev/packages/geolocator) + [`latlong2`](https://pub.dev/packages/latlong2)
- **Storage (sessions):** `shared_preferences` (simple local session)

---

## Main Features

### 1. Login & Session

- Login screen for **normal users** (role = `user` in the `users` table).
- Uses backend endpoint: `POST /api/user-login`.
- On success:
  - User data is saved locally via a small `SessionManager`.
  - User is redirected to the **User Zone** screen.
- On app restart:
  - The app restores the last logged-in user.
  - Skips the login screen and opens the zone screen directly.

### 2. User Zone Map

- Map centered on:
  - Assigned zone center (if available), otherwise a default location.
- Visual elements:
  - **Zone circle** (radius in meters) from:
    - `zone_center_lat`, `zone_center_lng`, `zone_radius_m`
  - **User marker** for live location:
    - `Geolocator.getPositionStream` with high accuracy.
- Status:
  - “Inside zone” / “Outside zone” chip displayed on top of the map.
  - Info card at the bottom showing current coordinates and/or status messages.

### 3. Geofence Logic & Alerts

- On each location update:
  - If the user has an assigned zone:
    - Compute distance between user and zone center.
    - Mark user as inside / outside based on radius.
- Backend calls:
  - `POST /api/user-location`
    - Always sent, includes:
      - `userId`, `latitude`, `longitude`
      - `insideZone` (true / false / null if no zone)
    - Backend stores last location and creates alerts when inside/outside changes.
  - `POST /api/alerts` (exit only)
    - Optional explicit “exit” alert, used when user leaves the zone.
- Zone refresh:
  - Every few seconds, the app calls `GET /api/users/:id` to refresh zone info
    (so if admin changes the zone, the user doesn’t have to restart the app).

> **Note:** True OS-level _background_ tracking (when app is killed) needs extra platform-specific setup and is not fully handled here. This project focuses on tracking while the app is running or in foreground.

---

## Backend Assumptions

The app expects the same API used by the Next.js dashboard:

- `POST /api/user-login`
- `GET /api/users/:id`
- `POST /api/user-location`
- `POST /api/alerts`

Make sure your backend (Next.js + MySQL) is running and reachable from the device/emulator.

---

## Configuration

### 1. `config.dart`

At `lib/config.dart` (create it if it doesn’t exist):

```dart
/// Base URL of the backend API (Next.js server).
/// Example for local dev:
/// - Android emulator:  http://10.0.2.2:3000
/// - Real device on same Wi-Fi: http://YOUR_PC_LAN_IP:3000
const String kBaseUrl = 'http://10.0.2.2:3000';
```

Adjust this value depending on how you run the backend:

- **Android emulator:** `http://10.0.2.2:3000`
- **Android device (same Wi-Fi):** `http://192.168.x.x:3000` (your PC IP)
- **Web (Chrome):** `http://localhost:3000` or the LAN IP.

> If you use plain `http` on Android, you may need to allow cleartext traffic
> or use `https` in production.

---

## Location Permissions

The app uses `geolocator` to request and listen to location.

### Android

Check `android/app/src/main/AndroidManifest.xml` and ensure you have:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For background tracking, additional permissions and setup are required (not fully implemented here).

### iOS

If/when you build for iOS, add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to check if you are inside your assigned zone.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs your location to check if you are inside your assigned zone.</string>
```

Building and running on iOS requires macOS + Xcode.

---

## Running the App

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Run on Android device / emulator

```bash
flutter run -d android
```

or via Android Studio / VS Code device selector.

### 3. Run on Web (for quick testing / iPhone browser)

```bash
flutter run -d chrome
```

You can also use:

```bash
flutter run -d web-server
```

and open the printed URL from:

- Your PC browser, or
- Your phone browser (same Wi-Fi) to quickly test UI & API.

> Web builds can be “Add to Home Screen” on iOS to feel more like a native app, but browser background tracking is limited.

---

## Project Structure (simplified)

- `lib/main.dart`
  App entry point, theme + route setup.

- `lib/routes.dart`
  Central route names + initial route.

- `lib/models/app_user.dart`
  `AppUser` model (login + zone info).

- `lib/services/session_manager.dart`
  Simple wrapper for saving/loading user session.

- `lib/screens/login_screen.dart`
  Login UI, calls `/api/user-login`, saves session.

- `lib/screens/user_zone_screen.dart`
  Map view, geofence logic, location stream, API calls.

---

## Notes & Limitations

- This app assumes a **trusted environment**; there is no advanced token/JWT handling.
- Real background geofencing (when the app is fully closed) requires:

  - OS-level background services,
  - Additional plugins/configuration,
    which are not fully set up here.

- For production:

  - Use `https` and secure backend config.
  - Consider proper auth tokens & refresh flows.

---

## License

Internal project for geofence system. No public license specified yet.

```

If you want, I can also add a small “troubleshooting” section (e.g. common Android emulator network issues, Geolocator permission problems, etc.) to the README.
::contentReference[oaicite:0]{index=0}
```
