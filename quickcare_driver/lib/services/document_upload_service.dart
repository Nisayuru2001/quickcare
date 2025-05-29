// lib/services/document_upload_service.dart - FIXED VERSION

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DocumentUploadService {
  static FirebaseStorage? _storage;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize Firebase Storage with proper error handling
  static Future<void> initializeStorage() async {
    try {
      if (_storage != null) {
        print('Firebase Storage already initialized');
        return;
      }

      _storage = FirebaseStorage.instance;
      print('Firebase Storage instance created successfully');
      print('Storage bucket: ${_storage!.bucket}');
    } catch (e) {
      print('Error initializing Firebase Storage: $e');
      rethrow;
    }
  }

  /// Upload PDF document to Firebase Storage AND update Firestore profile
  static Future<String?> uploadPDF({
    required String userId,
    required String documentType, // 'police_report' or 'driving_license'
  }) async {
    try {
      // Ensure storage is initialized
      if (_storage == null) {
        await initializeStorage();
      }

      print('UPLOAD SERVICE: Starting PDF upload for $documentType');

      // Pick PDF file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        print('UPLOAD SERVICE: No file selected');
        return null;
      }

      print('UPLOAD SERVICE: File selected: ${result.files.single.name}');
      File file = File(result.files.single.path!);

      // Check if file exists
      if (!await file.exists()) {
        throw Exception('Selected file does not exist. Please try again.');
      }

      // Check file size (limit to 10MB)
      final fileSize = await file.length();
      print('UPLOAD SERVICE: File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
            'File size exceeds 10MB limit. Please select a smaller file.');
      }

      // Create a direct path to store the file
      String fileName = '${documentType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      String filePath = 'driver_documents/$userId/$fileName';
      print('UPLOAD SERVICE: Uploading to path: $filePath');

      Reference ref = _storage!.ref().child(filePath);

      // Upload with metadata
      UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'userId': userId,
            'documentType': documentType,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('UPLOAD SERVICE: Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
        onError: (error) {
          print('UPLOAD SERVICE: Upload progress error: $error');
        },
      );

      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        String downloadUrl = await snapshot.ref.getDownloadURL();
        print('UPLOAD SERVICE: Upload successful. URL: $downloadUrl');

        // *** CRITICAL FIX: Update Firestore document with the URL ***
        await _updateDriverProfileWithDocumentUrl(userId, documentType, downloadUrl);

        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      print('UPLOAD SERVICE ERROR: $e');

      if (e is FirebaseException) {
        String errorMessage;
        switch (e.code) {
          case 'storage/unauthorized':
            errorMessage = 'You do not have permission to upload files.';
            break;
          case 'storage/canceled':
            errorMessage = 'The upload was canceled.';
            break;
          case 'storage/retry-limit-exceeded':
            errorMessage = 'The maximum time limit on an operation was exceeded.';
            break;
          case 'storage/invalid-checksum':
            errorMessage = 'File upload failed due to mismatched checksum.';
            break;
          case 'storage/object-not-found':
            errorMessage = 'No object exists at the desired reference.';
            break;
          default:
            errorMessage = 'Upload failed: ${e.message}';
        }
        throw Exception(errorMessage);
      } else {
        throw Exception('Failed to upload file: ${e.toString()}');
      }
    }
  }

  /// *** NEW METHOD: Update driver profile with document URL ***
  static Future<void> _updateDriverProfileWithDocumentUrl(
      String userId,
      String documentType,
      String downloadUrl
      ) async {
    try {
      print('FIRESTORE UPDATE: Starting update for $documentType with URL: $downloadUrl');

      // Determine the field name
      String fieldName;
      if (documentType == 'police_report') {
        fieldName = 'policeReportUrl';
      } else if (documentType == 'driving_license') {
        fieldName = 'drivingLicenseUrl';
      } else {
        throw Exception('Unknown document type: $documentType');
      }

      // Create the update data
      Map<String, dynamic> updateData = {
        fieldName: downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('FIRESTORE UPDATE: Update data: $updateData');

      // Get document reference
      DocumentReference docRef = _firestore.collection('driver_profiles').doc(userId);

      // Check if document exists first
      DocumentSnapshot docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        print('FIRESTORE UPDATE: Document does not exist, creating new one');
        // If document doesn't exist, create it with basic structure
        updateData.addAll({
          'fullName': '',
          'email': _auth.currentUser?.email ?? '',
          'phoneNumber': '',
          'licenseNumber': '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await docRef.set(updateData);
      } else {
        // Document exists, just update it
        print('FIRESTORE UPDATE: Document exists, updating...');
        await docRef.update(updateData);
      }

      print('FIRESTORE UPDATE: Successfully updated $fieldName');

      // Verify the update worked
      DocumentSnapshot verifyDoc = await docRef.get();
      if (verifyDoc.exists) {
        Map<String, dynamic> data = verifyDoc.data() as Map<String, dynamic>;
        String? savedUrl = data[fieldName] as String?;
        print('FIRESTORE UPDATE: Verification - $fieldName = $savedUrl');

        if (savedUrl != downloadUrl) {
          throw Exception('Firestore update verification failed - URL mismatch');
        }
      } else {
        throw Exception('Document does not exist after update attempt');
      }

    } catch (e) {
      print('FIRESTORE UPDATE ERROR: Failed to update driver profile: $e');
      // Don't rethrow here - we want the upload to succeed even if Firestore fails
      // The UI can handle the case where the file exists but isn't in the profile
    }
  }

  /// Delete a document from Firebase Storage and remove URL from Firestore
  static Future<bool> deleteDocument(String url, {String? documentType, String? userId}) async {
    try {
      if (url.isEmpty) return true;

      // Initialize storage if needed
      if (_storage == null) {
        await initializeStorage();
      }

      // Get reference from URL
      Reference ref = _storage!.refFromURL(url);
      print('DELETE SERVICE: Deleting document at: ${ref.fullPath}');

      // Delete the file from storage
      await ref.delete();
      print('DELETE SERVICE: Document deleted from storage successfully');

      // If document type and user ID are provided, also remove from Firestore
      if (documentType != null && userId != null) {
        await _removeDocumentUrlFromProfile(userId, documentType);
      }

      return true;
    } catch (e) {
      print('DELETE SERVICE ERROR: $e');
      if (e is FirebaseException) {
        print('DELETE SERVICE: Firebase error code: ${e.code}');
        print('DELETE SERVICE: Firebase error message: ${e.message}');
      }
      return false;
    }
  }

  /// Remove document URL from driver profile
  static Future<void> _removeDocumentUrlFromProfile(String userId, String documentType) async {
    try {
      print('FIRESTORE DELETE: Removing $documentType URL from profile');

      String fieldName;
      if (documentType == 'police_report') {
        fieldName = 'policeReportUrl';
      } else if (documentType == 'driving_license') {
        fieldName = 'drivingLicenseUrl';
      } else {
        throw Exception('Unknown document type: $documentType');
      }

      DocumentReference docRef = _firestore.collection('driver_profiles').doc(userId);

      await docRef.update({
        fieldName: FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('FIRESTORE DELETE: Successfully removed $fieldName from profile');
    } catch (e) {
      print('FIRESTORE DELETE ERROR: Failed to remove URL from profile: $e');
      throw e;
    }
  }

  /// Get current user's document URLs from Firestore
  static Future<Map<String, String?>> getDocumentUrls() async {
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      DocumentSnapshot doc = await _firestore
          .collection('driver_profiles')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'policeReportUrl': data['policeReportUrl'] as String?,
          'drivingLicenseUrl': data['drivingLicenseUrl'] as String?,
        };
      } else {
        return {
          'policeReportUrl': null,
          'drivingLicenseUrl': null,
        };
      }
    } catch (e) {
      print('GET DOCUMENT URLS ERROR: $e');
      return {
        'policeReportUrl': null,
        'drivingLicenseUrl': null,
      };
    }
  }
}