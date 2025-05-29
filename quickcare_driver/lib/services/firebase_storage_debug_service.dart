// lib/services/firebase_storage_debug_service.dart

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseStorageDebugService {
  static Future<void> debugStorageSetup() async {
    try {
      final storage = FirebaseStorage.instance;

      print('Firebase Storage Instance: ${storage.toString()}');
      print('Firebase Storage Bucket: ${storage.bucket}');

      // Try to create a test file with a safer approach
      String testPath = 'test/test_file_${DateTime.now().millisecondsSinceEpoch}.txt';
      Reference testRef = storage.ref().child(testPath);

      print('Attempting to create test file at: ${testRef.fullPath}');

      // Upload a small test string
      final testContent = 'Test file created on ${DateTime.now().toIso8601String()}';

      // Use a more controlled upload process
      try {
        final uploadTask = testRef.putString(
          testContent,
          metadata: SettableMetadata(contentType: 'text/plain'),
        );

        // Wait for completion
        final snapshot = await uploadTask;

        if (snapshot.state == TaskState.success) {
          String downloadUrl = await testRef.getDownloadURL();
          print('Test file uploaded successfully: $downloadUrl');

          // Clean up test file
          await testRef.delete();
          print('Test file deleted successfully');
        } else {
          print('Test file upload completed with state: ${snapshot.state}');
        }
      } catch (uploadError) {
        print('Failed to upload test file: $uploadError');
        if (uploadError is FirebaseException) {
          print('Firebase Error Code: ${uploadError.code}');
          print('Firebase Error Message: ${uploadError.message}');
        }
      }
    } catch (e) {
      print('Firebase Storage Debug Error: $e');
      if (e is FirebaseException) {
        print('Firebase Error Code: ${e.code}');
        print('Firebase Error Message: ${e.message}');
        print('Firebase Error Plugin: ${e.plugin}');
      }
    }
  }
}