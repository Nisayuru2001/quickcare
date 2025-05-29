// lib/services/location_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static StreamSubscription<Position>? _positionStream;
  static bool _isTracking = false;
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0, // Update regardless of distance
    timeLimit: Duration(seconds: 5), // Force updates every 5 seconds
  );

  /// Initialize location tracking service with improved error handling
  static Future<bool> initLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied');
        return false;
      }

      // Start background location updates
      String? driverId = _auth.currentUser?.uid;
      if (driverId != null) {
        await startBackgroundLocationUpdates();
      } else {
        print('No driver ID found');
        return false;
      }

      return true;
    } catch (e) {
      print('Error initializing location tracking: $e');
      return false;
    }
  }

  /// Start background location updates for driver's general location
  static Future<void> startBackgroundLocationUpdates() async {
    if (_isTracking) {
      print('Already tracking location');
      return;
    }

    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) {
        print('No driver ID available for location updates');
        return;
      }

      // Get driver profile for name and phone
      DocumentSnapshot driverProfile = await _firestore
          .collection('driver_profiles')
          .doc(driverId)
          .get();

      Map<String, dynamic>? driverData = 
          driverProfile.exists ? driverProfile.data() as Map<String, dynamic> : null;

      if (driverData == null) {
        print('Driver profile not found');
        return;
      }

      // Cancel existing stream if any
      await _positionStream?.cancel();

      // Start new location stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen((Position position) async {
        try {
          // Create the location update data
          Map<String, dynamic> locationData = {
            'driverId': driverId,
            'location': GeoPoint(position.latitude, position.longitude),
            'accuracy': position.accuracy,
            'altitude': position.altitude,
            'heading': position.heading,
            'speed': position.speed,
            'timestamp': FieldValue.serverTimestamp(),
            'isOnline': true,
            'status': 'active',
            'driverName': driverData['fullName'] ?? '',
            'phoneNumber': driverData['phoneNumber'] ?? '',
          };

          // Update driver_locations collection with merge: true to ensure atomic updates
          await _firestore
              .collection('driver_locations')
              .doc(driverId)
              .set(locationData, SetOptions(merge: true));

          // Update driver's profile
          await _firestore
              .collection('driver_profiles')
              .doc(driverId)
              .update({
            'currentLocation': GeoPoint(position.latitude, position.longitude),
            'lastLocationUpdate': FieldValue.serverTimestamp(),
            'isOnline': true,
          });

          print('Location updated successfully - Lat: ${position.latitude}, Lng: ${position.longitude}');
        } catch (e) {
          print('Error updating location in Firebase: $e');
          // Attempt to restart tracking if there's an error
          _restartTracking();
        }
      }, 
      onError: (error) {
        print('Location stream error: $error');
        // Attempt to restart tracking on error
        _restartTracking();
      },
      cancelOnError: false);

      _isTracking = true;
      print('Location tracking started successfully');
    } catch (e) {
      print('Error starting background location updates: $e');
      _isTracking = false;
      // Attempt to restart tracking after a delay
      await Future.delayed(const Duration(seconds: 5));
      startBackgroundLocationUpdates();
    }
  }

  /// Restart tracking if there's an error
  static void _restartTracking() async {
    if (!_isTracking) return;
    
    print('Attempting to restart location tracking');
    _isTracking = false;
    await _positionStream?.cancel();
    _positionStream = null;
    
    await Future.delayed(const Duration(seconds: 2));
    await startBackgroundLocationUpdates();
  }

  /// Start tracking driver location for a specific emergency request
  static Future<void> startTracking(String emergencyRequestId) async {
    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) return;

      // Make sure background updates are running
      if (!_isTracking) {
        await startBackgroundLocationUpdates();
      }

      // Get current position
      Position position = await getCurrentLocation() ?? 
          await Geolocator.getCurrentPosition();

      // Update emergency request with driver location
      await _firestore
          .collection('emergency_requests')
          .doc(emergencyRequestId)
          .update({
        'driverLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error starting emergency tracking: $e');
    }
  }

  /// Stop tracking driver location
  static Future<void> stopTracking() async {
    try {
      await _positionStream?.cancel();
      _positionStream = null;
      _isTracking = false;

      // Update driver's online status in both collections
      String? driverId = _auth.currentUser?.uid;
      if (driverId != null) {
        await Future.wait([
          _firestore
              .collection('driver_profiles')
              .doc(driverId)
              .update({
            'isOnline': false,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          }),
          _firestore
              .collection('driver_locations')
              .doc(driverId)
              .update({
            'isOnline': false,
            'timestamp': FieldValue.serverTimestamp(),
          }),
        ]);
      }
    } catch (e) {
      print('Error stopping location tracking: $e');
    }
  }

  /// Get current location once
  static Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Update driver's initial location when accepting request
  static Future<void> updateInitialLocation(String emergencyRequestId) async {
    try {
      Position? position = await getCurrentLocation();
      if (position == null) return;

      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) return;

      // Get driver profile for name and phone
      DocumentSnapshot driverProfile = await _firestore
          .collection('driver_profiles')
          .doc(driverId)
          .get();

      Map<String, dynamic>? driverData = 
          driverProfile.exists ? driverProfile.data() as Map<String, dynamic> : null;

      // Update all necessary collections
      await Future.wait([
        // Update emergency request
        _firestore
            .collection('emergency_requests')
            .doc(emergencyRequestId)
            .update({
          'driverLocation': GeoPoint(position.latitude, position.longitude),
          'initialDriverLocation': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        }),

        // Update driver profile
        _firestore
            .collection('driver_profiles')
            .doc(driverId)
            .update({
          'currentLocation': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'isOnline': true,
        }),

        // Update driver locations
        _firestore
            .collection('driver_locations')
            .doc(driverId)
            .set({
          'driverId': driverId,
          'location': GeoPoint(position.latitude, position.longitude),
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'heading': position.heading,
          'speed': position.speed,
          'timestamp': FieldValue.serverTimestamp(),
          'isOnline': true,
          'status': 'active',
          'driverName': driverData?['fullName'] ?? '',
          'phoneNumber': driverData?['phoneNumber'] ?? '',
        }),
      ]);
    } catch (e) {
      print('Error updating initial location: $e');
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