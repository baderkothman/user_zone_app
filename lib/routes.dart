import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'screens/login_screen.dart';
import 'screens/user_zone_screen.dart';

/// Routes
/// ======
/// Central route names for navigation.
class Routes {
  static const String login = '/';
  static const String userZone = '/user-zone';
}

/// RouteConfig
/// ===========
/// A single route factory that:
/// - Keeps routing logic centralized
/// - Ensures the UserZone screen always receives the required AppUser argument
///
/// Navigation expectations:
/// - Login -> UserZone uses pushReplacementNamed with `arguments: user`
/// - Logout -> Login clears the navigation stack
class RouteConfig {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case Routes.userZone:
        final args = settings.arguments;

        // Safety: if the route is called without the correct argument,
        // fallback to Login to avoid runtime crashes.
        if (args is AppUser) {
          return MaterialPageRoute<void>(
            builder: (_) => UserZoneScreen(user: args),
            settings: settings,
          );
        }

        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
    }
  }
}
