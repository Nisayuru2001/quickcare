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
import '../trip/ambulance_booking_details_screen.dart';
import '../../services/ambulance_booking_service.dart';
import 'package:geolocator/geolocator.dart'; // Import GeoPoint
import 'package:flutter/services.dart';


class DriverHomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const DriverHomeScreen({
    super.key,
    this.initialTabIndex = 0
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _authInstance = FirebaseAuth.instance;

  // Modern design colors
  final Color primaryColor = const Color(0xFFE53935); // Modern red

  List<Map<String, dynamic>> _emergencyRequests = [];
  List<Map<String, dynamic>> _ambulanceBookings = [];
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _activeBooking;
  bool _isLoading = true;
  bool _isDarkMode = false;
  late int _currentIndex; // Index for BottomNavigationBar
  String? _driverName;
  late TabController _tabController; // Controller for TabBar

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _emergencyRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _ambulanceBookingsSubscription;

  late List<Widget> _mainScreens; // List of main screens for IndexedStack

  // Add this field to track driver status
  String _driverStatus = 'pending'; // Default to pending

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _tabController = TabController(length: 2, vsync: this);

    _loadDriverStatus();
    _loadThemePreference();
    _loadDriverProfile();
    _setupEmergencyRequestsListener();
    _setupAmbulanceBookingsListener();
    _checkForActiveTrip();
    _checkForActiveBooking();

    // Initialize main screens
    _initializeMainScreens();

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

    // Set status bar to transparent
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    // Cancel stream subscription to prevent memory leaks
    _emergencyRequestsSubscription?.cancel();
    _ambulanceBookingsSubscription?.cancel();
    _tabController.dispose();
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

  Future<void> _loadDriverStatus() async {
    try {
      String userId = _authInstance.currentUser!.uid;
      DocumentSnapshot doc = await _firestore.collection('driver_profiles').doc(userId).get();

      if (doc.exists) {
        setState(() {
          _driverStatus = (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
        });
      }
    } catch (e) {
      print('Error loading driver status: $e');
    }
  }

  void _initializeMainScreens() {
    // Initialize with placeholder widgets that will be built during build phase
    _mainScreens = [
      Container(), // Will be replaced with home content
      const TripHistoryScreen(),
      const DriverProfileScreen(),
    ];
  }

  // Set up a real-time listener for emergency requests
  void _setupEmergencyRequestsListener() {
    setState(() => _isLoading = true);

    try {
      // Only set up listener if driver is approved
      if (_driverStatus != 'approved') {
        setState(() {
          _emergencyRequests = [];
          _isLoading = false;
        });
        return;
      }

      // Create a real-time stream for pending emergency requests
      _emergencyRequestsSubscription = _firestore
          .collection('emergency_requests')
          .where('status', isEqualTo: 'pending')
          .where('driverId', isNull: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
        setState(() {
          _emergencyRequests = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>
                  })
              .toList();
          _isLoading = false;
        });
        }
      }, onError: (error) {
        print('Error in emergency requests stream: $error');
        if (mounted) {
        setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      print('Error setting up emergency requests listener: $e');
      if (mounted) {
      setState(() => _isLoading = false);
      }
    }
  }

  void _setupAmbulanceBookingsListener() {
    try {
      // Only set up listener if driver is approved
      if (_driverStatus != 'approved') {
        setState(() {
          _ambulanceBookings = [];
        });
        return;
      }

      _ambulanceBookingsSubscription = _firestore
          .collection('ambulance_bookings')
          .where('status', isEqualTo: 'pending')
          .where('driverId', isNull: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _ambulanceBookings = snapshot.docs
                .map((doc) => {
                      'id': doc.id,
                      'patientName': doc.data()['patientName'] ?? 'Unknown',
                      'patientPhone': doc.data()['patientPhone'] ?? 'None',
                      'injuredPersons': doc.data()['injuredPersons'] ?? '0',
                      'location': doc.data()['location'],
                      'status': doc.data()['status'] ?? 'pending',
                      'emergencyType': doc.data()['emergencyType'] ?? 'Emergency',
                    })
                .toList();
          });
        }
      }, onError: (error) {
        print('Error in ambulance bookings stream: $error');
      });
    } catch (e) {
      print('Error setting up ambulance bookings listener: $e');
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
    } finally {
      // Ensure UI updates after check
      if(mounted) setState(() {});
    }
  }

  Future<void> _checkForActiveBooking() async {
    try {
      _activeBooking = await AmbulanceBookingService.getActiveBooking();
    } catch (e) {
      print('Error checking for active booking: $e');
    } finally {
      // Ensure UI updates after check
       if(mounted) setState(() {});
    }
  }

  // Use this for manual refresh if needed
  Future<void> _fetchEmergencyRequests() async {
    setState(() => _isLoading = true);

    try {
      // Only fetch if driver is approved
      if (_driverStatus != 'approved') {
        setState(() {
          _emergencyRequests = [];
          _isLoading = false;
        });
        return;
      }

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

  // Manual refresh for ambulance bookings
  Future<void> _fetchAmbulanceBookings() async {
    setState(() => _isLoading = true);

    try {
      // Only fetch if driver is approved
      if (_driverStatus != 'approved') {
        setState(() {
          _ambulanceBookings = [];
          _isLoading = false;
        });
        return;
      }

      QuerySnapshot querySnapshot = await _firestore
          .collection('ambulance_bookings')
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _ambulanceBookings = querySnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>
                })
            .toList();
        _isLoading = false;
      });

      await _checkForActiveBooking();
    } catch (e) {
      print('Error fetching ambulance bookings: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleTheme(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
      DriverThemeService.setDarkMode(isDarkMode);
    });
  }

  Future<void> _acceptEmergencyRequest(Map<String, dynamic> request) async {
    try {
      String driverId = _authInstance.currentUser!.uid;
      String requestId = request['id'];

      // First update the request status
      await _firestore
          .collection('emergency_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'driverId': driverId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Initialize location tracking
      await LocationService.updateInitialLocation(requestId);
      await LocationService.startTracking(requestId);

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
          // Stop location tracking
          await LocationService.stopTracking();
          
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
      
      // Stop location tracking in case of error
      await LocationService.stopTracking();

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

  Future<void> _acceptAmbulanceBooking(Map<String, dynamic> booking) async {
    try {
      await AmbulanceBookingService.acceptBooking(booking['id']);

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AmbulanceBookingDetailsScreen(
              booking: booking,
            ),
          ),
        );

        if (result == true) {
          await _checkForActiveBooking();
          // Stay on Home tab or switch to History if appropriate
          // setState(() { _currentIndex = 1; }); // Uncomment to switch to history
        } else {
          await _checkForActiveBooking();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ambulance booking accepted'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('Error accepting ambulance booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept booking: $e'),
            backgroundColor: primaryColor,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    await Future.wait<void>([
      _fetchEmergencyRequests(),
      _fetchAmbulanceBookings(),
      _checkForActiveTrip(),
      _checkForActiveBooking(),
    ]);
  }

  void _navigateToEmergencyDetails(Map<String, dynamic> request) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyDetailsScreen(emergencyRequest: request),
      ),
    );

    // When returning from emergency details, refresh the data
    if (mounted) {
      // Remove the request from the local list immediately
      setState(() {
        _emergencyRequests.removeWhere((r) => r['id'] == request['id']);
      });
      
      // Then refresh all data to ensure everything is in sync
      _refreshData();
    }
  }

  void _navigateToBookingDetails(Map<String, dynamic> booking) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmbulanceBookingDetailsScreen(booking: booking),
      ),
    );

    // When returning from booking details, refresh the data
    if (mounted) {
      // Remove the booking from the local list immediately
      setState(() {
        _ambulanceBookings.removeWhere((b) => b['id'] == booking['id']);
      });
      
      // Then refresh all data to ensure everything is in sync
      _refreshData();
    }
  }

  // Helper methods to build different parts of the UI

  Widget _buildHomeContent() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    // If driver is not approved, show pending/rejected screen
    if (_driverStatus != 'approved') {
      return _buildPendingApprovalScreen();
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _refreshData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Modern App Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Driver Info and Status
        Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                    color: primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.drive_eta_outlined,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _driverName ?? 'Driver',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Active',
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification Badge
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: textColor,
                              size: 28,
                            ),
                            onPressed: () {
                              // Show notifications panel
                              _showNotificationsPanel();
                            },
                          ),
                          // Notification Badge
                          if (_hasUnreadNotifications())
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                    ),
        ),
      ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quick Stats Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildQuickStat(
                          icon: Icons.emergency_outlined,
                          label: 'Emergency\nRequests',
                          value: _emergencyRequests.length.toString(),
                          textColor: textColor,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: textColor.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        _buildQuickStat(
                          icon: Icons.calendar_today_outlined,
                          label: 'Pending\nBookings',
                          value: _ambulanceBookings.length.toString(),
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: textColor.withOpacity(0.5),
                indicatorColor: primaryColor,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Emergency'),
                  Tab(text: 'Bookings'),
                ],
              ),
            ),
          ),

          // Tab View Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Emergency Requests Tab
                _buildEmergencyRequestsList(cardColor, textColor),
                
                // Ambulance Bookings Tab
                _buildAmbulanceBookingsList(cardColor, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Expanded(
      child: Row(
      children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
                      color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 12,
                  height: 1.2,
                    ),
        ),
      ],
          ),
        ],
      ),
    );
  }

  // Add this method to check for unread notifications
  bool _hasUnreadNotifications() {
    // TODO: Implement actual notification checking logic
    return _emergencyRequests.isNotEmpty || _ambulanceBookings.isNotEmpty;
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final Color bgColor = isDarkMode ? Colors.grey[900]! : Colors.white;
        final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
      child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
          Text(
                      'Notifications',
            style: TextStyle(
                        color: textColor,
                        fontSize: 20,
              fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Mark all as read
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Mark all as read',
                        style: TextStyle(
              color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (_emergencyRequests.isNotEmpty)
                      _buildNotificationItem(
                        icon: Icons.emergency_outlined,
                        title: 'New Emergency Request',
                        message: 'You have ${_emergencyRequests.length} new emergency request(s)',
                        time: 'Now',
                        textColor: textColor,
                      ),
                    if (_ambulanceBookings.isNotEmpty)
                      _buildNotificationItem(
                        icon: Icons.calendar_today_outlined,
                        title: 'New Ambulance Booking',
                        message: 'You have ${_ambulanceBookings.length} new booking(s)',
                        time: 'Now',
                        textColor: textColor,
                      ),
                    if (_emergencyRequests.isEmpty && _ambulanceBookings.isEmpty)
          Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
            child: Text(
                            'No new notifications',
              style: TextStyle(
                              color: textColor.withOpacity(0.6),
                fontSize: 16,
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
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        // Switch to appropriate tab based on notification type
        setState(() {
          _tabController.index = title.contains('Emergency') ? 0 : 1;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
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
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 14,
            ),
          ),
        ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: textColor.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyRequestsList(Color cardColor, Color textColor) {
    if (_emergencyRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency_outlined,
              size: 64,
              color: textColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No emergency requests',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _emergencyRequests.length,
      itemBuilder: (context, index) {
        final request = _emergencyRequests[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: cardColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToEmergencyDetails(request),
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
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                      ),
                          child: Icon(
                            Icons.emergency,
                            color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Request',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request['status'] ?? 'Unknown',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: textColor.withOpacity(0.3),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: textColor.withOpacity(0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            request['pickup_location'] ?? 'Unknown location',
                            style: TextStyle(
                              color: textColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
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

  Widget _buildAmbulanceBookingsList(Color cardColor, Color textColor) {
    if (_ambulanceBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency_outlined,
              size: 64,
              color: textColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No emergency requests',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ambulanceBookings.length,
      itemBuilder: (context, index) {
        final booking = _ambulanceBookings[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: cardColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToBookingDetails(booking),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emergency Info Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.emergency_outlined,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Request',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${booking['injuredPersons']} injured',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Patient Information
                    _buildInfoRow(
                      Icons.person_outline,
                      'Patient: ${booking['patientName']}',
                      textColor,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.phone_outlined,
                      'Contact: ${booking['patientPhone']}',
                      textColor,
                    ),
                    const SizedBox(height: 8),

                    // Location
                    if (booking['location'] != null)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        _formatLocation(booking['location']),
                        textColor,
                      ),

                    const SizedBox(height: 12),
                    // Accept Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _acceptAmbulanceBooking(booking),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Accept Emergency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  String _formatLocation(dynamic location) {
    if (location is List && location.length == 2) {
      return '${location[0]}°N, ${location[1]}°W';
    }
    return 'Location not available';
  }

  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
            children: [
        Icon(
          icon,
          size: 16,
          color: textColor.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingApprovalScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pending_actions,
            size: 80,
            color: primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            _driverStatus == 'rejected' 
                ? 'Application Rejected'
                : 'Approval Pending',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _driverStatus == 'rejected'
                  ? 'Your application has been rejected. Please contact support for more information.'
                  : 'Your application is under review. You will be notified once approved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Refresh status
              _loadDriverStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Check Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildActiveTripOverlay() {
    final trip = _activeTrip ?? _activeBooking;
    if (trip == null) return const SizedBox.shrink();

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);

    return Positioned.fill(
      child: Container(
        color: Colors.black54, // Dark overlay background
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _activeTrip != null ? Icons.local_hospital : Icons.medical_services_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _activeTrip != null ? 'Active Emergency Trip' : 'Active Ambulance Booking',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    Icons.person_outline,
                    'Patient Name',
                    trip['userName'] ?? trip['patientName'] ?? 'Unknown', // Handle both keys
                    textColor,
                  ),
                  const SizedBox(height: 8),
                   _buildDetailRow(
                    Icons.location_on_outlined,
                    _activeTrip != null ? 'Patient Location' : 'Pickup Location',
                     _activeTrip != null
                        ? (trip['location'] != null ? '${(trip['location'] as GeoPoint).latitude.toStringAsFixed(4)} N, ${(trip['location'] as GeoPoint).longitude.toStringAsFixed(4)} W' : 'Unknown')
                        : trip['pickupAddress'] ?? 'Unknown', // Use pickupAddress for booking
                    textColor,
                  ),
                   if (_activeBooking != null)
                     Padding(
                       padding: const EdgeInsets.only(top: 8.0),
                       child: _buildDetailRow(
                          Icons.flag_outlined,
                          'Destination',
                          trip['destinationAddress'] ?? 'Unknown',
                          textColor,
                        ),
                     ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to active trip details screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => _activeTrip != null
                                ? EmergencyDetailsScreen(
                                    emergencyRequest: trip,
                                  )
                                : AmbulanceBookingDetailsScreen(
                                    booking: trip,
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
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 80,
            color: textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: textColor.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (title.contains('Emergency')) {
                _fetchEmergencyRequests();
              } else {
                _fetchAmbulanceBookings(); // Call fetch for bookings
              }
            },
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

    // Update the home content here where we have access to the theme
    _mainScreens[0] = _buildHomeContent();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Theme(
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

              // Use IndexedStack for the main content based on bottom navigation
              SafeArea(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _mainScreens, // Use _mainScreens here
                ),
              ),

              // Active trip/booking overlay positioned on top
              if (_activeTrip != null || _activeBooking != null)
                _buildActiveTripOverlay(),
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

                    // If switching to Home tab (index 0), refresh data
                    if (index == 0) {
                      _refreshData();
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
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}