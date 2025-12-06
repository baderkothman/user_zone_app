// lib/routes.dart
import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'screens/login_screen.dart';
import 'screens/user_zone_screen.dart';

/// Central registry of route names used in the app.
///
/// Keep all route paths here to avoid hard-coded strings
/// spread across multiple files.
class Routes {
  /// Login screen (entry point of the app).
  static const String login = '/';

  /// Main user zone / map screen.
  static const String userZone = '/user-zone';
}

/// Central route factory for [MaterialApp.onGenerateRoute].
///
/// Responsibilities:
/// - Map route names (see [Routes]) to concrete screens.
/// - Handle typed arguments safely (e.g. [AppUser] for [UserZoneScreen]).
/// - Provide safe fallbacks to [LoginScreen] when something is wrong.
class RouteConfig {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.login:
        // Default entry route → login screen.
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case Routes.userZone:
        // This route expects an [AppUser] as arguments.
        final args = settings.arguments;
        if (args is AppUser) {
          return MaterialPageRoute<void>(
            builder: (_) => UserZoneScreen(user: args),
            settings: settings,
          );
        }

        // If arguments are missing or invalid, fall back to login.
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      default:
        // Unknown route → safe fallback.
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}
