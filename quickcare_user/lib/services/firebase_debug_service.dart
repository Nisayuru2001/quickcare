import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A utility class to help debug Firebase Firestore issues
class FirebaseDebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Test if we can read from the emergency_requests collection
  static Future<bool> testEmergencyRequestsAccess({
    required BuildContext context,
    bool showSnackBar = true,
  }) async {
    try {
      // Try to read from the collection
      QuerySnapshot snapshot = await _firestore
          .collection('emergency_requests')
          .limit(1)
          .get();

      // Show success message
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firestore access successful!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return true;
    } catch (e) {
      // Show error message
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Firestore access error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('Firestore access error: $e');
      return false;
    }
  }

  /// Debug function to list all documents in the emergency_requests collection
  static Future<List<Map<String, dynamic>>> listAllEmergencyRequests() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('emergency_requests')
          .get();

      List<Map<String, dynamic>> results = snapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      })
          .toList();

      print('Found ${results.length} emergency requests');
      for (var doc in results) {
        print('Request ID: ${doc['id']}, Status: ${doc['status']}');
      }

      return results;
    } catch (e) {
      print('Error listing emergency requests: $e');
      return [];
    }
  }

  /// Check if a specific collection exists and is accessible
  static Future<bool> checkCollectionAccess(String collectionPath) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionPath)
          .limit(1)
          .get();

      print('Collection $collectionPath access successful');
      return true;
    } catch (e) {
      print('Collection $collectionPath access error: $e');
      return false;
    }
  }

  /// Log all data from an emergency request to help with debugging
  static Future<void> logEmergencyRequestDetails(String requestId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('emergency_requests')
          .doc(requestId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('=== Emergency Request Details ===');
        print('ID: $requestId');
        data.forEach((key, value) {
          print('$key: $value');
        });
      } else {
        print('Emergency request not found: $requestId');
      }
    } catch (e) {
      print('Error getting emergency request details: $e');
    }
  }

  /// Create a test emergency request for debugging
  static Future<String?> createTestEmergencyRequest({
    required BuildContext context,
    bool showSnackBar = true,
  }) async {
    try {
      // Create a test emergency request
      DocumentReference ref = await _firestore.collection('emergency_requests').add({
        'userId': 'test_user_id',
        'userName': 'Test User',
        'location': const GeoPoint(37.4219999, -122.0840575), // Example coordinates
        'status': 'pending',
        'medicalInfo': {
          'bloodType': 'O+',
          'allergies': 'None',
          'medicalConditions': 'None',
          'medications': 'None',
        },
        'emergencyContact': '123-456-7890',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update with its own ID
      await ref.update({'id': ref.id});

      // Show success message
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test emergency request created: ${ref.id}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('Created test emergency request: ${ref.id}');
      return ref.id;
    } catch (e) {
      // Show error message
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error creating test request: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('Error creating test emergency request: $e');
      return null;
    }
  }
}