import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:quickcare_user/firebase_options.dart';
import 'package:quickcare_user/screens/wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables with fallback options
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // If .env file is not found, load default values
    await dotenv.load(fileName: ".env.default");
  }
  
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
      title: 'QuickCare',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const Wrapper(),
    );
  }
}