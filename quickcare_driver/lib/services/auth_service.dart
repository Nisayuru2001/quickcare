import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth change user stream
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email & password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in driver: $e');
      rethrow;
    }
  }

  // Register with email & password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String licenseNumber,
  }) async {
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create driver profile in Firestore
      await _firestore.collection('driver_profiles').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'licenseNumber': licenseNumber,
        'status': 'pending', // Initial status could be pending verification
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      print('Error registering driver: $e');
      rethrow;
    }
  }

  // Update driver profile
  Future<void> updateDriverProfile({
    required String fullName,
    required String phoneNumber,
    required String licenseNumber,
  }) async {
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId == null) throw 'No user signed in';

      // Check if document exists
      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(userId).get();

      if (doc.exists) {
        // Update existing document
        await _firestore.collection('driver_profiles').doc(userId).update({
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'licenseNumber': licenseNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new document
        await _firestore.collection('driver_profiles').doc(userId).set({
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'licenseNumber': licenseNumber,
          'email': _auth.currentUser?.email ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating driver profile: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out driver: $e');
      rethrow;
    }
  }

  // Get current driver profile
  Future<Map<String, dynamic>?> getCurrentDriverProfile() async {
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(userId).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('Error fetching driver profile: $e');
      return null;
    }
  }
}