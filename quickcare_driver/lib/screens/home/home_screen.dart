// File: lib/screens/home/home_screen.dart (Driver App)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickcare_driver/screens/profile/driver_profile_screen.dart';
import 'package:quickcare_driver/screens/trip/trip_history_screen.dart';
import 'package:quickcare_driver/services/driver_theme_service.dart';
import 'package:quickcare_driver/services/location_service.dart';
import 'package:quickcare_driver/services/firebase_debug_service.dart';
import 'package:quickcare_driver/screens/emergency/emergency_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


class DriverHomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const DriverHomeScreen({
    super.key,
    this.initialTabIndex = 0
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _authInstance = FirebaseAuth.instance;

  // Modern design colors
  final Color primaryColor = const Color(0xFFE53935); // Modern red

  List<Map<String, dynamic>> _emergencyRequests = [];
  Map<String, dynamic>? _activeTrip;
  bool _isLoading = true;
  bool _isDarkMode = false;
  late int _currentIndex;
  String? _driverName;

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _emergencyRequestsSubscription;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _loadThemePreference();
    _loadDriverProfile();
    _setupEmergencyRequestsListener(); // Use a listener instead of a one-time fetch
    _checkForActiveTrip();
    _initializeScreens();

    // Add this new code for location tracking
    LocationService.initLocationTracking().then((success) {
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services for this app to work properly'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    // Cancel stream subscription to prevent memory leaks
    _emergencyRequestsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('darkMode') ?? false;
      });
    } catch (e) {
      print('Error loading theme preference: $e');
      // Use default value
      setState(() {
        _isDarkMode = false;
      });
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      String userId = _authInstance.currentUser!.uid;
      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(userId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _driverName = data['fullName'];
        });
      }
    } catch (e) {
      print('Error loading driver profile: $e');
    }
  }

  void _initializeScreens() {
    _screens = [
      _buildPlaceholderScreen(), // Placeholder that will be replaced in build()
      const TripHistoryScreen(),
      const DriverProfileScreen(),
    ];
  }

  Widget _buildPlaceholderScreen() {
    return Center(
      child: CircularProgressIndicator(
        color: primaryColor,
      ),
    );
  }

  // Set up a real-time listener for emergency requests
  void _setupEmergencyRequestsListener() {
    setState(() => _isLoading = true);

    try {
      // Create a real-time stream for pending emergency requests
      _emergencyRequestsSubscription = _firestore
          .collection('emergency_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _emergencyRequests = snapshot.docs
              .map((doc) => {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>
          })
              .toList();
          _isLoading = false;
        });
      }, onError: (error) {
        print('Error in emergency requests stream: $error');
        setState(() => _isLoading = false);
      });
    } catch (e) {
      print('Error setting up emergency requests listener: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkForActiveTrip() async {
    try {
      String driverId = _authInstance.currentUser!.uid;

      QuerySnapshot querySnapshot = await _firestore
          .collection('emergency_requests')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _activeTrip = {
            'id': querySnapshot.docs[0].id,
            ...querySnapshot.docs[0].data() as Map<String, dynamic>,
          };
        });
      } else {
        setState(() {
          _activeTrip = null;
        });
      }
    } catch (e) {
      print('Error checking for active trip: $e');
    }
  }

  // Use this for manual refresh if needed
  Future<void> _fetchEmergencyRequests() async {
    setState(() => _isLoading = true);

    try {
      // Fetch pending emergency requests
      QuerySnapshot querySnapshot = await _firestore
          .collection('emergency_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _emergencyRequests = querySnapshot.docs
            .map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        })
            .toList();
        _isLoading = false;
      });

      // Also refresh active trip
      await _checkForActiveTrip();
    } catch (e) {
      print('Error fetching emergency requests: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleTheme(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
      DriverThemeService.setDarkMode(isDarkMode);
    });
  }

  // Update this method in your home_screen.dart file

  Future<void> _acceptEmergencyRequest(Map<String, dynamic> request) async {
    try {
      // Update request status
      await _firestore
          .collection('emergency_requests')
          .doc(request['id'])
          .update({
        'status': 'accepted',
        'driverId': _authInstance.currentUser!.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to emergency details screen
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyDetailsScreen(
              emergencyRequest: request,
            ),
          ),
        );

        // If the trip was completed (result == true)
        if (result == true) {
          // Refresh data and switch to history tab
          await _fetchEmergencyRequests();
          await _checkForActiveTrip();

          setState(() {
            _currentIndex = 1; // Switch to History tab
          });
        } else {
          // Just refresh the data
          await _fetchEmergencyRequests();
          await _checkForActiveTrip();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Emergency request accepted',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error accepting emergency request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to accept request: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildEmergencyRequestsScreen() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Column(
      children: [
        // Welcome header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and app name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded( // 👈 this allows the left row to use remaining space
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.drive_eta_outlined,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible( // 👈 avoids the text from overflowing
                          child: Text(
                            'SmartAmbulance Driver',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min, // 👈 avoid extra space
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: textColor.withOpacity(0.7),
                        ),
                        onPressed: _fetchEmergencyRequests,
                      ),
                      IconButton(
                        icon: Icon(
                          _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: textColor,
                        ),
                        onPressed: () => _toggleTheme(!_isDarkMode),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                'Hello, ${_driverName ?? 'Driver'}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                _activeTrip != null
                    ? 'You have an active emergency trip'
                    : 'Ready to respond to emergencies?',
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        // Active trip card
        if (_activeTrip != null)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildActiveTripCard(_activeTrip!, cardColor, textColor),
          ),

        // Emergency Requests Section
        Expanded(
          child: _isLoading
              ? Center(
            child: CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          )
              : _emergencyRequests.isEmpty
              ? _buildEmptyState(textColor)
              : RefreshIndicator(
            onRefresh: _fetchEmergencyRequests,
            color: primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _emergencyRequests.length,
              itemBuilder: (context, index) {
                var request = _emergencyRequests[index];
                return _buildEmergencyRequestCard(request, cardColor, textColor);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTripCard(Map<String, dynamic> trip, Color cardColor, Color textColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Emergency',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Patient: ${trip['userName'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to active trip details screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyDetailsScreen(
                        emergencyRequest: trip,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Resume Navigation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emergency_outlined,
            size: 80,
            color: textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Emergency Requests',
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests will appear here',
            style: TextStyle(
              color: textColor.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchEmergencyRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyRequestCard(
      Map<String, dynamic> request,
      Color cardColor,
      Color textColor
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Details Header
            Row(
              children: [
                Icon(
                  Icons.emergency_outlined,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emergency Request',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Patient Name
            _buildDetailRow(
              Icons.person_outline,
              'Patient Name',
              request['userName'] ?? 'Unknown',
              textColor,
            ),

            const SizedBox(height: 12),

            // Medical Information
            Text(
              'Medical Details',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.bloodtype_outlined,
              'Blood Type',
              request['medicalInfo']?['bloodType'] ?? 'Unknown',
              textColor,
            ),
            _buildDetailRow(
              Icons.medical_information_outlined,
              'Allergies',
              request['medicalInfo']?['allergies'] ?? 'None',
              textColor,
            ),
            _buildDetailRow(
              Icons.medical_services_outlined,
              'Medical Conditions',
              request['medicalInfo']?['medicalConditions'] ?? 'None',
              textColor,
            ),

            const SizedBox(height: 16),

            // Accept Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _acceptEmergencyRequest(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Accept Emergency Request',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColorThemed = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color surfaceColor = isDarkMode ? Colors.grey[850]! : const Color(0xFFF8F9FA);

    // Update the first screen here, safely in the build method
    if (_screens.isNotEmpty) {
      _screens[0] = _buildEmergencyRequestsScreen();
    }

    return Theme(
      data: DriverThemeService.getThemeData(_isDarkMode),
      child: Scaffold(
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
            SafeArea(child: _screens[_currentIndex]),
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

                  // If switching to Home tab, refresh data
                  if (index == 0) {
                    _fetchEmergencyRequests();
                  }
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
                    icon: Icon(Icons.history_outlined),
                    activeIcon: Icon(Icons.history),
                    label: 'History',
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