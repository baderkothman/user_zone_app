import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// SessionManager
/// ==============
/// Minimal local session persistence for the mobile app.
///
/// What it stores:
/// - The last logged-in AppUser as JSON in SharedPreferences
///
/// Why this exists:
/// - On app restart, we want to skip the login screen if a user session exists
/// - This is not “secure storage”; it is convenience persistence
///
/// Security note:
/// - If you later introduce access tokens or sensitive secrets, prefer
///   flutter_secure_storage / Keychain / Keystore.
class SessionManager {
  static const _keyUser = 'session_user';

  /// Save the authenticated user locally.
  static Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(user.toJson());
    await prefs.setString(_keyUser, jsonString);
  }

  /// Load the saved user from local storage.
  ///
  /// Returns:
  /// - AppUser if decoding is successful
  /// - null if no session exists or stored data is corrupted
  static Future<AppUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear the stored session user.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
  }
}
