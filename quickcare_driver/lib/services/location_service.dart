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

  /// Initialize location tracking service
  static Future<bool> initLocationTracking() async {
    // Check if already tracking
    if (_isTracking) return true;

    try {
      // Check permissions
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) return false;

      // Check if location is enabled
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) return false;

      // Get current user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get current location first and update immediately
      Position initialPosition = await Geolocator.getCurrentPosition();
      await _updateDriverLocation(initialPosition, currentUser.uid, true);

      // Start listening to location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: _locationSettings
      ).listen((Position position) async {
        await _updateDriverLocation(position, currentUser.uid, true);
      });

      _isTracking = true;

      // Add app termination listener
      // Note: This is best-effort and may not always run depending on how app is terminated
      // For reliable offline detection, you'd need additional mechanisms like server heartbeats
      return true;
    } catch (e) {
      print('Error initializing location tracking: $e');
      return false;
    }
  }

  /// Check and request location permissions
  static Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  /// Update driver location in Firestore
  static Future<void> _updateDriverLocation(
      Position position,
      String driverId,
      bool isOnline
      ) async {
    try {
      // Get driver's profile document
      DocumentSnapshot driverDoc = await _firestore
          .collection('driver_profiles')
          .doc(driverId)
          .get();

      // Update driver location document
      await _firestore
          .collection('driver_locations')
          .doc(driverId)
          .set({
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
        'status': driverDoc.exists ? driverDoc['status'] : 'unknown',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  /// Stop location tracking service
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
    } catch (e) {
      print('Error stopping location tracking: $e');
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