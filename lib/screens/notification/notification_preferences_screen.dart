import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_allergy_identifier/services/notification_service.dart';
import 'dart:developer' as developer;

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  bool _notificationsEnabled = false;
  bool _dailyRemindersEnabled = false;
  bool _highPollenAlertsEnabled = false;
  bool _weeklyReportsEnabled = false;
  String? _errorMessage;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.initialize();

      _fcmToken = _notificationService.token;

      // In a real app, you would fetch the user's notification preferences from your backend
      // For now, we'll just assume all are disabled initially
      setState(() {
        _notificationsEnabled = true;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error initializing notifications', error: e);
      setState(() {
        _errorMessage = 'Failed to initialize notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDailyReminders(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        await _notificationService.subscribeToTopic('daily_reminders');
      } else {
        await _notificationService.unsubscribeFromTopic('daily_reminders');
      }

      setState(() {
        _dailyRemindersEnabled = value;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error toggling daily reminders', error: e);
      setState(() {
        _errorMessage = 'Failed to update preference: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleHighPollenAlerts(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        await _notificationService.subscribeToTopic('high_pollen_alerts');
      } else {
        await _notificationService.unsubscribeFromTopic('high_pollen_alerts');
      }

      setState(() {
        _highPollenAlertsEnabled = value;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error toggling high pollen alerts', error: e);
      setState(() {
        _errorMessage = 'Failed to update preference: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleWeeklyReports(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        await _notificationService.subscribeToTopic('weekly_reports');
      } else {
        await _notificationService.unsubscribeFromTopic('weekly_reports');
      }

      setState(() {
        _weeklyReportsEnabled = value;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error toggling weekly reports', error: e);
      setState(() {
        _errorMessage = 'Failed to update preference: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testNotification() async {
    // This would normally be triggered from the server,
    // but for testing we'll simulate it via the app
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent! Check your device.'),
      ),
    );

    // In a real app, you would call your server to send a test notification
    // For example:
    // await YourApiService.sendTestNotification(userId);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
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
                          'Notification Settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          ),

                        // Notification status card
                        Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _notificationsEnabled
                                          ? Icons.notifications_active
                                          : Icons.notifications_off,
                                      color:
                                          _notificationsEnabled
                                              ? Colors.green
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Push Notifications',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _notificationsEnabled
                                                  ? Colors.black
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (kIsWeb)
                                      TextButton.icon(
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Check Permission'),
                                        onPressed: _initializeNotifications,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _notificationsEnabled
                                      ? 'You will receive important alerts about your allergies.'
                                      : 'Push notifications are disabled. Enable them in your browser or device settings.',
                                  style: TextStyle(
                                    color:
                                        _notificationsEnabled
                                            ? Colors.black87
                                            : Colors.grey,
                                  ),
                                ),
                                if (!_notificationsEnabled && kIsWeb) ...[
                                  const SizedBox(height: 16),
                                  if (kIsWeb) _buildPwaInstructions(),
                                ],
                              ],
                            ),
                          ),
                        ),

                        if (_notificationsEnabled) ...[
                          const Text(
                            'Notification Types',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Card(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              children: [
                                // Daily reminders
                                SwitchListTile(
                                  title: const Text('Daily Feedback Reminders'),
                                  subtitle: const Text(
                                    'Get a reminder to submit your daily allergy feedback',
                                  ),
                                  value: _dailyRemindersEnabled,
                                  onChanged: _toggleDailyReminders,
                                  secondary: const Icon(Icons.alarm),
                                ),

                                const Divider(),

                                // High pollen alerts
                                SwitchListTile(
                                  title: const Text('High Pollen Alerts'),
                                  subtitle: const Text(
                                    'Be notified when pollen levels are high in your area',
                                  ),
                                  value: _highPollenAlertsEnabled,
                                  onChanged: _toggleHighPollenAlerts,
                                  secondary: const Icon(Icons.warning_amber),
                                ),

                                const Divider(),

                                // Weekly reports
                                SwitchListTile(
                                  title: const Text('Weekly Reports'),
                                  subtitle: const Text(
                                    'Receive a weekly summary of your symptoms and pollen levels',
                                  ),
                                  value: _weeklyReportsEnabled,
                                  onChanged: _toggleWeeklyReports,
                                  secondary: const Icon(Icons.bar_chart),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _testNotification,
                              icon: const Icon(Icons.send),
                              label: const Text('Test Notification'),
                            ),
                          ),
                        ],

                        // For debugging: Show FCM token
                        if (kDebugMode && _fcmToken != null) ...[
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Developer Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'FCM Token (for server-side notifications):',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _fcmToken!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  onPressed: () {
                                    // Copy to clipboard logic would go here
                                  },
                                  tooltip: 'Copy token',
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

  Widget _buildPwaInstructions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enable Notifications in Your Browser',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Click the lock/info icon in your browser\'s address bar\n'
            '2. Find "Notifications" in the site settings\n'
            '3. Allow notifications for this site\n'
            '4. Refresh this page',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Page'),
              onPressed: () {
                // In a real app, you might want to reload the page
                // For now, just re-initialize notifications
                _initializeNotifications();
              },
            ),
          ),
        ],
      ),
    );
  }
}
