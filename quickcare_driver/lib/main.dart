// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:quickcare_driver/firebase_options.dart';
import 'package:quickcare_driver/screens/wrapper.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Storage
  try {
    final storage = FirebaseStorage.instance;

    // Print storage configuration
    print('Firebase Storage Bucket: ${storage.bucket}');

    // Configure Firebase Storage settings
    storage.setMaxUploadRetryTime(const Duration(seconds: 30));
    storage.setMaxDownloadRetryTime(const Duration(seconds: 30));
    storage.setMaxOperationRetryTime(const Duration(seconds: 30));

    print('Firebase Storage initialized successfully');
  } catch (e) {
    print('Error initializing Firebase Storage: $e');
    // Handle the error appropriately - you might want to show an error screen
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
        useMaterial3: true,
      ),
      home: const DriverWrapper(),
    );
  }
}