import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:quickcare_driver/firebase_options.dart';
import 'package:quickcare_driver/screens/wrapper.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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