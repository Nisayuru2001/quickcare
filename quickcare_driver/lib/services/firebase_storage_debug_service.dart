// lib/services/firebase_storage_debug_service.dart

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseStorageDebugService {
  static Future<void> debugStorageSetup() async {
    try {
      final storage = FirebaseStorage.instance;

      print('Firebase Storage Instance: ${storage.toString()}');
      print('Firebase Storage Bucket: ${storage.bucket}');

      // Try to create a test file
      Reference testRef = storage.ref().child('test/test.txt');
      await testRef.putString('Test file');
      String downloadUrl = await testRef.getDownloadURL();
      print('Test file uploaded successfully: $downloadUrl');

      // Clean up test file
      await testRef.delete();
      print('Test file deleted successfully');

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