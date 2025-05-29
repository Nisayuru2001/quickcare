// File: lib/screens/home/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickcare_user/screens/profile/medical_profile_screen.dart';
import 'package:quickcare_user/services/auth_service.dart';
import 'package:quickcare_user/services/location_service.dart';
import 'package:quickcare_user/services/theme_service.dart';
import 'package:quickcare_user/screens/first_aid_screen.dart';
import 'package:quickcare_user/screens/settings_screen.dart';
import 'package:quickcare_user/screens/ambulance_booking_screen.dart';
import 'package:quickcare_user/screens/ongoing_requests_screen.dart';
import 'package:quickcare_user/screens/emergency_loading_screen.dart';
import 'package:quickcare_user/services/email_service.dart';
import 'package:quickcare_user/screens/medical_storage_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool)? toggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    this.toggleTheme,
    this.isDarkMode = false,
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _authInstance = FirebaseAuth.instance;

  // Modern design colors - matching other screens
  final Color primaryColor = const Color(0xFFE53935); // Modern red

  bool _isRequestingHelp = false;
  bool _hasProfile = false;
  String _userName = '';
  int _currentIndex = 0;
  bool _isDarkMode = false;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _checkForProfile();
    _initializeScreens();
  }

  void _initializeScreens() {
    _screens = [
      _HomeMainScreen(
        userName: _userName,
        hasProfile: _hasProfile,
        isRequestingHelp: _isRequestingHelp,
        checkProfile: _checkForProfile,
        requestHelp: _requestEmergencyHelp,
        isDarkMode: _isDarkMode,
      ),
      const MedicalStorageScreen(),
      SettingsScreen(
        onThemeChanged: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
      const MedicalProfileScreen(),
    ];
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
      // Store theme preference
      ThemeService.setDarkMode(isDark);
      // Call parent callback if provided
      if (widget.toggleTheme != null) {
        widget.toggleTheme!(isDark);
      }
      // Recreate screens with updated theme
      _initializeScreens();
    });
  }

  Future<void> _checkForProfile() async {
    try {
      String userId = _authInstance.currentUser!.uid;
      DocumentSnapshot doc = await _firestore.collection('user_profiles').doc(userId).get();

      setState(() {
        _hasProfile = doc.exists;
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          _userName = data['fullName'] ?? 'User';
        }
      });

      // Refresh main screen content after profile check
      _initializeScreens();
    } catch (e) {
      print('Error checking profile: $e');
    }
  }

  Future<void> _requestEmergencyHelp() async {
    setState(() => _isRequestingHelp = true);

    try {
      if (!_hasProfile) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please complete your medical profile first'),
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
          setState(() => _currentIndex = 3);
        }
        setState(() => _isRequestingHelp = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission is required'),
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }
          setState(() => _isRequestingHelp = false);
          return;
        }
      }

      String userId = _authInstance.currentUser!.uid;
      DocumentSnapshot profileDoc = await _firestore.collection('user_profiles').doc(userId).get();
      Map<String, dynamic> profileData = profileDoc.data() as Map<String, dynamic>;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send emergency email
      try {
        await EmailService.sendEmergencyAlert(
          userName: profileData['fullName'] ?? 'Unknown',
          userLocation: position,
          userPhone: profileData['phoneNumber'] ?? 'Unknown',
          emergencyEmail: profileData['emergencyEmail'] ?? '',
          additionalNotes: profileData['medicalConditions'] ?? 'None',
        );
      } catch (emailError) {
        print('Error sending emergency email: $emailError');
        // Continue with the emergency request even if email fails
      }

      DocumentReference requestRef = await _firestore.collection('emergency_requests').add({
        'userId': userId,
        'requesterId': userId,
        'userName': profileData['fullName'] ?? 'Unknown',
        'location': GeoPoint(position.latitude, position.longitude),
        'status': 'pending',
        'medicalInfo': {
          'bloodType': profileData['bloodType'] ?? 'Unknown',
          'allergies': profileData['allergies'] ?? 'None',
          'medicalConditions': profileData['medicalConditions'] ?? 'None',
          'medications': profileData['medications'] ?? 'None',
        },
        'emergencyContact': profileData['emergencyContact'] ?? 'None',
        'emergencyEmail': profileData['emergencyEmail'] ?? 'None',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await requestRef.update({'id': requestRef.id});

      if (mounted) {
        // Navigate to loading screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyLoadingScreen(
              requestId: requestRef.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting help: $e'),
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingHelp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply theme based on isDarkMode
    final Color backgroundColor = _isDarkMode ? Colors.black : Colors.white;
    final Color textColorThemed = _isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color surfaceColor = _isDarkMode ? Colors.grey[850]! : const Color(0xFFF8F9FA);

    return Theme(
      data: ThemeService.getThemeData(_isDarkMode),
      child: Scaffold(
        backgroundColor: backgroundColor,
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

            // Current screen based on index
            _screens[_currentIndex],
          ],
        ),

        // Bottom Navigation Bar
        bottomNavigationBar: Container(
          height: 70, // Fixed height
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.black : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor: _isDarkMode ? Colors.grey[900] : surfaceColor,
                selectedItemColor: primaryColor,
                unselectedItemColor: textColorThemed.withOpacity(0.5),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.folder_open),
                    activeIcon: Icon(Icons.folder),
                    label: 'Medical Storage',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Home main content screen
class _HomeMainScreen extends StatelessWidget {
  final String userName;
  final bool hasProfile;
  final bool isRequestingHelp;
  final bool isDarkMode;
  final Function checkProfile;
  final Function requestHelp;

  const _HomeMainScreen({
    required this.userName,
    required this.hasProfile,
    required this.isRequestingHelp,
    required this.checkProfile,
    required this.requestHelp,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE53935);
    final Color surfaceColor = isDarkMode ? Colors.grey[850]! : const Color(0xFFF8F9FA);
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color subtleColor = isDarkMode ? Colors.grey[800]! : const Color(0xFFEEEEEE);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return SafeArea(
      child: Column(
        children: [
          // Modern app bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo and app name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_services,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Quick Care',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),

                // Buttons row
                Row(
                  children: [
                    // Debug button for testing location permissions
                    IconButton(
                      icon: Icon(
                        Icons.location_on,
                        color: textColor.withOpacity(0.7),
                        size: 24,
                      ),
                      onPressed: () async {
                        // Test location permissions with in-app dialog
                        LocationPermission permission = await Geolocator.requestPermission();
                        // Show result
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Location permission result: $permission',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    // Profile button
                    InkWell(
                      onTap: () {
                        // Use bottom navigation to go to profile tab
                        if (context.findAncestorStateOfType<_HomeScreenState>() != null) {
                          context.findAncestorStateOfType<_HomeScreenState>()!.setState(() {
                            context.findAncestorStateOfType<_HomeScreenState>()!._currentIndex = 3; // Profile tab
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: subtleColor,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 22,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main content area with Expanded to handle overflow
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  // User greeting card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.health_and_safety_outlined,
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome${userName.isNotEmpty ? ', $userName' : ''}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasProfile
                                        ? 'Your medical profile is ready'
                                        : 'Please complete your medical profile',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (!hasProfile) ... [
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                // Use bottom navigation to go to profile tab
                                if (context.findAncestorStateOfType<_HomeScreenState>() != null) {
                                  context.findAncestorStateOfType<_HomeScreenState>()!.setState(() {
                                    context.findAncestorStateOfType<_HomeScreenState>()!._currentIndex = 3; // Profile tab
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Complete Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick Access Cards
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.medical_services_outlined,
                          title: 'Medical Storage',
                          description: 'Store medical records',
                          onTap: () {
                            // Navigate to medical storage screen via tab
                            if (context.findAncestorStateOfType<_HomeScreenState>() != null) {
                              context.findAncestorStateOfType<_HomeScreenState>()!.setState(() {
                                context.findAncestorStateOfType<_HomeScreenState>()!._currentIndex = 1; // Medical Storage tab
                              });
                            }
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.local_hospital,
                          title: 'Ongoing',
                          description: 'Active requests',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OngoingRequestsScreen(),
                              ),
                            );
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Emergency instructions
                  Text(
                    hasProfile
                        ? 'In case of emergency, press the button below'
                        : 'Please complete your medical profile before requesting emergency assistance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: textColor.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Emergency button
                  _buildEmergencyButton(context),

                  const SizedBox(height: 20),

                  // Ambulance booking card
                  _buildAmbulanceBookingCard(context),

                  const SizedBox(height: 20),

                  // Information card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This will send your location and medical information to emergency responders',
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
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
    );
  }

  Widget _buildEmergencyButton(BuildContext context) {
    return Column(
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: isRequestingHelp ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                width: 180 * scale,
                height: 180 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4 + (isRequestingHelp ? 0.2 : 0)),
                      blurRadius: isRequestingHelp ? 40 : 24,
                      spreadRadius: isRequestingHelp ? 8 : 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => requestHelp(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'EMERGENCY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            isRequestingHelp
                ? 'Help is on the way'
                : 'Tap the button for immediate emergency assistance',
            key: ValueKey(isRequestingHelp),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildAmbulanceBookingCard(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadowColor: const Color(0xFFE53935).withOpacity(0.2),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AmbulanceBookingScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_taxi,
                        color: Color(0xFFE53935),
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Book Ambulance',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE53935),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Quickly book an ambulance for yourself or others',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFFE53935),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Quick access card widget
class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE53935);
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color borderColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                color: textColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}