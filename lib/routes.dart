import 'package:flutter/material.dart';
import 'package:flutter_allergy_identifier/screens/auth/login_screen.dart';
import 'package:flutter_allergy_identifier/screens/auth/signup_screen.dart';
import 'package:flutter_allergy_identifier/screens/home_screen.dart';
import 'package:flutter_allergy_identifier/screens/feedback/feedback_screen.dart';
import 'package:flutter_allergy_identifier/screens/analysis/analysis_screen.dart';
import 'package:flutter_allergy_identifier/screens/notification/notification_preferences_screen.dart';
import 'package:flutter_allergy_identifier/screens/settings/settings_screen.dart';

// Define route names as constants
class Routes {
  static const String home = '/';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String homeScreen = '/home';
  static const String feedback = '/feedback';
  static const String analysis = '/analysis';
  static const String notifications = '/notifications';
  static const String settings = '/settings';

  // Add more routes as needed
}

// Define a route generator function
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case Routes.signup:
      return MaterialPageRoute(builder: (_) => const SignupScreen());
    case Routes.login:
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    case Routes.homeScreen:
      return MaterialPageRoute(builder: (_) => const HomeScreen());
    case Routes.feedback:
      return MaterialPageRoute(builder: (_) => const FeedbackScreen());
    case Routes.analysis:
      return MaterialPageRoute(builder: (_) => const AnalysisScreen());
    case Routes.notifications:
      return MaterialPageRoute(
        builder: (_) => const NotificationPreferencesScreen(),
      );
    case Routes.settings:
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    // Add more cases for other routes
    default:
      // If there is no such named route, return a 404 page
      return MaterialPageRoute(
        builder:
            (_) => Scaffold(
              body: Center(
                child: Text('No route defined for ${settings.name}'),
              ),
            ),
      );
  }
}
