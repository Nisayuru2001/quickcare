import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickcare_user/screens/profile/medical_profile_screen.dart';
import 'package:quickcare_user/services/auth_service.dart';
import 'package:quickcare_user/services/theme_service.dart';
import 'package:quickcare_user/screens/first_aid_screen.dart';
import 'package:quickcare_user/screens/settings_screen.dart';

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
    _requestLocationPermission();
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
      const FirstAidScreen(),
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

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location services are disabled.',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permissions are denied',
                style: TextStyle(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permissions are permanently denied.',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error getting location: $e',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _requestEmergencyHelp() async {
    setState(() => _isRequestingHelp = true);

    try {
      // Check if profile exists
      if (!_hasProfile) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please complete your medical profile first',
                style: TextStyle(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          // Navigate to profile tab
          setState(() => _currentIndex = 3);
        }

        setState(() => _isRequestingHelp = false);
        return;
      }

      // Get location
      Position? position = await _getCurrentLocation();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to get your location. Help request failed.',
                style: TextStyle(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        setState(() => _isRequestingHelp = false);
        return;
      }

      // Get user profile data
      String userId = _authInstance.currentUser!.uid;
      DocumentSnapshot profileDoc = await _firestore.collection('user_profiles').doc(userId).get();
      Map<String, dynamic> profileData = profileDoc.data() as Map<String, dynamic>;

      // Create emergency request
      await _firestore.collection('emergency_requests').add({
        'userId': userId,
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
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Emergency help requested! Ambulance will be dispatched soon.',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error requesting help: $e',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingHelp = false);
        // Refresh the main screen to update button state
        _initializeScreens();
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
                    icon: Icon(Icons.healing_outlined),
                    activeIcon: Icon(Icons.healing),
                    label: 'First Aid',
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
                        Icons.medical_services_outlined,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SmartAmbulance',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
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
                          icon: Icons.healing,
                          title: 'First Aid',
                          description: 'Emergency instructions',
                          onTap: () {
                            // Navigate to first aid screen via tab
                            if (context.findAncestorStateOfType<_HomeScreenState>() != null) {
                              context.findAncestorStateOfType<_HomeScreenState>()!.setState(() {
                                context.findAncestorStateOfType<_HomeScreenState>()!._currentIndex = 1; // First Aid tab
                              });
                            }
                          },
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.history,
                          title: 'History',
                          description: 'Previous requests',
                          onTap: () {
                            // Navigate to history screen
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
                  Container(
                    width: 180, // Reduced size slightly
                    height: 180, // Reduced size slightly
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: primaryColor,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      child: InkWell(
                        onTap: isRequestingHelp ? null : () => requestHelp(),
                        splashColor: Colors.white.withOpacity(0.1),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: isRequestingHelp
                            ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.emergency,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'REQUEST\nHELP',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

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