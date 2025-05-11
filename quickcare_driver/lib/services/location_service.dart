// lib/services/location_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static StreamSubscription<Position>? _positionStreamSubscription;
  static bool _isTracking = false;
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  /// Initialize location tracking service with improved error handling
  static Future<bool> initLocationTracking() async {
    // Check if already tracking
    if (_isTracking) return true;

    try {
      // Check permissions
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        print('Location permission denied');
        return false;
      }

      // Check if location is enabled
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        print('Location services disabled');
        return false;
      }

      // Get current user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user found');
        return false;
      }

      // Try to get current location with a timeout
      Position? initialPosition;
      try {
        initialPosition = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Error getting initial position: $e');
        // We'll try with last known position as fallback
        initialPosition = await Geolocator.getLastKnownPosition();

        if (initialPosition == null) {
          print('Could not get any position data');
          // We'll continue even without position data
        }
      }

      // Update driver location if we have position data
      if (initialPosition != null) {
        await _updateDriverLocation(initialPosition, currentUser.uid, true)
            .catchError((e) {
          print('Error updating initial driver location: $e');
          // Continue even if update fails
        });
      }

      // Start listening to location updates with error handling
      _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: _locationSettings
      ).listen(
            (Position position) async {
          await _updateDriverLocation(position, currentUser.uid, true)
              .catchError((e) {
            print('Error updating driver location from stream: $e');
          });
        },
        onError: (e) {
          print('Error in position stream: $e');
          // Keep _isTracking true even with errors, as the stream continues
        },
      );

      _isTracking = true;
      print('Location tracking initialized successfully');
      return true;
    } catch (e) {
      print('Error initializing location tracking: $e');
      return false;
    }
  }

  /// Check and request location permissions with improved handling
  static Future<bool> _checkLocationPermission() async {
    try {
      // First check with Permission Handler for clearer error messages
      PermissionStatus permission = await Permission.location.status;

      if (permission == PermissionStatus.denied) {
        permission = await Permission.location.request();
      }

      if (permission == PermissionStatus.permanentlyDenied) {
        print('Location permission permanently denied');
        return false;
      }

      // Fall back to Geolocator's permission handling
      if (permission != PermissionStatus.granted) {
        LocationPermission geoPermission = await Geolocator.checkPermission();

        if (geoPermission == LocationPermission.denied) {
          geoPermission = await Geolocator.requestPermission();
        }

        return geoPermission != LocationPermission.denied &&
            geoPermission != LocationPermission.deniedForever;
      }

      return true;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  /// Update driver location in Firestore with retry mechanism
  static Future<void> _updateDriverLocation(
      Position position,
      String driverId,
      bool isOnline,
      {int retryCount = 0}
      ) async {
    try {
      // Prepare location data
      Map<String, dynamic> locationData = {
        'driverId': driverId,
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
        'isOnline': isOnline,
      };

      // Try to get driver profile status if needed
      try {
        DocumentSnapshot driverDoc = await _firestore
            .collection('driver_profiles')
            .doc(driverId)
            .get();

        if (driverDoc.exists) {
          Map<String, dynamic> data = driverDoc.data() as Map<String, dynamic>;
          locationData['status'] = data['status'] ?? 'unknown';

          // Include name and phone if available for map display
          if (data.containsKey('fullName')) {
            locationData['driverName'] = data['fullName'];
          }

          if (data.containsKey('phoneNumber')) {
            locationData['phoneNumber'] = data['phoneNumber'];
          }
        } else {
          locationData['status'] = 'unknown';
        }
      } catch (e) {
        // If we can't get driver status, continue with default
        print('Error getting driver status: $e');
        locationData['status'] = 'unknown';
      }

      // Update driver location document
      await _firestore
          .collection('driver_locations')
          .doc(driverId)
          .set(locationData, SetOptions(merge: true));

    } catch (e) {
      print('Error updating driver location: $e');

      // Implement retry with backoff for network errors
      if (retryCount < 3 && e is FirebaseException) {
        final delay = Duration(seconds: 1 * (retryCount + 1));
        print('Retrying update after $delay (attempt ${retryCount + 1}/3)');
        await Future.delayed(delay);
        return _updateDriverLocation(position, driverId, isOnline, retryCount: retryCount + 1);
      } else {
        rethrow;
      }
    }
  }

  /// Stop location tracking service with improved cleanup
  static Future<void> stopLocationTracking() async {
    try {
      if (_positionStreamSubscription != null) {
        await _positionStreamSubscription!.cancel();
        _positionStreamSubscription = null;
      }

      // Mark driver as offline in the database
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get last known position
        Position? lastPosition;
        try {
          lastPosition = await Geolocator.getLastKnownPosition();
        } catch (e) {
          print('Error getting last known position: $e');
        }

        if (lastPosition != null) {
          await _updateDriverLocation(lastPosition, currentUser.uid, false);
        } else {
          // If we can't get the last position, just update the isOnline status
          await _firestore
              .collection('driver_locations')
              .doc(currentUser.uid)
              .update({
            'isOnline': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      _isTracking = false;
      print('Location tracking stopped successfully');
    } catch (e) {
      print('Error stopping location tracking: $e');
      // Reset tracking state even if there are errors
      _isTracking = false;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistance(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude
      ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Convert meters to kilometers
  }

  /// Check if location tracking is active
  static bool isTracking() {
    return _isTracking;
  }
}