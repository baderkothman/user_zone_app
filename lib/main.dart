import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/login_screen.dart';
import 'screens/user_zone_screen.dart';
import 'services/session_manager.dart';
import 'models/app_user.dart';

/// main()
/// ======
/// Boots the Flutter app and loads the root widget.
///
/// This app uses a small “session gate”:
/// - If a saved user exists in SharedPreferences -> open UserZoneScreen
/// - Otherwise -> open LoginScreen
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserZoneApp());
}

/// UserZoneApp
/// ===========
/// MaterialApp configuration:
/// - Dark theme (Material 3)
/// - Centralized onGenerateRoute routing
/// - Session-gated home screen
class UserZoneApp extends StatelessWidget {
  const UserZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This theme is intentionally “dark-first” to match map UI and overlay cards.
    const background = Color(0xFF020617);
    const foreground = Color(0xFFE5E7EB);
    const primary = Color(0xFF4F46E5);
    const secondary = Color(0xFF22C55E);

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: background,
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
      onGenerateRoute: RouteConfig.onGenerateRoute,
      home: const _SessionGate(),
    );
  }
}

/// _SessionGate
/// ============
/// Startup gate that checks for a saved session user.
/// This prevents the app from showing login every time it restarts.
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return UserZoneScreen(user: user);
      },
    );
  }
}
