// lib/services/session_manager.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// SessionManager
/// --------------
///
/// Small helper class that encapsulates **local session persistence** for
/// the logged-in user.
///
/// It uses `SharedPreferences` under the hood to:
///
/// - Save the current [AppUser] after a successful login.
/// - Load the persisted user at app startup (to skip the login screen).
/// - Clear the session on logout.
///
/// Storage format:
/// - Key: `"session_user"`
/// - Value: JSON-encoded representation of [AppUser] (`toJson()` / `fromJson()`).
class SessionManager {
  /// Key used inside [SharedPreferences] to store the serialized user object.
  static const _keyUser = 'session_user';

  /// Persists the given [user] into local storage.
  ///
  /// This is typically called right after a successful login so that
  /// the next app launch can restore the session without asking for
  /// credentials again.
  static Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(user.toJson());
    await prefs.setString(_keyUser, jsonString);
  }

  /// Loads the current [AppUser] from local storage, if available.
  ///
  /// Returns:
  /// - An [AppUser] instance if a valid JSON payload is found.
  /// - `null` if:
  ///   - No user is stored, or
  ///   - JSON decoding / parsing fails for any reason.
  static Future<AppUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser.fromJson(map);
    } catch (_) {
      // Corrupted or incompatible JSON, treat as "no session".
      return null;
    }
  }

  /// Clears the stored user session from local storage.
  ///
  /// Typically called on explicit logout to force the next app launch
  /// to show the login screen again.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
  }
}
