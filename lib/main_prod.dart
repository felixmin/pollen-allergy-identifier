import 'package:flutter/material.dart';
import 'package:flutter_allergy_identifier/config/environment.dart';

import 'main.dart' as app;

/// Entry point for production environment
void main() {
  // Set the environment before app initialization
  EnvironmentConfig.setEnvironment(Environment.prod);

  // Run the main app with production configuration
  app.main();
}
