import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickcare_driver/services/location_service.dart';

class DriverAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );

      // Debug: Print user info
      print('User signed in: ${result.user?.uid}');
      print('User email: ${result.user?.email}');

      // Check if user has a driver profile
      DocumentSnapshot driverDoc = await _firestore
          .collection('driver_profiles')
          .doc(result.user!.uid)
          .get();

      if (!driverDoc.exists) {
        // This means user exists in auth but not as a driver - throw an error
        throw FirebaseAuthException(
            code: 'not-a-driver',
            message: 'This account is not registered as a driver.'
        );
      }

      // Start location tracking after successful login
      LocationService.initLocationTracking();

      return result;
    } catch (e) {
      print('Sign in error: $e');
      throw e;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String licenseNumber,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      // Create driver profile in Firestore
      await _createDriverProfile(
        uid: result.user!.uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        licenseNumber: licenseNumber,
      );

      // Start location tracking
      LocationService.initLocationTracking();

      return result;
    } catch (e) {
      throw e;
    }
  }

  // Create driver profile
  Future<void> _createDriverProfile({
    required String uid,
    required String email,
    required String fullName,
    required String phoneNumber,
    required String licenseNumber,
  }) async {
    return await _firestore.collection('driver_profiles').doc(uid).set({
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'licenseNumber': licenseNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending', // Initial status pending until approved by admin
      'isVerified': false,
      'rating': 0.0,
      'totalTrips': 0,
    });
  }

  // Update driver profile
  Future<void> updateDriverProfile({
    String? fullName,
    String? phoneNumber,
    String? licenseNumber,
    String? policeReportUrl,
    String? drivingLicenseUrl,
  }) async {
    User? user = _auth.currentUser;

    if (user == null) {
      throw Exception("No authenticated user found");
    }

    Map<String, dynamic> data = {};

    if (fullName != null && fullName.isNotEmpty) {
      data['fullName'] = fullName;
    }

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      data['phoneNumber'] = phoneNumber;
    }

    if (licenseNumber != null && licenseNumber.isNotEmpty) {
      data['licenseNumber'] = licenseNumber;
    }

    if (policeReportUrl != null) {
      data['policeReportUrl'] = policeReportUrl;
    }

    if (drivingLicenseUrl != null) {
      data['drivingLicenseUrl'] = drivingLicenseUrl;
    }

    if (data.isNotEmpty) {
      data['updatedAt'] = FieldValue.serverTimestamp();

      // Check if the document exists first
      DocumentSnapshot docSnapshot = await _firestore
          .collection('driver_profiles')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        // Document exists, update it
        await _firestore
            .collection('driver_profiles')
            .doc(user.uid)
            .update(data);
      } else {
        // Document doesn't exist, create it
        // Add email field which is required for new profiles
        data['email'] = user.email;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['status'] = 'pending';
        data['isVerified'] = false;
        data['rating'] = 0.0;
        data['totalTrips'] = 0;

        await _firestore
            .collection('driver_profiles')
            .doc(user.uid)
            .set(data);
      }

      // Also update driver name and phone in driver_locations for map display
      if (fullName != null || phoneNumber != null) {
        Map<String, dynamic> locationData = {};

        if (fullName != null) {
          locationData['driverName'] = fullName;
        }

        if (phoneNumber != null) {
          locationData['phoneNumber'] = phoneNumber;
        }

        if (locationData.isNotEmpty) {
          try {
            await _firestore
                .collection('driver_locations')
                .doc(user.uid)
                .update(locationData);
          } catch (error) {
            // If document doesn't exist, create it
            if (error is FirebaseException && error.code == 'not-found') {
              await _firestore
                  .collection('driver_locations')
                  .doc(user.uid)
                  .set({
                ...locationData,
                'driverId': user.uid,
                'isOnline': false,
                'timestamp': FieldValue.serverTimestamp(),
              });
            } else {
              // Log other errors
              print("Warning: Couldn't update driver_locations: $error");
            }
          }
        }
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Stop location tracking and mark as offline
    await LocationService.stopLocationTracking();

    // Sign out from Firebase Auth
    return await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}