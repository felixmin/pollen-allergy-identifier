import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options_dev.dart';
import '../firebase_options_prod.dart';

/// Available environments for the application
enum Environment {
  /// Development environment
  dev,

  /// Production environment
  prod,
}

/// Central configuration class for environment management
class EnvironmentConfig {
  /// Private constructor to prevent direct instantiation
  EnvironmentConfig._();

  /// The current environment, defaults to development
  static Environment _currentEnvironment = Environment.dev;

  /// Initialize the environment configuration
  static void setEnvironment(Environment environment) {
    _currentEnvironment = environment;
    debugPrint('🔥 App running in ${environmentName.toUpperCase()} mode');
  }

  /// Get the current environment
  static Environment get currentEnvironment => _currentEnvironment;

  /// Get the name of the current environment
  static String get environmentName => _currentEnvironment.name;

  /// Get the Firebase options for the current environment
  static FirebaseOptions get firebaseOptions {
    switch (_currentEnvironment) {
      case Environment.dev:
        return DefaultFirebaseOptionsDev.currentPlatform;
      case Environment.prod:
        return DefaultFirebaseOptionsProd.currentPlatform;
    }
  }

  /// Get the Firebase project ID for the current environment
  static String get firebaseProjectId {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'allergy-ident-dev';
      case Environment.prod:
        return 'allergy-ident-prod';
    }
  }

  /// Get the app name with environment suffix in debug mode
  static String getAppName(String baseName) {
    if (kDebugMode && _currentEnvironment == Environment.dev) {
      return '$baseName (DEV)';
    }
    return baseName;
  }

  /// Check if running in development environment
  static bool get isDevelopment => _currentEnvironment == Environment.dev;

  /// Check if running in production environment
  static bool get isProduction => _currentEnvironment == Environment.prod;
}
