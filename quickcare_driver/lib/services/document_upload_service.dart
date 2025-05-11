// lib/services/document_upload_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DocumentUploadService {
  static FirebaseStorage? _storage;

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

  /// Upload PDF document to Firebase Storage
  static Future<String?> uploadPDF({
    required String userId,
    required String documentType, // 'police_report' or 'driving_license'
  }) async {
    try {
      // Ensure storage is initialized
      if (_storage == null) {
        await initializeStorage();
      }

      print('Starting PDF upload for $documentType');

      // Pick PDF file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        print('No file selected');
        return null;
      }

      print('File selected: ${result.files.single.name}');
      File file = File(result.files.single.path!);

      // Check if file exists
      if (!await file.exists()) {
        throw Exception('Selected file does not exist. Please try again.');
      }

      // Check file size (limit to 10MB)
      final fileSize = await file.length();
      print('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
            'File size exceeds 10MB limit. Please select a smaller file.');
      }

      // Create a direct path to store the file
      String fileName = '${documentType}_${DateTime
          .now()
          .millisecondsSinceEpoch}.pdf';
      String filePath = 'driver_documents/$userId/$fileName';
      print('Uploading to path: $filePath');

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
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
        onError: (error) {
          print('Upload progress error: $error');
        },
      );

      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        String downloadUrl = await snapshot.ref.getDownloadURL();
        print('Upload successful. URL: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      print('Error in uploadPDF: $e');

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
            errorMessage =
            'The maximum time limit on an operation was exceeded.';
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

  /// Delete a document from Firebase Storage
// Add this to lib/services/document_upload_service.dart
  static Future<bool> deleteDocument(String url) async {
    try {
      if (url.isEmpty) return true;

      // Initialize storage if needed
      if (_storage == null) {
        await initializeStorage();
      }

      // Get reference from URL
      Reference ref = _storage!.refFromURL(url);
      print('Deleting document at: ${ref.fullPath}');

      // Delete the file
      await ref.delete();
      print('Document deleted successfully');

      return true;
    } catch (e) {
      print('Error deleting document: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return false;
    }
  }
}