import 'package:flutter/material.dart';
import 'package:quickcare_user/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final Function toggleView;

  const RegisterScreen({super.key, required this.toggleView});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Modern design colors
  final Color primaryColor = const Color(0xFFE53935); // Modern red
  final Color surfaceColor = const Color(0xFFF8F9FA); // Light background
  final Color textColor = const Color(0xFF212121); // Deep text color
  final Color subtleColor = const Color(0xFFEEEEEE); // Subtle element color

  String firstName = '';
  String lastName = '';
  String email = '';
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
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
                strokeWidth: 3,
              ),
            )
                : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App bar with back button
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
                            Icons.medical_services_outlined,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Quick Care',
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
                      'Create an Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please fill in the details to get started',
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
                          // First name & Last name labels
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputLabel('First Name'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInputLabel('Last Name'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // First name & Last name fields
                          Row(
                            children: [
                              // First name
                              Expanded(
                                child: TextFormField(
                                  decoration: _buildInputDecoration('First Name', Icons.person_outline),
                                  validator: (val) => val!.isEmpty ? 'Enter first name' : null,
                                  onChanged: (val) {
                                    setState(() => firstName = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Last name
                              Expanded(
                                child: TextFormField(
                                  decoration: _buildInputDecoration('Last Name', Icons.person_outline),
                                  validator: (val) => val!.isEmpty ? 'Enter last name' : null,
                                  onChanged: (val) {
                                    setState(() => lastName = val);
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Email label and field
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

                          // Password label and field
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

                          // Confirm Password label and field
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
                                    await _auth.registerWithEmailAndPassword(email, password);
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
                                  const TextSpan(text: 'By creating an account, you agree to our '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
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