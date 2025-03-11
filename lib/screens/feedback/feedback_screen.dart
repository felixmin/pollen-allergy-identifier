import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_allergy_identifier/models/feedback_model.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';  // Add this import for Completer and TimeoutException
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
// Conditionally import dart:html for web
import 'dart:html' if (dart.library.io) 'dart:io' as platform;
// JS interop for direct browser access on web
import 'dart:js_util' as js_util;
import 'dart:js' as js;

// Added function for release-mode logging
void geoLog(String message, {Object? error}) {
  // This will show in release mode console
  // ignore: avoid_print
  print('GEO_LOG: $message');
  
  // Also log to developer console in debug mode
  developer.log(message, name: 'GeoLocation', error: error);
}

// Added fallback for web geolocation using JS interop
Future<Position?> getBrowserLocationFallback() async {
  geoLog('🌐 Using browser fallback for geolocation');
  
  if (!kIsWeb) {
    geoLog('❌ Browser fallback only works on web platform');
    return null;
  }
  
  try {
    // Check if the helper function is available
    if (!js.context.hasProperty('getBrowserGeolocation')) {
      geoLog('❌ Browser helper function not found');
      return null;
    }
    
    geoLog('Calling browser geolocation helper...');
    
    // Call the JS function and await the Promise result
    final result = await js_util.promiseToFuture(
      js_util.callMethod(js.context, 'getBrowserGeolocation', [])
    );
    
    geoLog('✅ Browser geolocation success: ${json.encode(result)}');
    
    // Convert the JS result to a Position object
    final position = Position(
      latitude: result['latitude'],
      longitude: result['longitude'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        result['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      accuracy: result['accuracy'] ?? 0.0,
      altitude: result['altitude'] ?? 0.0,
      heading: result['heading'] ?? 0.0,
      speed: result['speed'] ?? 0.0,
      speedAccuracy: result['speedAccuracy'] ?? 0.0,
      // These are required parameters in Position
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
      floor: null,
      isMocked: false,
    );
    
    geoLog('✅ Converted to Position object: ${position.latitude}, ${position.longitude}');
    return position;
  } catch (e) {
    geoLog('❌ Browser geolocation error in fallback: $e');
    
    // Try to extract error message from JS error
    String errorMessage = 'Unknown error';
    try {
      // Use toString for any error type
      errorMessage = e.toString();
      geoLog('Error message: $errorMessage');
    } catch (formatError) {
      geoLog('Error formatting JS error: $formatError');
    }
    
    // Rethrow with more info
    throw Exception('Browser geolocation error: $errorMessage');
  }
}

// Add a direct browser geolocation fallback method
Future<Position?> getDirectBrowserLocation() async {
  geoLog('🔎 Using direct browser geolocation API');
  
  if (!kIsWeb) {
    geoLog('❌ Direct browser geolocation only works on web platform');
    return null;
  }
  
  try {
    // Create a completer to handle the asynchronous geolocation call
    final Completer<Position> completer = Completer<Position>();
    
    // Get the navigator object
    final navigator = js.context['navigator'];
    
    // Check if geolocation is available
    if (navigator == null || !js.context.hasProperty('navigator') || 
        !js_util.hasProperty(navigator, 'geolocation')) {
      geoLog('❌ Browser geolocation API not available');
      return null;
    }
    
    final geolocation = js_util.getProperty(navigator, 'geolocation');
    
    // Set up a timeout for the geolocation request
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        geoLog('⏱️ Geolocation request timed out');
        completer.completeError(TimeoutException('Geolocation request timed out'));
      }
    });
    
    // Define success callback
    final success = js.allowInterop((position) {
      if (timeoutTimer != null) {
        timeoutTimer.cancel();
      }
      
      if (completer.isCompleted) return;
      
      try {
        final coords = js_util.getProperty(position, 'coords');
        
        final latitude = js_util.getProperty(coords, 'latitude');
        final longitude = js_util.getProperty(coords, 'longitude');
        final accuracy = js_util.getProperty(coords, 'accuracy');
        final altitude = js_util.hasProperty(coords, 'altitude') ? 
            js_util.getProperty(coords, 'altitude') : 0.0;
        final heading = js_util.hasProperty(coords, 'heading') ? 
            js_util.getProperty(coords, 'heading') : 0.0;
        final speed = js_util.hasProperty(coords, 'speed') ? 
            js_util.getProperty(coords, 'speed') : 0.0;
        
        geoLog('✅ Direct browser geolocation success: lat=$latitude, lng=$longitude, acc=$accuracy');
        
        final geoPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: accuracy,
          altitude: altitude,
          heading: heading,
          speed: speed,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
          floor: null,
          isMocked: false,
        );
        
        completer.complete(geoPosition);
      } catch (e) {
        geoLog('❌ Error processing geolocation result: $e');
        completer.completeError(e);
      }
    });
    
    // Define error callback
    final error = js.allowInterop((e) {
      if (timeoutTimer != null) {
        timeoutTimer.cancel();
      }
      
      if (completer.isCompleted) return;
      
      String errorMsg = 'Unknown geolocation error';
      int? code;
      
      try {
        if (js_util.hasProperty(e, 'code')) {
          code = js_util.getProperty(e, 'code');
          
          if (code == 1) {
            errorMsg = 'Permission denied';
          } else if (code == 2) {
            errorMsg = 'Position unavailable';
          } else if (code == 3) {
            errorMsg = 'Timeout';
          }
        }
        
        if (js_util.hasProperty(e, 'message')) {
          errorMsg = js_util.getProperty(e, 'message');
        }
      } catch (e2) {
        geoLog('Error extracting geolocation error details: $e2');
      }
      
      geoLog('❌ Geolocation error: $errorMsg (code: $code)');
      completer.completeError(Exception(errorMsg));
    });
    
    // Options for geolocation request
    final options = js.JsObject.jsify({
      'enableHighAccuracy': true,
      'timeout': 15000,
      'maximumAge': 0
    });
    
    // Call getCurrentPosition
    geoLog('Calling navigator.geolocation.getCurrentPosition...');
    js_util.callMethod(geolocation, 'getCurrentPosition', [success, error, options]);
    
    return await completer.future;
  } catch (e) {
    geoLog('❌ Error with direct browser geolocation: $e');
    return null;
  }
}

// Simplest possible approach for web geolocation
Future<Position?> getSimpleDirectLocation() async {
  geoLog('📍 Using simplified direct browser geolocation');
  
  if (!kIsWeb) {
    geoLog('❌ Simple direct browser geolocation only works on web');
    return null;
  }
  
  try {
    // Check if the window object has our direct function
    if (!js.context.hasProperty('getLocationDirect')) {
      geoLog('❌ Direct location function not found in window');
      return null;
    }
    
    geoLog('Calling simple direct geolocation...');
    
    // Call the JavaScript function directly
    final jsResult = await js_util.promiseToFuture(
      js.context.callMethod('getLocationDirect', [])
    );
    
    geoLog('✅ Simple direct geolocation successful!');
    
    // Extract location data from the position object
    final coords = js_util.getProperty(jsResult, 'coords');
    final latitude = js_util.getProperty(coords, 'latitude') as double;
    final longitude = js_util.getProperty(coords, 'longitude') as double;
    final accuracy = js_util.getProperty(coords, 'accuracy') as double;
    
    geoLog('Location: $latitude, $longitude (accuracy: $accuracy)');
    
    // Create a Position object with the data
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
      floor: null,
      isMocked: false,
    );
  } catch (e) {
    geoLog('❌ Simple direct geolocation failed: $e');
    return null;
  }
}

// Even simpler global geolocation method
Future<Position?> getGlobalWebLocation() async {
  geoLog('🌍 Using global web location object');
  
  if (!kIsWeb) {
    geoLog('This approach only works on web');
    return null;
  }
  
  try {
    geoLog('Checking if flutterGeoLocation is available...');
    
    // Check if our global object exists
    if (!js.context.hasProperty('flutterGeoLocation')) {
      geoLog('❌ flutterGeoLocation global object not found');
      return null;
    }
    
    final geoObj = js.context['flutterGeoLocation'];
    
    // First check if we already have a position stored
    final hasPosition = js_util.callMethod(geoObj, 'hasPosition', []);
    if (hasPosition == true) {
      geoLog('✅ Using cached position from global object');
      final pos = js_util.callMethod(geoObj, 'getLastPosition', []);
      return _convertJsPositionToGeolocator(pos);
    }
    
    // Otherwise request a new position
    geoLog('Requesting fresh position from browser...');
    final positionPromise = js_util.callMethod(geoObj, 'getCurrentPosition', []);
    final positionResult = await js_util.promiseToFuture(positionPromise);
    
    geoLog('✅ Got fresh position from browser');
    return _convertJsPositionToGeolocator(positionResult);
  } catch (e) {
    geoLog('❌ Error accessing global geolocation: $e');
    return null;
  }
}

// Helper to convert JS position to Geolocator Position
Position _convertJsPositionToGeolocator(dynamic jsPosition) {
  final lat = js_util.getProperty(jsPosition, 'latitude');
  final lng = js_util.getProperty(jsPosition, 'longitude');
  final acc = js_util.getProperty(jsPosition, 'accuracy');
  
  geoLog('Converting JS position to Geolocator Position: lat=$lat, lng=$lng');
  
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: acc,
    altitude: 0.0,
    heading: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
    altitudeAccuracy: 0.0,
    headingAccuracy: 0.0,
    floor: null,
    isMocked: false,
  );
}

// Replace getBrowserLocationFallback and any other getGlobalStateLocation methods with:

Future<Position?> getLocationFromService() async {
  geoLog('🔄 Using robust GeoLocationService module');
  
  if (!kIsWeb) {
    geoLog('❌ This approach only works on web');
    return null;
  }
  
  try {
    // Check if our GeoLocationService exists
    if (!js.context.hasProperty('GeoLocationService')) {
      geoLog('❌ GeoLocationService not found, falling back to global variables');
      // Fall back to the old globals approach
      return _getLocationFromGlobals();
    }
    
    final geoService = js.context['GeoLocationService'];
    
    // First check if we already have a valid position
    final hasPositionFn = js_util.callMethod(geoService, 'hasPosition', []);
    final bool hasPosition = hasPositionFn is bool ? hasPositionFn : false;
    
    if (hasPosition) {
      geoLog('✅ Position already available in GeoLocationService');
      
      // Get the position using the service
      final dynamic posObj = js_util.callMethod(geoService, 'getPosition', []);
      if (posObj == null) {
        throw Exception('Position returned null despite hasPosition being true');
      }
      
      final latitude = js_util.getProperty(posObj, 'latitude');
      final longitude = js_util.getProperty(posObj, 'longitude');
      final accuracy = js_util.getProperty(posObj, 'accuracy');
      
      geoLog('📍 Got position from service: lat=$latitude, lng=$longitude, accuracy=$accuracy');
      
      return Position(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy ?? 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
        timestamp: DateTime.now(),
        floor: null,
        isMocked: false,
      );
    }
    
    // No position available, request a new one
    geoLog('🔄 No position available, requesting new position from service...');
    
    // Get current status to see what's happening
    final status = js_util.callMethod(geoService, 'getStatus', []);
    geoLog('Current status: $status');
    
    if (status == 'loading') {
      // If already loading, wait briefly
      geoLog('⏱️ Position is currently loading, waiting briefly...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Check again after waiting
      final newStatus = js_util.callMethod(geoService, 'getStatus', []);
      geoLog('Status after waiting: $newStatus');
      
      if (newStatus == 'success') {
        // Success! Get the position
        return await getLocationFromService();
      } else if (newStatus == 'loading') {
        // Still loading, wait a bit longer
        await Future.delayed(const Duration(milliseconds: 1200));
        return await getLocationFromService();
      } else if (newStatus == 'error') {
        // Error occurred
        final errorMsg = js_util.callMethod(geoService, 'getError', []);
        throw Exception('Error getting location: $errorMsg');
      }
    }
    
    // If not already loading or if waiting didn't help, request a new position
    geoLog('🔄 Explicitly requesting new position...');
    
    try {
      // Call updatePosition and wait for the Promise to resolve
      final updatePromise = js_util.callMethod(geoService, 'updatePosition', []);
      final result = await js_util.promiseToFuture(updatePromise);
      
      geoLog('✅ Successfully updated position: ${json.encode(result)}');
      
      // Get the values from the result
      final latitude = js_util.getProperty(result, 'latitude');
      final longitude = js_util.getProperty(result, 'longitude');
      final accuracy = js_util.getProperty(result, 'accuracy');
      
      return Position(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy ?? 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
        timestamp: DateTime.now(),
        floor: null,
        isMocked: false,
      );
    } catch (e) {
      geoLog('❌ Error updating position: $e');
      
      // Check if there's a more detailed error message
      final errorMsg = js_util.callMethod(geoService, 'getError', []);
      throw Exception('Failed to get location: $errorMsg');
    }
  } catch (e) {
    geoLog('❌ Error in getLocationFromService: $e');
    
    // Fall back to the old globals approach as a last resort
    try {
      geoLog('Trying fallback to global variables approach...');
      return await _getLocationFromGlobals();
    } catch (fallbackError) {
      geoLog('❌ Even fallback failed: $fallbackError');
      rethrow;
    }
  }
}

// Private method using the original globals approach as fallback
Future<Position?> _getLocationFromGlobals() async {
  geoLog('🧪 Using fallback to direct global variables');
  
  try {
    // Try to read the global variables directly
    final dynamic status = js.context['geoStatus'];
    geoLog('🔍 Current geo status from globals: $status');
    
    if (status == 'success') {
      // Get the values directly from global variables
      final latitude = js.context['geoLatitude'];
      final longitude = js.context['geoLongitude'];
      final accuracy = js.context['geoAccuracy'];
      
      geoLog('📍 Got location from globals: lat=$latitude, lng=$longitude');
      
      if (latitude == null || longitude == null) {
        throw Exception('Invalid coordinates from global variables');
      }
      
      return Position(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy ?? 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
        timestamp: DateTime.now(),
        floor: null,
        isMocked: false,
      );
    } else if (status == 'loading') {
      // Wait a moment and check again
      geoLog('⏱️ Location is loading in globals, waiting briefly...');
      await Future.delayed(const Duration(milliseconds: 800));
      return _getLocationFromGlobals();
    } else if (status == 'error') {
      // Get the error message
      final errorMsg = js.context['geoError'];
      geoLog('❌ Location error from globals: $errorMsg');
      throw Exception('Geolocation error: $errorMsg');
    } else {
      // Try to trigger a geolocation request if we have the function
      geoLog('🔄 Unknown status in globals, trying to trigger request...');
      
      if (js.context.hasProperty('getDirectPosition')) {
        js.context.callMethod('getDirectPosition');
        
        // Wait a moment for the request to complete
        await Future.delayed(const Duration(seconds: 1));
        return _getLocationFromGlobals();
      } else {
        throw Exception('No way to request location through globals');
      }
    }
  } catch (e) {
    geoLog('❌ Error in global variables fallback: $e');
    rethrow;
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _isLoading = false;
  int _symptomScore = 1; // Default to middle value
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  String? _errorMessage;
  bool _hasSubmittedToday = false;
  bool _useManualLocation = false;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    // Always try to get location when the screen loads, even on web
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  // Check location permissions and get current location
  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationError = null;
      });
    }

    try {
      geoLog('🗺️ Getting current location');
      Position? position;

      // Special handling for web platform
      if (kIsWeb) {
        geoLog('Running on web platform');
        
        // Try the robust geolocation service approach
        geoLog('Using GeoLocationService with fallback mechanisms...');
        try {
          position = await getLocationFromService();
          geoLog('✅ GeoLocationService successfully provided location');
        } catch (e) {
          geoLog('GeoLocationService approach failed: $e');
          
          // Clear error message for user
          throw Exception('Failed to get location. Please try again or use manual location entry.');
        }
      } else {
        // Mobile platform flow (unchanged)
        geoLog('Running on mobile platform');
        
        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          geoLog('❌ Location services are disabled');
          throw Exception('Location services are disabled. Please enable them in your device settings.');
        }

        // Check for permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          geoLog('⚠️ Location permission denied, requesting permission...');
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            geoLog('❌ Location permission denied after request');
            throw Exception('Location permission denied. Please enable location permission for this app.');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          geoLog('❌ Location permission permanently denied');
          throw Exception('Location permission permanently denied. Please enable location permission in app settings.');
        }

        // Get position from Geolocator
        geoLog('Getting position from Geolocator...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        geoLog('✅ Got position from Geolocator: ${position.latitude}, ${position.longitude}');
      }

      // If we got here, we have a valid position
      if (position != null && mounted) {
        geoLog('Setting state with position: ${position.latitude}, ${position.longitude}');
        
        // Store position for non-null case (satisfies linter)
        final nonNullPosition = position;
        
        setState(() {
          _currentPosition = nonNullPosition;
          _latitudeController.text = nonNullPosition.latitude.toString();
          _longitudeController.text = nonNullPosition.longitude.toString();
          _isLoadingLocation = false;
        });
      } else {
        throw Exception('Unable to get location data');
      }
    } catch (e) {
      geoLog('❌ Error getting location: $e');
      
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = _getLocationErrorMessage(e);
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      double latitude;
      double longitude;

      // If using automatic location, use the currentPosition
      if (!_useManualLocation) {
        if (_currentPosition == null) {
          throw Exception('Location not available. Please try again or switch to manual entry.');
        }
        latitude = _currentPosition!.latitude;
        longitude = _currentPosition!.longitude;
      } else {
        // Using manual coordinates
        if (_latitudeController.text.isEmpty || _longitudeController.text.isEmpty) {
          throw Exception('Please enter valid coordinates');
        }

        try {
          latitude = double.parse(_latitudeController.text);
          longitude = double.parse(_longitudeController.text);
        } catch (e) {
          throw Exception('Please enter valid numeric coordinates');
        }
      }

      // Basic validation for latitude and longitude
      if (latitude < -90 || latitude > 90) {
        throw Exception('Latitude must be between -90 and 90');
      }

      if (longitude < -180 || longitude > 180) {
        throw Exception('Longitude must be between -180 and 180');
      }

      // Create the payload with the exact format expected by the backend
      final payload = {
        'feedback': _symptomScore,
        'location': {
          'lat': latitude,
          'lng': longitude,
        },
      };

      // Log the payload for debugging
      developer.log('Payload: ${jsonEncode(payload)}');
      
      // Verify the payload structure matches what the backend expects
      developer.log('Feedback type: ${_symptomScore.runtimeType}');
      developer.log('Latitude type: ${latitude.runtimeType}');
      developer.log('Longitude type: ${longitude.runtimeType}');

      // Get the Firebase Functions instance
      final functions = FirebaseFunctions.instance;
      
      // Create a reference to the 'submitFeedback' callable function
      final callable = functions.httpsCallable('submitFeedback');
      
      developer.log('Calling Firebase function: submitFeedback');
      developer.log('Payload: ${jsonEncode(payload)}');

      // Call the function with the payload
      final result = await callable.call(payload);
      
      developer.log('Function result: ${jsonEncode(result.data)}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully'),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e) {
      // Handle Firebase Functions specific errors
      developer.log('Firebase Functions error', error: e);
      developer.log('Error code: ${e.code}');
      developer.log('Error message: ${e.message}');
      developer.log('Error details: ${e.details}');
      
      setState(() {
        _errorMessage = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      developer.log('Error submitting feedback', error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
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
                if (_hasSubmittedToday)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Daily Limit Reached',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You have already submitted feedback today. Please come back tomorrow to submit again.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                const Text(
                  'How are your allergy symptoms today?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSymptomOption(
                      0,
                      'No Symptoms',
                      Icons.sentiment_very_satisfied,
                    ),
                    _buildSymptomOption(1, 'Mild', Icons.sentiment_satisfied),
                    _buildSymptomOption(
                      2,
                      'Severe',
                      Icons.sentiment_very_dissatisfied,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Location section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Text(
                              _useManualLocation ? 'Manual Entry' : 'Auto Detect',
                              style: TextStyle(
                                color: _useManualLocation 
                                    ? Colors.grey 
                                    : Theme.of(context).colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                            Switch(
                              value: _useManualLocation,
                              onChanged: (value) {
                                setState(() {
                                  _useManualLocation = value;
                                  if (!value && _currentPosition == null && !kIsWeb) {
                                    // If switching to auto mode and we don't have a location
                                    _getCurrentLocation();
                                  }
                                });
                              },
                              activeColor: Colors.grey,
                              inactiveThumbColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Show auto location controls (specific message for web)
                    if (!_useManualLocation) ...[
                      if (kIsWeb && _currentPosition == null && _locationError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Browser Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Location request might have been blocked. If you don\'t see a permission prompt, check your browser settings or try the button below.',
                                style: TextStyle(fontSize: 14),
                              ),
                              SizedBox(height: 12),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                                  icon: Icon(Icons.my_location),
                                  label: Text('Request Location Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Show location error if any
                      if (_locationError != null && !kIsWeb)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location Error: $_locationError',
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You can try again or switch to manual entry.',
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            ],
                          ),
                        ),
                      
                      // Show loading indicator when getting location
                      if (_isLoadingLocation)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: const Row(
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Getting your current location...'),
                            ],
                          ),
                        ),
                      
                      // Show current location when available
                      if (_currentPosition != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    'Current Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Spacer(),
                                  TextButton.icon(
                                    icon: Icon(Icons.refresh, size: 16),
                                    label: Text('Refresh'),
                                    onPressed: _getCurrentLocation,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size(0, 0),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                                style: TextStyle(fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                    
                    // If using manual entry, show the input fields
                    if (_useManualLocation) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Please enter your current coordinates:',
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                          if (kIsWeb) // Add sample location button for easy testing on web
                            TextButton(
                              onPressed: () {
                                // Use a generic San Francisco coordinate for testing
                                setState(() {
                                  _latitudeController.text = '37.7749';
                                  _longitudeController.text = '-122.4194';
                                });
                              },
                              child: const Text('Use Sample Location'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Desktop layout: Two columns for location inputs
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latitudeController,
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g., 37.7749',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _longitudeController,
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g., -122.4194',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                              ),
                            ),
                          ],
                        )
                      // Mobile layout: Stacked inputs
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _latitudeController,
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                                hintText: 'e.g., 37.7749',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _longitudeController,
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                                hintText: 'e.g., -122.4194',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ],
                        ),
                        
                      const SizedBox(height: 8),
                      const Text(
                        'Tip: You can find your coordinates using Google Maps or other mapping services.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text(
                              'SUBMIT FEEDBACK',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomOption(int value, String label, IconData icon) {
    final isSelected = _symptomScore == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _symptomScore = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get user-friendly error messages for location errors
  String _getLocationErrorMessage(dynamic error) {
    geoLog('Creating user-friendly error message for: $error');
    String errorStr = error.toString();
    
    if (kIsWeb) {
      // Web-specific error messages
      if (errorStr.contains('permission') || errorStr.contains('Permission')) {
        return 'Please allow location access in your browser when prompted. Some browsers may hide this prompt in the address bar.';
      } else if (errorStr.contains('timeout') || errorStr.contains('Timeout')) {
        return 'Location request timed out. Please ensure location is enabled in your device/browser settings.';
      } else if (errorStr.contains('position unavailable') || errorStr.contains('Position unavailable')) {
        return 'Could not determine your location. Your browser might have blocked the request.';
      } else if (errorStr.contains('MissingPluginException')) {
        return 'Your browser might not support location services. Try switching to manual entry.';
      }
    }
    
    // Generic error messages for all platforms
    if (errorStr.contains('permission') || errorStr.contains('Permission')) {
      return 'Location permission denied. Please enable location permissions for this app.';
    } else if (errorStr.contains('service') || errorStr.contains('Service')) {
      return 'Location services are disabled. Please enable them in your device settings.';
    }
    
    // If we can't determine a specific error, truncate the message to a reasonable length
    return 'Error getting location: ${errorStr.substring(0, math.min(errorStr.length, 100))}...';
  }
}
