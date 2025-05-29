import 'package:flutter/material.dart';
import 'package:quickcare_driver/screens/auth/authenticate.dart';
import 'package:quickcare_driver/screens/wrapper.dart';

class AppRoutes {
  static const String home = '/';
  static const String auth = '/auth';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const DriverWrapper(),
      auth: (context) => const DriverAuthenticate(),
    };
  }
}