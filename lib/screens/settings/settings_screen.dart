import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_allergy_identifier/services/settings_service.dart';
import 'package:flutter_allergy_identifier/screens/notification/notification_preferences_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = true;
  bool _showAddToHomeScreen = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    // Ensure settings service is initialized
    if (!_settingsService.isInitialized) {
      await _settingsService.initialize();
    }

    setState(() {
      _showAddToHomeScreen = _settingsService.showAddToHomeScreen;
      _isLoading = false;
    });
  }

  Future<void> _toggleShowAddToHomeScreen(bool value) async {
    setState(() {
      _isLoading = true;
    });

    await _settingsService.setShowAddToHomeScreen(value);

    setState(() {
      _showAddToHomeScreen = value;
      _isLoading = false;
    });

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Home screen banner enabled'
                : 'Home screen banner disabled',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Show debug indicator in debug mode
        actions: [
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DEBUG',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 800 : double.infinity,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32.0 : 16.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // UI Settings Section
                        const Text(
                          'User Interface',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              // Add to Home Screen Banner Toggle
                              if (kIsWeb) ...[
                                SwitchListTile(
                                  title: const Text(
                                    'Show "Add to Home Screen" Banner',
                                  ),
                                  subtitle: const Text(
                                    'Display a banner on the home screen with instructions to add the app to your home screen',
                                  ),
                                  value: _showAddToHomeScreen,
                                  onChanged: _toggleShowAddToHomeScreen,
                                  secondary: const Icon(
                                    Icons.add_to_home_screen,
                                  ),
                                ),
                                const Divider(),
                              ],

                              // Theme Settings (placeholder for future)
                              ListTile(
                                leading: const Icon(Icons.color_lens),
                                title: const Text('App Theme'),
                                subtitle: const Text(
                                  'Light mode (More options coming soon)',
                                ),
                                enabled: false,
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Notifications Section
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications),
                            title: const Text('Notification Preferences'),
                            subtitle: const Text(
                              'Manage your notification settings',
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const NotificationPreferencesScreen(),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Account Section
                        const Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.person),
                                title: const Text('Profile'),
                                subtitle: const Text(
                                  'Manage your account information',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  // Future feature
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Profile management coming soon',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.lock),
                                title: const Text('Privacy Settings'),
                                subtitle: const Text(
                                  'Manage data privacy options',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  // Future feature
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Privacy settings coming soon',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // About Section
                        const Text(
                          'About',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.info),
                                title: const Text('App Version'),
                                subtitle: const Text('1.0.0'),
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.contact_support),
                                title: const Text('Help & Support'),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  // Future feature
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Help & Support coming soon',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.policy),
                                title: const Text('Terms & Privacy Policy'),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  // Future feature
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Terms & Privacy Policy coming soon',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Debug section in debug mode
                        if (kDebugMode) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Developer Options',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.restore),
                                  title: const Text('Reset All Settings'),
                                  subtitle: const Text(
                                    'Restore default settings',
                                  ),
                                  onTap: () async {
                                    // Show confirmation dialog
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: const Text('Reset Settings'),
                                            content: const Text(
                                              'Are you sure you want to reset all settings to their default values?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                      false,
                                                    ),
                                                child: const Text('CANCEL'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                      true,
                                                    ),
                                                child: const Text('RESET'),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirm == true) {
                                      await _settingsService.resetAllSettings();
                                      await _loadSettings();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'All settings reset to defaults',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
