// lib/main.dart
import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/login_screen.dart';
import 'screens/user_zone_screen.dart';
import 'services/session_manager.dart';
import 'models/app_user.dart';

/// Entry point of the User Zone mobile app.
///
/// - Ensures Flutter bindings are initialized.
/// - Boots the [UserZoneApp] which decides whether to show:
///   - the **login screen**, or
///   - the **user zone screen** (if a session is already stored).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserZoneApp());
}

/// Root widget for the User Zone app.
///
/// Responsibilities:
/// - Define a **single dark theme** that visually matches the
///   Next.js admin dashboard (deep navy background, indigo primary).
/// - Configure routing via [RouteConfig.onGenerateRoute].
/// - Use [_SessionGate] as `home` to restore an existing session
///   without showing the login screen again.
class UserZoneApp extends StatelessWidget {
  const UserZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Core colors aligned with the dashboard tokens.
    const background = Color(0xFF020617); // very dark navy
    const foreground = Color(0xFFE5E7EB); // light gray text
    const primary = Color(0xFF4F46E5); // indigo accent
    const secondary = Color(0xFF22C55E); // emerald accent (status / success);

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: background,
        background: background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: foreground, fontSize: 14),
        bodySmall: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF020617).withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF020617).withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
    );

    return MaterialApp(
      title: 'User Zone',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // Centralized route builder (login, user zone…)
      onGenerateRoute: RouteConfig.onGenerateRoute,
      // First screen decides based on stored session.
      home: const _SessionGate(),
    );
  }
}

/// Initial gate that decides which screen to show.
///
/// Flow:
/// - Loads the stored [AppUser] from [SessionManager].
/// - While loading, shows a minimal full-screen spinner.
/// - If no user is found → show [LoginScreen].
/// - If a user is found → go directly to [UserZoneScreen] so the
///   user stays logged in across app restarts.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<AppUser?> _futureUser;

  @override
  void initState() {
    super.initState();
    _futureUser = SessionManager.loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _futureUser,
      builder: (context, snapshot) {
        // Simple splash/loading state while checking session.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final user = snapshot.data;

        // No stored session → show login
        if (user == null) {
          return const LoginScreen();
        }

        // Stored session found → jump straight into the map screen
        return UserZoneScreen(user: user);
      },
    );
  }
}
