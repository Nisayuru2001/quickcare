import 'package:flutter/material.dart';
import 'package:quickcare_driver/services/auth_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  final Function toggleView;

  const DriverRegisterScreen({super.key, required this.toggleView});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final DriverAuthService _auth = DriverAuthService();
  final _formKey = GlobalKey<FormState>();

  // Modern design colors
  final Color primaryColor = const Color(0xFFE53935); // Modern red
  final Color surfaceColor = const Color(0xFFF8F9FA); // Light background
  final Color textColor = const Color(0xFF212121); // Deep text color
  final Color subtleColor = const Color(0xFFEEEEEE); // Subtle element color

  String fullName = '';
  String email = '';
  String phoneNumber = '';
  String licenseNumber = '';
  String password = '';
  String confirmPassword = '';
  String error = '';
  bool loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background elements
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
            child: loading
                ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            )
                : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App bar with Sign In button
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => widget.toggleView(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: subtleColor,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                size: 24,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.toggleView(),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Logo and welcome text
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.drive_eta_outlined,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'SmartAmbulance',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Header text
                    Text(
                      'Driver Registration',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your driver account',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withOpacity(0.6),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name field
                          _buildInputLabel('Full Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _buildInputDecoration('Enter your full name', Icons.person_outline),
                            validator: (val) => val!.isEmpty ? 'Enter your full name' : null,
                            onChanged: (val) {
                              setState(() => fullName = val);
                            },
                          ),

                          const SizedBox(height: 24),

                          // Email field
                          _buildInputLabel('Email'),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _buildInputDecoration('Email', Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val!.isEmpty) {
                                return 'Enter an email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              setState(() => email = val);
                            },
                          ),

                          const SizedBox(height: 24),

                          // Phone Number field
                          _buildInputLabel('Phone Number'),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _buildInputDecoration('Enter your phone number', Icons.phone_outlined),
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val!.isEmpty) {
                                return 'Enter your phone number';
                              }
                              // Basic phone number validation
                              if (!RegExp(r'^[+]?[(]?[0-9]{3}[)]?[-\s.]?[0-9]{3}[-\s.]?[0-9]{4,6}$').hasMatch(val)) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              setState(() => phoneNumber = val);
                            },
                          ),

                          const SizedBox(height: 24),

                          // License Number field
                          _buildInputLabel('License Number'),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _buildInputDecoration('Enter your driver\'s license number', Icons.badge_outlined),
                            validator: (val) => val!.isEmpty ? 'Enter your license number' : null,
                            onChanged: (val) {
                              setState(() => licenseNumber = val);
                            },
                          ),

                          const SizedBox(height: 24),

                          // Password field
                          _buildInputLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _buildPasswordInputDecoration(
                              'Password',
                              Icons.lock_outline,
                              _obscurePassword,
                                  () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            obscureText: _obscurePassword,
                            validator: (val) {
                              if (val!.isEmpty) {
                                return 'Enter a password';
                              }
                              if (val.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            onChanged: (val) {
                              setState(() => password = val);
                            },
                          ),

                          const SizedBox(height: 24),

                          // Confirm Password field
                          _buildInputLabel('Confirm Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: _buildPasswordInputDecoration(
                              'Confirm Password',
                              Icons.lock_outline,
                              _obscureConfirmPassword,
                                  () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            obscureText: _obscureConfirmPassword,
                            validator: (val) => val != password ? 'Passwords do not match' : null,
                            onChanged: (val) {
                              setState(() => confirmPassword = val);
                            },
                          ),

                          // Error text
                          if (error.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),

                          // Register button
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
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  setState(() => loading = true);
                                  try {
                                    await _auth.registerWithEmailAndPassword(
                                      email: email,
                                      password: password,
                                      fullName: fullName,
                                      phoneNumber: phoneNumber,
                                      licenseNumber: licenseNumber,
                                    );
                                  } catch (e) {
                                    setState(() {
                                      error = 'Registration failed. Please try again.';
                                      loading = false;
                                    });
                                  }
                                }
                              },
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Terms and conditions
                          Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'By signing up, you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' and ',
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor.withOpacity(0.8),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textColor.withOpacity(0.4),
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: textColor.withOpacity(0.6), size: 22),
      filled: true,
      fillColor: surfaceColor,
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

  InputDecoration _buildPasswordInputDecoration(
      String hint, IconData icon, bool obscureText, VoidCallback onPressed) {
    return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
        color: textColor.withOpacity(0.4),
    fontSize: 16,
    ),
    prefixIcon: Icon(icon, color: textColor.withOpacity(0.6), size: 22),
    suffixIcon: IconButton(
    icon: Icon(
    obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
    color: textColor.withOpacity(0.6),
      size: 22,
    ),
      onPressed: onPressed,
    ),
      filled: true,
      fillColor: surfaceColor,
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