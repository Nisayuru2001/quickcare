import 'package:flutter/material.dart';
import 'package:quickcare_driver/screens/auth/login_screen.dart';
import 'package:quickcare_driver/screens/auth/register_screen.dart';

class DriverAuthenticate extends StatefulWidget {
  const DriverAuthenticate({super.key});

  @override
  State<DriverAuthenticate> createState() => _DriverAuthenticateState();
}

class _DriverAuthenticateState extends State<DriverAuthenticate> {
  bool showSignIn = true;

  void toggleView() {
    setState(() => showSignIn = !showSignIn);
  }

  @override
  Widget build(BuildContext context) {
    if (showSignIn) {
      return DriverLoginScreen(toggleView: toggleView);
    } else {
      return DriverRegisterScreen(toggleView: toggleView);
    }
  }
}