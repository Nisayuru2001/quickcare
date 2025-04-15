import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickcare_driver/services/auth_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final DriverAuthService _auth = DriverAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _authInstance = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Design colors
  final Color primaryColor = const Color(0xFFE53935);
  final Color textColor = const Color(0xFF212121);
  final Color surfaceColor = const Color(0xFFF8F9FA);

  // Driver profile data
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  bool _isEditing = false;

  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverProfile() async {
    setState(() => _isLoading = true);

    try {
      String userId = _authInstance.currentUser!.uid;
      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(userId).get();

      if (doc.exists) {
        setState(() {
          _driverProfile = doc.data() as Map<String, dynamic>;
          _fullNameController.text = _driverProfile?['fullName'] ?? '';
          _phoneController.text = _driverProfile?['phoneNumber'] ?? '';
          _licenseController.text = _driverProfile?['licenseNumber'] ?? '';
          _emailController.text = _driverProfile?['email'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading driver profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Use the auth service instead of directly accessing Firestore
      await _auth.updateDriverProfile(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        licenseNumber: _licenseController.text,
      );

      setState(() => _isEditing = false);
      await _loadDriverProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColorThemed = isDarkMode ? Colors.grey[850]! : surfaceColor;
    final Color textColorThemed = isDarkMode ? Colors.white : textColor;
    final Color cardColorThemed = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Driver Profile',
                    style: TextStyle(
                      color: textColorThemed,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  if (!_isEditing)
                    IconButton(
                      icon: Icon(Icons.edit, color: primaryColor),
                      onPressed: () {
                        setState(() => _isEditing = true);
                      },
                    )
                  else
                    TextButton(
                      onPressed: _updateProfile,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            _isLoading
                ? const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE53935),
                ),
              ),
            )
                : Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _driverProfile?['fullName'] ?? 'Driver Name',
                              style: TextStyle(
                                color: textColorThemed,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_driverProfile?['status']),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _capitalizeStatus(_driverProfile?['status'] ?? 'unknown'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Profile Information Section
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          color: textColorThemed,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Full Name Field
                      _buildInputLabel('Full Name', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _buildInputDecoration(
                          'Full Name',
                          Icons.person_outline,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: _isEditing,
                        validator: (val) => val!.isEmpty ? 'Please enter your name' : null,
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 16),

                      // Phone Number Field
                      _buildInputLabel('Phone Number', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _buildInputDecoration(
                          'Phone Number',
                          Icons.phone_outlined,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val!.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 16),

                      // License Number Field
                      _buildInputLabel('License Number', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _licenseController,
                        decoration: _buildInputDecoration(
                          'License Number',
                          Icons.badge_outlined,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: _isEditing,
                        validator: (val) => val!.isEmpty ? 'Please enter your license number' : null,
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 16),

                      // Email Field (read-only)
                      _buildInputLabel('Email', textColorThemed),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        decoration: _buildInputDecoration(
                          'Email',
                          Icons.email_outlined,
                          surfaceColorThemed,
                          textColorThemed,
                        ),
                        enabled: false, // Email is always read-only
                        style: TextStyle(color: textColorThemed),
                      ),

                      const SizedBox(height: 32),

                      // Statistics Section
                      Text(
                        'Driver Statistics',
                        style: TextStyle(
                          color: textColorThemed,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Statistics Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '0',
                              'Completed\nTrips',
                              Icons.check_circle_outline,
                              cardColorThemed,
                              textColorThemed,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              '0',
                              'In Progress\nTrips',
                              Icons.pending_outlined,
                              cardColorThemed,
                              textColorThemed,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            await _auth.signOut();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
      String hint, IconData icon, Color backgroundColor, Color textColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textColor.withOpacity(0.4),
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: textColor.withOpacity(0.6), size: 22),
      filled: true,
      fillColor: backgroundColor,
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }
}