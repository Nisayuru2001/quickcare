import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickcare_driver/services/location_service.dart';

class DriverStatusManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Toggle driver's online/offline status
  static Future<bool> toggleOnlineStatus(bool isOnline) async {
    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) return false;

      if (isOnline) {
        // Driver is going online
        bool locationInitialized = await LocationService.initLocationTracking();
        if (!locationInitialized) return false;

        await _firestore.collection('driver_profiles').doc(driverId).update({
          'status': 'active',
          'lastActive': FieldValue.serverTimestamp(),
        });

        return true;
      } else {
        // Driver is going offline
        await LocationService.stopLocationTracking();

        await _firestore.collection('driver_profiles').doc(driverId).update({
          'status': 'inactive',
          'lastActive': FieldValue.serverTimestamp(),
        });

        return true;
      }
    } catch (e) {
      print('Error toggling online status: $e');
      return false;
    }
  }

  // Get driver's current status
  static Future<String> getCurrentStatus() async {
    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) return 'unknown';

      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(driverId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['status'] ?? 'unknown';
      }

      return 'unknown';
    } catch (e) {
      print('Error getting driver status: $e');
      return 'unknown';
    }
  }

  // Check if driver has an active trip
  static Future<bool> hasActiveTrip() async {
    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) return false;

      QuerySnapshot snapshot = await _firestore
          .collection('emergency_requests')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for active trip: $e');
      return false;
    }
  }
}