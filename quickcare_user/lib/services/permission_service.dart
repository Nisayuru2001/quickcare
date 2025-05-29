import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> checkSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  static Future<bool> requestLocationPermission(BuildContext context) async {
    // First show our custom permission dialog
    if (!context.mounted) return false;
    
    bool? shouldRequestPermission = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QuickCare needs location permission to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Track your location for emergency services'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Deny',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            child: const Text(
              'Allow',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldRequestPermission != true) {
      return false;
    }

    // Now request the actual system permission
    var status = await Permission.location.request();
    
    // If permission is denied after the system prompt
    if (status.isDenied && context.mounted) {
      // Show settings dialog if permission was denied
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE53935),
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Location permission is required for emergency services. Please enable it in settings.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return false;
    }
    
    return status.isGranted;
  }
} 