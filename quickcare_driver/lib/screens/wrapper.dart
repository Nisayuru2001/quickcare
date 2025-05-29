// lib/screens/wrapper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickcare_driver/screens/auth/authenticate.dart';
import 'package:quickcare_driver/screens/home/home_screen.dart';
import 'package:quickcare_driver/services/location_service.dart';

class DriverWrapper extends StatelessWidget {
  const DriverWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we have arguments passed (for tab navigation)
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    final int initialTabIndex = args != null ? args as int : 0;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle connection states properly
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
            ),
          );
        }

        // Handle errors in the stream
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFE53935),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;

          if (user == null) {
            return const DriverAuthenticate();
          } else {
            // User is logged in, initialize location tracking and show home screen
            // Use a future to handle location initialization
            return FutureBuilder<bool>(
              future: LocationService.initLocationTracking(),
              builder: (context, locationSnapshot) {
                // We'll show the home screen regardless of location init result
                // But this gives us a chance to handle location permission issues
                if (locationSnapshot.hasData && locationSnapshot.data == false) {
                  // Location services failed to initialize - we'll still show the home screen
                  // but might show a warning
                  Future.microtask(() {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location services disabled. Some features may not work properly.'),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  });
                }

                return DriverHomeScreen(initialTabIndex: initialTabIndex);
              },
            );
          }
        }

        // Default loading screen
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE53935),
            ),
          ),
        );
      },
    );
  }
}