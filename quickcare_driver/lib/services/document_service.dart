import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DocumentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload document to Firebase Storage and save metadata to Firestore
  static Future<void> uploadDocument(File file, String documentType) async {
    try {
      String userId = _auth.currentUser!.uid;
      String fileName = '${documentType}_$userId.pdf';
      
      // Upload file to Firebase Storage
      Reference ref = _storage.ref().child('driver_documents/$userId/$fileName');
      await ref.putFile(file);
      String downloadUrl = await ref.getDownloadURL();

      // Save metadata to Firestore
      await _firestore.collection('driver_documents').doc(userId).set({
        documentType: {
          'url': downloadUrl,
          'uploadedAt': FieldValue.serverTimestamp(),
          'fileName': fileName,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  // Delete document from both Storage and Firestore
  static Future<void> deleteDocument(String documentType) async {
    try {
      String userId = _auth.currentUser!.uid;
      String fileName = '${documentType}_$userId.pdf';

      // Delete from Storage
      Reference ref = _storage.ref().child('driver_documents/$userId/$fileName');
      await ref.delete();

      // Remove from Firestore
      await _firestore.collection('driver_documents').doc(userId).update({
        documentType: FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  // Get document metadata and URL
  static Future<Map<String, dynamic>?> getDocument(String documentType) async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot doc = await _firestore
          .collection('driver_documents')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data[documentType] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get document: $e');
    }
  }
} 