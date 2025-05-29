import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LocationService {
  static LocationService? _instance;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  String? _currentDriverId;
  static const int LOCATION_DISTANCE_FILTER = 10; // 10 meters

  // Private constructor
  LocationService._();

  // Singleton factory
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  // Set current driver ID
  void setDriverId(String driverId) {
    _currentDriverId = driverId;
  }

  // Get current driver ID
  String? getCurrentDriverId() {
    return _currentDriverId;
  }

  // Cleanup method
  void dispose() {
    stopTracking();
    _currentDriverId = null;
    _instance = null;
  }

  // Start tracking for a specific driver
  void startTracking({String? driverId}) {
    if (driverId != null) {
      _currentDriverId = driverId;
    }
    
    if (_currentDriverId == null) {
      print('Error: No driver ID set for tracking');
      return;
    }

    if (_isTracking) return;
    _isTracking = true;
    _initializeLocationUpdates();
  }

  // Stop tracking
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // Initialize location updates
  void _initializeLocationUpdates() {
    if (_positionSubscription != null) {
      _positionSubscription!.cancel();
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: LOCATION_DISTANCE_FILTER,
      timeLimit: Duration(seconds: 30),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).handleError((error) {
      print('Location stream error: $error');
      return;
    }).listen(
      (Position position) async {
        try {
          if (_currentDriverId != null) {
            await updateDriverLocation(_currentDriverId!, position);
            print('Updated driver location: ${position.latitude}, ${position.longitude}');
          }
        } catch (e) {
          print('Error updating driver location: $e');
        }
      },
      onError: (error) {
        print('Location subscription error: $error');
        _isTracking = false;
      },
      cancelOnError: false,
    );
  }

  // Get current location with error handling
  static Future<Position?> getCurrentLocation({
    BuildContext? context,
    bool showErrors = true,
  }) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showErrors && context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (showErrors && context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (showErrors && context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permissions are permanently denied. Please enable them in app settings.'),
              action: SnackBarAction(
                label: 'SETTINGS',
                onPressed: () => openAppSettings(),
                textColor: Colors.white,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // Get the current position with a longer timeout
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
    } catch (e) {
      if (showErrors && context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error getting location: $e');
      return null;
    }
  }

  // Request location permissions
  static Future<bool> requestLocationPermission() async {
    try {
      // Request multiple permissions at once
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationAlways,
        Permission.locationWhenInUse,
      ].request();

      // Check if all required permissions are granted
      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
        }
      });

      return allGranted;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  // Check if location permissions are granted
  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted &&
           await Permission.locationWhenInUse.isGranted;
  }

  // Start location updates with distance filter
  static Stream<Position> getLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: LOCATION_DISTANCE_FILTER,
      timeLimit: Duration(seconds: 30), // Increased timeout
    );

    try {
      return Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).handleError((error) {
        print('Location stream error: $error');
        // Return an empty stream on error
        return Stream<Position>.empty();
      });
    } catch (e) {
      print('Error setting up location stream: $e');
      return Stream<Position>.empty();
    }
  }

  // Update driver location in Firestore
  static Future<void> updateDriverLocation(String driverId, Position position) async {
    if (driverId.isEmpty) {
      print('Error: driverId is empty');
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final driverLocationRef = FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(driverId);

      batch.set(driverLocationRef, {
        'driverId': driverId,
        'location': GeoPoint(position.latitude, position.longitude),
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'isOnline': true,
        'status': 'active',
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      print('Error updating driver location: $e');
      rethrow;
    }
  }
}