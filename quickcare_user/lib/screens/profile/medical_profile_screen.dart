import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickcare_user/services/theme_service.dart';

class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form fields
  String _fullName = '';
  String _bloodType = '';
  String _allergies = '';
  String _medicalConditions = '';
  String _medications = '';
  String _emergencyContact = '';
  String _emergencyEmail = '';
  bool _isLoading = false;

  // Blood type options
  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);

    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot doc = await _firestore.collection('user_profiles').doc(userId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _fullName = data['fullName'] ?? '';
          _bloodType = data['bloodType'] ?? '';
          _allergies = data['allergies'] ?? '';
          _medicalConditions = data['medicalConditions'] ?? '';
          _medications = data['medications'] ?? '';
          _emergencyContact = data['emergencyContact'] ?? '';
          _emergencyEmail = data['emergencyEmail'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String userId = _auth.currentUser!.uid;

      await _firestore.collection('user_profiles').doc(userId).set({
        'fullName': _fullName,
        'bloodType': _bloodType,
        'allergies': _allergies,
        'medicalConditions': _medicalConditions,
        'medications': _medications,
        'emergencyContact': _emergencyContact,
        'emergencyEmail': _emergencyEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical profile saved successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
          ),
        );

        // Go back to home screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color surfaceColor = isDarkMode ? Colors.grey[850]! : const Color(0xFFF8F9FA);
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color subtleColor = isDarkMode ? Colors.grey[800]! : const Color(0xFFEEEEEE);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // Background elements for consistency with other screens
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            )
                : Column(
              children: [
                // Modern App bar - removed back button because we're using tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        'Medical Profile',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Modern info card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: primaryColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Your medical information will be shared with emergency responders when you request help',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.8),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Personal Information section
                          _buildSectionHeader('Personal Information', textColor),

                          const SizedBox(height: 16),

                          // Full Name field
                          _buildInputLabel('Full Name', textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _fullName,
                            decoration: _buildInputDecoration('Enter your full name', Icons.person_outline, surfaceColor, primaryColor, textColor),
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Please enter your name' : null,
                            onChanged: (value) => _fullName = value,
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 24),

                          // Blood Type dropdown
                          _buildInputLabel('Blood Type', textColor),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _bloodType.isNotEmpty ? _bloodType : null,
                            decoration: _buildInputDecoration('Select blood type', Icons.bloodtype_outlined, surfaceColor, primaryColor, textColor),
                            items: _bloodTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _bloodType = value!),
                            validator: (value) =>
                            value == null ? 'Please select blood type' : null,
                            dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
                            icon: Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.6)),
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 32),

                          // Medical Details section
                          _buildSectionHeader('Medical Details', textColor),

                          const SizedBox(height: 16),

                          // Allergies field
                          _buildInputLabel('Allergies', textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _allergies,
                            decoration: _buildInputDecoration('E.g., Penicillin, Peanuts, None', Icons.coronavirus_outlined, surfaceColor, primaryColor, textColor),
                            maxLines: 2,
                            onChanged: (value) => _allergies = value,
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 24),

                          // Medical Conditions field
                          _buildInputLabel('Medical Conditions', textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _medicalConditions,
                            decoration: _buildInputDecoration('E.g., Diabetes, Asthma, None', Icons.medical_information_outlined, surfaceColor, primaryColor, textColor),
                            maxLines: 3,
                            onChanged: (value) => _medicalConditions = value,
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 24),

                          // Medications field
                          _buildInputLabel('Current Medications', textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _medications,
                            decoration: _buildInputDecoration('E.g., Insulin, Ventolin, None', Icons.medication_outlined, surfaceColor, primaryColor, textColor),
                            maxLines: 3,
                            onChanged: (value) => _medications = value,
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 32),

                          // Emergency Contact section
                          _buildSectionHeader('Emergency Contact', textColor),

                          const SizedBox(height: 16),

                          // Emergency Contact field
                          _buildInputLabel('Emergency Contact Number (For Reference)', textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _emergencyContact,
                            decoration: _buildInputDecoration(
                              'E.g., +94 7X XXX XXXX',
                              Icons.phone_outlined,
                              surfaceColor,
                              primaryColor,
                              textColor,
                              helperText: 'This number will be used for reference only',
                              helperStyle: TextStyle(color: textColor.withOpacity(0.6)),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Please enter a contact number' : null,
                            onChanged: (value) => _emergencyContact = value,
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 24),

                          // Emergency Email field
                          _buildInputLabel('Emergency Email Address (For Reference)', textColor),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _emergencyEmail,
                            decoration: _buildInputDecoration(
                              'E.g., emergency@example.com',
                              Icons.email_outlined,
                              surfaceColor,
                              primaryColor,
                              textColor,
                              helperText: 'This email will be used for reference only',
                              helperStyle: TextStyle(color: textColor.withOpacity(0.6)),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an email address';
                              }
                              // Basic email validation
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            onChanged: (value) => _emergencyEmail = value,
                            style: TextStyle(color: textColor),
                          ),

                          const SizedBox(height: 40),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _saveProfile,
                              child: const Text(
                                'Save Medical Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildInputLabel(String label, Color textColor) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor.withOpacity(0.8),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String hint,
    IconData icon,
    Color fillColor,
    Color primaryColor,
    Color textColor, {
    String? helperText,
    TextStyle? helperStyle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textColor.withOpacity(0.4),
        fontSize: 16,
      ),
      helperText: helperText,
      helperStyle: helperStyle,
      prefixIcon: Icon(icon, color: textColor.withOpacity(0.6), size: 22),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}