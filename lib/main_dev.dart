import 'package:flutter/material.dart';
import 'package:flutter_allergy_identifier/config/environment.dart';

import 'main.dart' as app;

/// Entry point for development environment
void main() {
  // Set the environment before app initialization
  EnvironmentConfig.setEnvironment(Environment.dev);

  // Run the main app with development configuration
  app.main();
}
