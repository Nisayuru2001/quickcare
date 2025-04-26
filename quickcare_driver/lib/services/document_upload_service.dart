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
        _storage = FirebaseStorage.instance;
      }

      print('Starting PDF upload for $documentType');
      print('Current storage bucket: ${_storage!.bucket}');

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

        // Create a unique file name with timestamp
        String fileName = '${documentType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        print('Uploading as: $fileName');

        try {
          // Try a simple upload first
          String simplePath = fileName;
          Reference simpleRef = _storage!.ref().child(simplePath);
          print('Trying simple upload to: ${simpleRef.fullPath}');

          UploadTask uploadTask = simpleRef.putFile(
            file,
            SettableMetadata(contentType: 'application/pdf'),
          );

          // Monitor upload progress
          uploadTask.snapshotEvents.listen(
                (TaskSnapshot snapshot) {
              double progress = snapshot.bytesTransferred / snapshot.totalBytes;
              print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
            },
            onError: (error) {
              print('Upload progress error: $error');
              if (error is FirebaseException) {
                print('Firebase error code: ${error.code}');
                print('Firebase error message: ${error.message}');
              }
            },
          );

          // Wait for the upload to complete
          TaskSnapshot snapshot = await uploadTask;

          if (snapshot.state == TaskState.success) {
            String downloadUrl = await snapshot.ref.getDownloadURL();
            print('Simple upload successful. URL: $downloadUrl');

            // Now try to move to the correct location
            try {
              String correctPath = 'driver_documents/$userId/$fileName';
              Reference correctRef = _storage!.ref().child(correctPath);

              // Copy to correct location
              await correctRef.putFile(file);
              String finalUrl = await correctRef.getDownloadURL();

              // Delete from root
              try {
                await simpleRef.delete();
              } catch (e) {
                print('Could not delete temporary file: $e');
              }

              print('Moved to correct location. Final URL: $finalUrl');
              return finalUrl;
            } catch (e) {
              print('Could not move file to correct location: $e');
              return downloadUrl; // Return the simple upload URL
            }
          } else {
            throw Exception('Upload failed with state: ${snapshot.state}');
          }

        } catch (e) {
          print('Upload error: $e');

          if (e is FirebaseException) {
            print('Firebase error details: ${e.code} - ${e.message}');

            // Check for specific errors
            if (e.code == 'storage/unauthorized') {
              throw Exception('User does not have permission to upload. Please check Firebase Storage rules.');
            } else if (e.code == 'storage/unauthenticated') {
              throw Exception('User not authenticated. Please log in again.');
            } else if (e.code == 'storage/bucket-not-found') {
              throw Exception('Storage bucket not found. Please check your Firebase configuration.');
            } else if (e.code == 'storage/project-not-found') {
              throw Exception('Firebase project not found. Please check your Firebase configuration.');
            }

            throw Exception('Upload failed: ${e.message}');
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