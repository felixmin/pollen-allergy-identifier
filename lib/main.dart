import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_allergy_identifier/firebase_options.dart';
import 'package:flutter_allergy_identifier/routes.dart';
import 'package:flutter_allergy_identifier/screens/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_allergy_identifier/services/notification_service.dart';
import 'package:flutter_allergy_identifier/services/settings_service.dart';

// Define a top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("Handling a background message: ${message.messageId}");
  // You can process the message data here if needed
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the default options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Firebase Auth persistence to reduce sign-out issues
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Initialize settings service
  final settingsService = SettingsService();
  await settingsService.initialize();

  // Set up Firebase Cloud Messaging background handler
  if (!kIsWeb) {
    // Background message handling is only available on native platforms
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } else {
    // For web, we don't need the background handler
    debugPrint('Firebase Messaging background handler not required for web');
  }

  // Connect to Firebase emulators in debug mode
  if (kDebugMode) {
    try {
      // Use Firebase Auth emulator
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

      // Use Firestore emulator
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

      // Use Functions emulator
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

      debugPrint('🔥 Connected to Firebase Emulators');
    } catch (e) {
      debugPrint('⚠️ Failed to connect to Firebase Emulators: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      // Use a more descriptive error message
      if (kIsWeb && e.toString().contains('MissingPluginException')) {
        debugPrint(
          'ℹ️ Firebase Messaging web: Some features may be limited in web environment',
        );
      } else {
        debugPrint('⚠️ Failed to initialize notification service: $e');
      }
      // Continue app execution even if notifications fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Allergy Identifier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      onGenerateRoute: generateRoute,
      home: _getLandingPage(),
    );
  }

  // Check if user is already logged in and return appropriate screen
  Widget _getLandingPage() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // User is logged in, show home screen
          return const HomeScreen();
        } else {
          // User is not logged in, show welcome screen
          return const WelcomeScreen(title: 'Allergy Identifier');
        }
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.title});

  final String title;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : double.infinity,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.health_and_safety,
                  size: 100,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to Allergy Identifier',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Test message banner
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Hi there! Update successful!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Track and manage your allergies with ease',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Add to Home Screen instruction
                if (kIsWeb) _buildAddToHomeScreenBanner(),

                const SizedBox(height: 32),

                // Desktop layout: buttons with constrained width
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              Routes.login,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              Routes.signup,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SIGN UP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                // Mobile layout: full-width buttons
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              Routes.login,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              Routes.signup,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SIGN UP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddToHomeScreenBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
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
}
