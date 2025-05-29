import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static String get _senderEmail => dotenv.env['SENDER_EMAIL'] ?? "";
  static String get _senderPassword => dotenv.env['SENDER_PASSWORD'] ?? "";

  static Future<void> sendEmergencyAlert({
    required String userName,
    required Position userLocation,
    required String userPhone,
    required String emergencyEmail,
    String? additionalNotes,
  }) async {
    // Validate email configuration
    if (_senderEmail.isEmpty) {
      throw Exception('Sender email not configured. Please check your .env file and ensure SENDER_EMAIL is set.');
    }

    if (_senderPassword.isEmpty) {
      throw Exception('Sender password not configured. Please check your .env file and ensure SENDER_PASSWORD is set.');
    }

    // Validate emergency email
    if (emergencyEmail.isEmpty) {
      throw Exception('No emergency email provided. Please update your medical profile with an emergency contact email.');
    }

    try {
      final smtpServer = gmail(_senderEmail, _senderPassword);

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final message = Message()
        ..from = Address(_senderEmail, 'QuickCare Emergency Alert')
        ..recipients.add(emergencyEmail)
        ..subject = '🚨 EMERGENCY ALERT - Immediate Assistance Required'
        ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h1 style="color: #E53935; text-align: center;">⚠️ EMERGENCY ALERT</h1>
            <div style="background-color: #f8f8f8; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <h2 style="color: #333;">User Details:</h2>
              <ul style="list-style: none; padding: 0;">
                <li><strong>Name:</strong> $userName</li>
                <li><strong>Phone:</strong> $userPhone</li>
                <li><strong>Email:</strong> ${user.email}</li>
              </ul>
              
              <h2 style="color: #333;">Location:</h2>
              <ul style="list-style: none; padding: 0;">
                <li><strong>Latitude:</strong> ${userLocation.latitude}</li>
                <li><strong>Longitude:</strong> ${userLocation.longitude}</li>
                <li><strong>Google Maps:</strong> <a href="https://www.google.com/maps?q=${userLocation.latitude},${userLocation.longitude}">View Location</a></li>
              </ul>
              
              ${additionalNotes != null && additionalNotes.isNotEmpty ? '''
              <h2 style="color: #333;">Medical Information:</h2>
              <p>$additionalNotes</p>
              ''' : ''}
            </div>
            <p style="color: #E53935; text-align: center; font-weight: bold;">
              This is an automated emergency alert. Please respond immediately!
            </p>
            <p style="color: #666; text-align: center; font-size: 12px;">
              Sent from QuickCare Emergency Alert System
            </p>
          </div>
        ''';

      final sendReport = await send(message, smtpServer);
      print('Emergency alert email sent successfully to $emergencyEmail');
      return;
    } catch (e) {
      print('Error sending emergency alert email: $e');
      rethrow;
    }
  }
} 