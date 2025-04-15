import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickcare_driver/screens/auth/authenticate.dart';
import 'package:quickcare_driver/screens/home/home_screen.dart';

class DriverWrapper extends StatelessWidget {
  const DriverWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;

          if (user == null) {
            return const DriverAuthenticate();
          } else {
            // User is logged in, show home screen
            return const DriverHomeScreen();
          }
        }

        // Show loading screen while waiting for auth state
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}