import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _token;
  final StreamController<String> _tokenStreamController =
      StreamController<String>.broadcast();

  // For local notifications on Android
  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Stream<String> get tokenStream => _tokenStreamController.stream;

  String? get token => _token;

  Future<void> initialize() async {
    developer.log('Initializing notification service');

    try {
      if (kIsWeb) {
        // Web-specific implementation
        developer.log('Initializing notifications for web platform');
        await _initializeForWeb();
      } else {
        // Mobile-specific implementation
        await _initializeForMobile();
      }

      // Set up handlers for different notification scenarios
      _setupNotificationHandlers();

      // Set up local notifications for mobile platforms
      if (!kIsWeb) {
        await _setupLocalNotifications();
      }
    } catch (e) {
      developer.log('Error initializing notification service: $e');
      // Swallow the error to prevent app crashes, but log it
    }
  }

  Future<void> _initializeForWeb() async {
    // For web, notification permissions are handled by the browser directly
    // We don't need to call requestPermission as it's not implemented for web

    try {
      // Try to get the FCM token if available
      _token = await _firebaseMessaging.getToken();

      if (_token != null) {
        developer.log('FCM Token for web: $_token');
        _tokenStreamController.add(_token!);

        // Listen for token refreshes
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          _token = newToken;
          _tokenStreamController.add(newToken);
          developer.log('FCM Token refreshed for web: $newToken');
        });
      } else {
        developer.log('No FCM token available for web');
      }
    } catch (e) {
      developer.log('Error getting FCM token for web: $e');
      // Continue without token - notifications might not work but app should function
    }
  }

  Future<void> _initializeForMobile() async {
    // Request permission (iOS and Android)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    developer.log(
      'User notification permission status: ${settings.authorizationStatus}',
    );

    // Get the token and listen for refreshes
    _token = await _firebaseMessaging.getToken();
    developer.log('FCM Token: $_token');
    _tokenStreamController.add(_token ?? '');

    // Listen for token refreshes
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      _tokenStreamController.add(newToken);
      developer.log('FCM Token refreshed: $newToken');
    });
  }

  Future<void> _setupLocalNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        developer.log('Notification tapped: ${response.payload}');
      },
    );
  }

  void _setupNotificationHandlers() {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log('Received foreground message:');
        developer.log('Message data: ${message.data}');

        if (message.notification != null) {
          developer.log(
            'Message notification: ${message.notification!.title}, ${message.notification!.body}',
          );

          // Show notification even when in foreground
          if (!kIsWeb && _flutterLocalNotificationsPlugin != null) {
            _showLocalNotification(message);
          }
        }
      });

      // These methods might not be fully supported on web, so wrap them in try/catch
      try {
        // Handle when the app is opened from a background notification
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          developer.log('Notification opened app from background state:');
          developer.log('Message data: ${message.data}');
        });

        // Check if the app was opened from a terminated state notification
        // This might not work on web, so we'll handle errors gracefully
        if (!kIsWeb) {
          _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
            if (message != null) {
              developer.log(
                'App opened from terminated state by notification:',
              );
              developer.log('Message data: ${message.data}');
            }
          });
        }
      } catch (e) {
        developer.log('Error setting up additional notification handlers: $e');
        // Swallow the error so the app continues to function
      }
    } catch (e) {
      developer.log('Error setting up notification handlers: $e');
      // Swallow the error so the app continues to function
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_flutterLocalNotificationsPlugin == null) return;

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _flutterLocalNotificationsPlugin!.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'allergy_alerts_channel',
            'Allergy Alerts',
            channelDescription: 'Important alerts about your allergies',
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'Allergy Alert',
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  // Set up topic-based notifications
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (!kIsWeb) {
        await _firebaseMessaging.subscribeToTopic(topic);
        developer.log('Subscribed to topic: $topic');
      } else {
        developer.log('Topic subscription not fully supported on web: $topic');
        // Web implementation might require a different approach
      }
    } catch (e) {
      developer.log('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (!kIsWeb) {
        await _firebaseMessaging.unsubscribeFromTopic(topic);
        developer.log('Unsubscribed from topic: $topic');
      } else {
        developer.log(
          'Topic unsubscription not fully supported on web: $topic',
        );
        // Web implementation might require a different approach
      }
    } catch (e) {
      developer.log('Error unsubscribing from topic: $e');
    }
  }

  // Clean up resources
  void dispose() {
    _tokenStreamController.close();
  }
}
