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

  /// List all emergency requests
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
}