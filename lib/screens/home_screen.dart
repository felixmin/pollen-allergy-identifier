import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_allergy_identifier/routes.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;
// Only import JS for web
import 'dart:js' as js_interop if (dart.library.js) 'dart:js';
import 'package:flutter_allergy_identifier/services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Add a static global key that can be used to access navigator globally
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Track banner visibility (local state)
  bool _isAddToHomeScreenBannerVisible = true;
  bool _isSettingsLoaded = false;

  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Ensure settings service is initialized
    if (!_settingsService.isInitialized) {
      await _settingsService.initialize();
    }

    setState(() {
      _isAddToHomeScreenBannerVisible = _settingsService.showAddToHomeScreen;
      _isSettingsLoaded = true;
    });
  }

  // Hide banner and save preference
  Future<void> _hideBanner() async {
    setState(() {
      _isAddToHomeScreenBannerVisible = false;
    });

    // Save setting
    await _settingsService.setShowAddToHomeScreen(false);
  }

  Future<void> _signOut(BuildContext context) async {
    // Tracking variable for dialog state
    bool dialogDismissed = false;
    bool signOutCompleted = false;

    // Store the original context for later use
    final BuildContext originalContext = context;

    // Get a navigator that we can use even if the context changes
    final navigator = Navigator.of(context);

    // Release-mode debugging helper
    void releaseLog(String message) {
      // This will show in release mode
      // ignore: avoid_print
      print('LOGOUT_DEBUG: $message');
      // Also log to developer console in debug mode
      developer.log(message, name: 'LogoutProcess');
    }

    releaseLog('---- LOGOUT PROCESS STARTED ----');
    releaseLog(
      'Current user: ${FirebaseAuth.instance.currentUser?.email ?? 'null'}',
    );
    releaseLog('IsWeb: $kIsWeb');

    // Helper function to safely dismiss the dialog
    void safelyDismissDialog() {
      if (dialogDismissed) {
        releaseLog('Dialog already dismissed, skipping');
        return;
      }

      releaseLog('Attempting to dismiss dialog');
      dialogDismissed = true;

      try {
        // First try with the original context
        if (originalContext.mounted && Navigator.of(originalContext).canPop()) {
          releaseLog('Dismissing dialog with original context');
          Navigator.of(originalContext).pop();
        }
        // Then try with the stored navigator
        else if (navigator.canPop()) {
          releaseLog('Dismissing dialog with stored navigator');
          navigator.pop();
        }
        // As a last resort, try the global navigator key
        else {
          releaseLog('Contexts invalid, using global navigator');
          // Force close any dialogs that might be showing across the app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (Navigator.of(originalContext, rootNavigator: true).canPop()) {
                Navigator.of(originalContext, rootNavigator: true).pop();
              }
            } catch (e) {
              releaseLog('Post-frame dialog dismissal failed: $e');
            }
          });
        }
      } catch (e) {
        releaseLog('Error dismissing dialog: $e');
      }
    }

    // Helper function to safely navigate home
    void safelyNavigateHome() {
      releaseLog('Attempting to navigate home');

      try {
        // First try with the original context
        if (originalContext.mounted) {
          releaseLog('Navigating with original context');
          Navigator.pushNamedAndRemoveUntil(
            originalContext,
            Routes.home,
            (route) => false,
          );
        }
        // Then try with the stored navigator
        else {
          releaseLog(
            'Original context not mounted, using alternative navigation',
          );
          // Use the global navigator key as a fallback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              Navigator.pushNamedAndRemoveUntil(
                originalContext,
                Routes.home,
                (route) => false,
              );
            } catch (e) {
              releaseLog('Error in delayed navigation: $e');
              // Force a reload of the page as an absolute last resort
              if (kIsWeb) {
                releaseLog('Forcing page reload in web');
                js_interop.context.callMethod('eval', [
                  'window.location.href = "/"',
                ]);
              }
            }
          });
        }
      } catch (e) {
        releaseLog('Error navigating home: $e');
        // Force reload as last resort for web
        if (kIsWeb) {
          releaseLog('Forcing page reload after navigation error');
          js_interop.context.callMethod('eval', ['window.location.href = "/"']);
        }
      }
    }

    // Show a loading dialog to provide feedback to the user
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Signing out..."),
            ],
          ),
        );
      },
    );
    releaseLog('Logout dialog displayed');

    // Guaranteed dialog cleanup after delay, regardless of other outcomes
    Timer(const Duration(seconds: 4), () {
      releaseLog(
        'Dialog cleanup timer triggered: dialogDismissed=$dialogDismissed, signOutCompleted=$signOutCompleted',
      );

      // Dismiss dialog if still showing
      if (!dialogDismissed) {
        releaseLog('Forcing dialog dismissal via timer');
        safelyDismissDialog();

        // If signout is still not completed, force navigation anyway
        if (!signOutCompleted) {
          releaseLog(
            'Sign out not completed in time - forcing navigation and cleanup',
          );

          // This typically happens when Firebase auth is in an inconsistent state
          // Force update the UI to logged out state
          FirebaseAuth.instance.authStateChanges().listen((user) {
            releaseLog(
              'Current auth state after force timeout: user=${user != null}',
            );
          });

          // Force navigation home
          safelyNavigateHome();
        }
      }
    });

    try {
      releaseLog('Starting Firebase signout sequence');

      // Execute signout operations in parallel with a timeout
      await Future.wait([
        // Firebase signout with better error handling
        Future(() async {
          try {
            releaseLog('Attempting to sign out from Firebase Auth');
            final user = FirebaseAuth.instance.currentUser;
            releaseLog(
              'Current user before signout: ${user?.email ?? 'null'} (uid: ${user?.uid ?? 'null'})',
            );

            // For web, clear persistence first to handle reconnection scenarios
            if (kIsWeb) {
              try {
                releaseLog('Clearing web persistence state (setting to NONE)');
                await FirebaseAuth.instance.setPersistence(Persistence.NONE);
                releaseLog('Web persistence state cleared successfully');
              } catch (e) {
                releaseLog('Error clearing web persistence: $e');
              }

              // Add extra handling for IndexedDB persistence in web browsers
              try {
                releaseLog('Attempting to clear stored auth data if any');
                // Direct signout calls
                await FirebaseAuth.instance.signOut();
                await Future.delayed(const Duration(milliseconds: 300));
                // Additional signout to ensure clean state
                await FirebaseAuth.instance.signOut();
                releaseLog('Multiple signout calls completed');
              } catch (e) {
                releaseLog('Error in additional signout attempts: $e');
              }
            } else {
              // Standard signout for non-web
              releaseLog('Using standard signout for non-web platform');
              await FirebaseAuth.instance.signOut();
            }

            // Verify signout result
            final userAfter = FirebaseAuth.instance.currentUser;
            releaseLog(
              'User after signout attempt: ${userAfter?.email ?? 'null'} (null = success)',
            );
            if (userAfter == null) {
              releaseLog('Firebase Auth signOut completed successfully');
            } else {
              releaseLog(
                'WARNING: User still logged in after signout attempt!',
              );
              // Force an additional attempt
              await FirebaseAuth.instance.signOut();
              releaseLog('Additional signout attempt completed');
            }
          } catch (e) {
            releaseLog('Error in Firebase signOut: $e');
          }
        }),
        // Minimum delay to show loading dialog
        Future.delayed(const Duration(milliseconds: 800)).then((_) {
          releaseLog('Minimum dialog display time elapsed');
        }),
      ]).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          releaseLog('Sign out operation timed out after 3 seconds');
          return [null, null];
        },
      );

      // Mark as completed before UI updates
      signOutCompleted = true;
      releaseLog('Main signout process complete, updating UI');

      // Dismiss dialog
      safelyDismissDialog();

      // Navigate to home screen
      releaseLog('Navigating to home screen');
      safelyNavigateHome();

      releaseLog('---- LOGOUT PROCESS COMPLETED SUCCESSFULLY ----');
    } catch (e) {
      releaseLog('Error during sign out process: $e');

      // Mark as completed even with error - we'll force navigation
      signOutCompleted = true;

      // Dismiss dialog if needed
      safelyDismissDialog();

      // Show error to user if context still valid
      if (originalContext.mounted) {
        ScaffoldMessenger.of(originalContext).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _signOut(originalContext),
            ),
          ),
        );
      }

      // Navigate home anyway
      releaseLog('Navigating to home screen (error fallback)');
      safelyNavigateHome();

      releaseLog('---- LOGOUT PROCESS COMPLETED WITH ERRORS ----');
    }
  }

  Widget _buildAddToHomeScreenBanner() {
    // Don't show if settings say not to or if it was dismissed
    if (!_isAddToHomeScreenBannerVisible) {
      return const SizedBox.shrink(); // Empty widget
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_to_home_screen, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add to Home Screen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _hideBanner,
                tooltip: 'Hide this banner',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'For iOS: Tap the share icon (📤) then "Add to Home Screen"\n'
            'For Android: Tap the menu (⋮) then "Install app" or "Add to Home Screen"',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allergy Identifier'),
        actions: [
          // Show debug indicator in debug mode
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, Routes.settings);
            },
            tooltip: 'Settings',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
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
                  'Welcome to Allergy Identifier',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (user != null) ...[
                  Text(
                    'Logged in as: ${user.email}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User ID: ${user.uid}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ] else
                  const Text(
                    'You are not logged in',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                const SizedBox(height: 16),

                // Add to Home Screen instruction - now with visibility control
                if (kIsWeb && _isSettingsLoaded) _buildAddToHomeScreenBanner(),

                const SizedBox(height: 16),

                const Text(
                  'How It Works',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app helps identify which pollen types might be causing your allergy symptoms:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            'Submit daily feedback about your symptoms',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            'We collect pollen data for your location',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3. ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            'Our algorithm analyzes the correlation between your symptoms and pollen levels',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '4. ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            'View your personalized allergy analysis',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // Desktop layout: Two columns for action cards
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Feedback card
                      Expanded(child: _buildFeedbackCard(context)),
                      const SizedBox(width: 24),
                      // Analysis card
                      Expanded(child: _buildAnalysisCard(context)),
                    ],
                  )
                // Mobile layout: Stacked cards
                else
                  Column(
                    children: [
                      _buildFeedbackCard(context),
                      const SizedBox(height: 32),
                      _buildAnalysisCard(context),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Feedback',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Help us identify your allergies by providing daily feedback about your symptoms.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.feedback);
                },
                icon: const Icon(Icons.rate_review),
                label: const Text('Submit Feedback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Allergy Analysis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'View your personalized allergy analysis based on your feedback history.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, Routes.analysis);
                },
                icon: const Icon(Icons.analytics),
                label: const Text('View Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  foregroundColor: Theme.of(context).colorScheme.onTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
