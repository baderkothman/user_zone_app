import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'screens/login_screen.dart';
import 'screens/user_zone_screen.dart';

class Routes {
  static const String login = '/';
  static const String userZone = '/user-zone';
}

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
