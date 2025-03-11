import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// A service that manages user preferences and settings
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  SharedPreferences? _prefs;
  bool _initialized = false;

  // Keys for settings
  static const String _showAddToHomeScreenKey = 'show_add_to_home_screen';

  // Default values
  static const bool _defaultShowAddToHomeScreen = true;

  // Singleton constructor
  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  /// Initialize the settings service
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      developer.log('Settings service initialized');
    } catch (e) {
      developer.log('Failed to initialize settings service', error: e);
      // Continue without settings - app should still function
    }
  }

  /// Check if the settings service is initialized
  bool get isInitialized => _initialized;

  /// Get whether to show the "Add to Home Screen" banner
  bool get showAddToHomeScreen {
    if (!_initialized || _prefs == null) {
      return _defaultShowAddToHomeScreen;
    }
    return _prefs!.getBool(_showAddToHomeScreenKey) ??
        _defaultShowAddToHomeScreen;
  }

  /// Set whether to show the "Add to Home Screen" banner
  Future<bool> setShowAddToHomeScreen(bool value) async {
    if (!_initialized || _prefs == null) {
      developer.log('Settings service not initialized, cannot save settings');
      return false;
    }

    try {
      final result = await _prefs!.setBool(_showAddToHomeScreenKey, value);
      developer.log('Set showAddToHomeScreen to $value: $result');
      return result;
    } catch (e) {
      developer.log('Error setting showAddToHomeScreen', error: e);
      return false;
    }
  }

  /// Reset all settings to their default values
  Future<void> resetAllSettings() async {
    if (!_initialized || _prefs == null) {
      return;
    }

    await _prefs!.setBool(_showAddToHomeScreenKey, _defaultShowAddToHomeScreen);
    developer.log('All settings reset to defaults');
  }
}
