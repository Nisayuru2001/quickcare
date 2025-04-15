import 'package:flutter/material.dart';
import 'package:quickcare_user/services/auth_service.dart';
import 'package:quickcare_user/screens/profile/medical_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;

  const SettingsScreen({
    required this.onThemeChanged,
    required this.isDarkMode,
    super.key,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE53935);
    final Color textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF212121);
    final Color surfaceColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[850]!
        : const Color(0xFFF8F9FA);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Settings List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme Settings
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    widget.isDarkMode
                                        ? Icons.dark_mode
                                        : Icons.light_mode,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Dark Mode',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: widget.isDarkMode,
                                activeColor: primaryColor,
                                onChanged: (value) {
                                  widget.onThemeChanged(value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Account Settings
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingItem(
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MedicalProfileScreen(),
                                ),
                              );
                            },
                            textColor: textColor,
                          ),
                          const Divider(),
                          _buildSettingItem(
                            icon: Icons.logout,
                            title: 'Log Out',
                            onTap: () async {
                              await _auth.signOut();
                              // Navigate to login screen or handle in auth stream
                            },
                            textColor: textColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // App Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSettingItem(
                            icon: Icons.info_outline,
                            title: 'App Version',
                            subtitle: '1.0.0',
                            textColor: textColor,
                          ),
                          const Divider(),
                          _buildSettingItem(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            onTap: () {
                              // Navigate to help screen
                            },
                            textColor: textColor,
                          ),
                          const Divider(),
                          _buildSettingItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: () {
                              // Navigate to privacy policy
                            },
                            textColor: textColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor.withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColor.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withOpacity(0.4),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}