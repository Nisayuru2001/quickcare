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
      _storage = FirebaseStorage.instance;
      print('Firebase Storage instance created successfully');
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
        _storage = FirebaseStorage.instance;
      }

      print('Starting PDF upload for $documentType');

      // Pick PDF file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
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
          throw Exception('File size exceeds 10MB limit. Please select a smaller file.');
        }

        // Validate file extension
        if (!result.files.single.name.toLowerCase().endsWith('.pdf')) {
          throw Exception('Please select a PDF file');
        }

        // Create a unique file name with timestamp
        String fileName = '${documentType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        print('Uploading as: $fileName');

        try {
          // Create reference with proper path
          String storagePath = 'driver_documents/$userId/$fileName';
          Reference ref = _storage!.ref().child(storagePath);
          print('Storage reference path: ${ref.fullPath}');

          // Set metadata
          SettableMetadata metadata = SettableMetadata(
            contentType: 'application/pdf',
            customMetadata: {
              'documentType': documentType,
              'uploadedAt': DateTime.now().toIso8601String(),
              'userId': userId,
              'fileName': result.files.single.name,
            },
          );

          // Upload the file
          UploadTask uploadTask = ref.putFile(file, metadata);

          // Monitor upload progress
          uploadTask.snapshotEvents.listen(
                (TaskSnapshot snapshot) {
              double progress = snapshot.bytesTransferred / snapshot.totalBytes;
              print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
            },
            onError: (error) {
              print('Upload progress error: $error');
              if (error is FirebaseException) {
                print('Firebase error details: ${error.code} - ${error.message}');
              }
            },
          );

          // Wait for the upload to complete
          TaskSnapshot snapshot = await uploadTask;

          // Verify upload was successful
          if (snapshot.state != TaskState.success) {
            throw Exception('Upload failed. Please try again.');
          }

          // Get the download URL
          String downloadUrl = await snapshot.ref.getDownloadURL();

          // Verify the URL is valid
          if (downloadUrl.isEmpty) {
            throw Exception('Failed to get download URL');
          }

          print('File uploaded successfully. URL: $downloadUrl');
          return downloadUrl;

        } catch (e) {
          print('Upload error: $e');

          if (e is FirebaseException) {
            print('Firebase error details: ${e.code} - ${e.message}');

            // Provide specific error messages based on Firebase error codes
            switch (e.code) {
              case 'storage/unknown':
                throw Exception('Unknown error occurred. Please ensure Firebase Storage is properly configured in your Firebase project.');
              case 'storage/object-not-found':
              // Try alternative approach if object-not-found error
                print('Attempting alternative upload approach...');
                // Create metadata again for the alternative approach
                final altMetadata = SettableMetadata(
                  contentType: 'application/pdf',
                  customMetadata: {
                    'documentType': documentType,
                    'uploadedAt': DateTime.now().toIso8601String(),
                    'userId': userId,
                    'fileName': result.files.single.name,
                  },
                );
                return await _uploadWithAlternativeApproach(file, userId, documentType, altMetadata);
              case 'storage/bucket-not-found':
                throw Exception('Storage bucket not found. Please check your Firebase Storage configuration.');
              case 'storage/project-not-found':
                throw Exception('Firebase project not found. Please check your Firebase configuration.');
              case 'storage/quota-exceeded':
                throw Exception('Storage quota exceeded. Please upgrade your Firebase plan.');
              case 'storage/unauthenticated':
                throw Exception('User not authenticated. Please log in again.');
              case 'storage/unauthorized':
                throw Exception('User does not have permission to upload. Please check Firebase Storage rules.');
              case 'storage/retry-limit-exceeded':
                throw Exception('Upload failed after multiple attempts. Please check your internet connection.');
              case 'storage/invalid-checksum':
                throw Exception('File integrity check failed. Please try again.');
              case 'storage/canceled':
                throw Exception('Upload was cancelled.');
              default:
                throw Exception('Upload failed: ${e.message}');
            }
          }

          rethrow;
        }
      } else {
        print('No file selected');
        return null;
      }
    } catch (e) {
      print('Error in uploadPDF: $e');
      if (e.toString().contains('Exception:')) {
        rethrow;
      } else {
        throw Exception('Failed to upload file: ${e.toString()}');
      }
    }
  }

  /// Alternative upload approach if the main method fails
  static Future<String?> _uploadWithAlternativeApproach(
      File file,
      String userId,
      String documentType,
      SettableMetadata metadata,
      ) async {
    try {
      // Try a simpler path structure
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = '${userId}_${documentType}_$timestamp.pdf';

      // Use root level upload first
      Reference ref = _storage!.ref().child(fileName);
      print('Trying alternative path: ${ref.fullPath}');

      UploadTask uploadTask = ref.putFile(file, metadata);
      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Now try to move it to the correct location
        try {
          String correctPath = 'driver_documents/$userId/$fileName';
          Reference correctRef = _storage!.ref().child(correctPath);

          // Copy to correct location
          await correctRef.putFile(file, metadata);

          // Delete from root
          try {
            await ref.delete();
          } catch (e) {
            print('Could not delete temporary file: $e');
          }

          // Return the correct URL
          return await correctRef.getDownloadURL();
        } catch (e) {
          // If moving fails, return the original URL
          print('Could not move file to correct location, using root URL: $e');
          return downloadUrl;
        }
      }

      throw Exception('Alternative upload approach failed');
    } catch (e) {
      print('Alternative upload failed: $e');
      rethrow;
    }
  }

  /// Delete a document from Firebase Storage
  static Future<bool> deleteDocument(String url) async {
    try {
      if (url.isEmpty) return true;

      // Get reference from URL
      Reference ref = _storage!.refFromURL(url);

      // Delete the file
      await ref.delete();

      return true;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }
}