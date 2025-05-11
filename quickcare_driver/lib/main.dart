// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:quickcare_driver/firebase_options.dart';
import 'package:quickcare_driver/screens/wrapper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:quickcare_driver/services/document_upload_service.dart';
import 'package:quickcare_driver/services/firebase_storage_debug_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle Firebase initialization with proper error handling
  FirebaseApp? app;
  try {
    app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully: ${app.name}');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing with existing instance');
    } else {
      print('Error initializing Firebase: $e');
      // Consider adding a way to show this error to users
    }
  }

  // Initialize Firebase Storage
  try {
    final storage = FirebaseStorage.instance;
    print('Firebase Storage Bucket: ${storage.bucket}');

    // Configure Firebase Storage settings
    storage.setMaxUploadRetryTime(const Duration(seconds: 30));
    storage.setMaxDownloadRetryTime(const Duration(seconds: 30));
    storage.setMaxOperationRetryTime(const Duration(seconds: 30));

    // Initialize our document upload service
    await DocumentUploadService.initializeStorage();

    // Optional: Run debug check in development mode only
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      await FirebaseStorageDebugService.debugStorageSetup();
    }

    print('Firebase Storage initialized successfully');
  } catch (e) {
    print('Error initializing Firebase Storage: $e');
    // We'll continue even if storage fails - might just impact document uploads
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartAmbulance Driver',
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFE53935),
        useMaterial3: true,
      ),
      home: const DriverWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}