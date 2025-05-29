import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> emergencyRequest;

  const EmergencyDetailsScreen({
    Key? key,
    required this.emergencyRequest,
  }) : super(key: key);

  @override
  State<EmergencyDetailsScreen> createState() => _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState extends State<EmergencyDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isCompleting = false;
  Position? _driverPosition;
  double _distanceToPatient = 0;
  String _estimatedTime = 'Calculating...';
  final Color primaryColor = const Color(0xFFE53935);

  // Track if the request is already accepted
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
    _checkLocationPermission();
    _calculateDistanceToPatient();
  }

  Future<void> _checkRequestStatus() async {
    // Check if this emergency request is already accepted by this driver
    String currentUserId = _auth.currentUser?.uid ?? '';
    String requestId = widget.emergencyRequest['id'] ?? '';

    try {
      DocumentSnapshot docSnapshot = await _firestore
          .collection('emergency_requests')
          .doc(requestId)
          .get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;

        if (data['status'] == 'accepted' && data['driverId'] == currentUserId) {
          setState(() {
            _isAccepted = true;
          });
        }
      }
    } catch (e) {
      print('Error checking request status: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<void> _calculateDistanceToPatient() async {
    setState(() => _isLoading = true);
    try {
      // Get driver's current location
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _driverPosition = position;
      });

      // Get patient's location from the emergency request
      GeoPoint patientLocation = widget.emergencyRequest['location'];

      // Calculate distance
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        patientLocation.latitude,
        patientLocation.longitude,
      );

      // Estimate arrival time (assuming average speed of 40 km/h)
      double timeInMinutes = (distanceInMeters / 1000) / 40 * 60;

      setState(() {
        _distanceToPatient = distanceInMeters / 1000; // Convert to km
        _estimatedTime = timeInMinutes < 1
            ? 'Less than 1 min'
            : '${timeInMinutes.round()} mins';
        _isLoading = false;
      });
    } catch (e) {
      print('Error calculating distance: $e');
      setState(() {
        _isLoading = false;
        _estimatedTime = 'Unable to calculate';
      });
    }
  }

  Future<void> _acceptEmergencyRequest() async {
    setState(() => _isLoading = true);

    try {
      // Update request status in Firestore
      await _firestore
          .collection('emergency_requests')
          .doc(widget.emergencyRequest['id'])
          .update({
        'status': 'accepted',
        'driverId': _auth.currentUser!.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
        _isAccepted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error accepting request: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting request: $e')),
        );
      }
    }
  }

  Future<void> _completeTrip() async {
    setState(() => _isCompleting = true);

    try {
      await _firestore
          .collection('emergency_requests')
          .doc(widget.emergencyRequest['id'])
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip completed successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop back to home screen
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error completing trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing trip: $e')),
        );
        setState(() => _isCompleting = false);
      }
    }
  }

  Future<void> _openMapsNavigation() async {
    if (widget.emergencyRequest['location'] == null) return;

    try {
      GeoPoint patientLocation = widget.emergencyRequest['location'];

      // Format for Google Maps app navigation
      final Uri googleMapsUri = Uri.parse(
          'google.navigation:q=${patientLocation.latitude},${patientLocation.longitude}&mode=d'
      );

      // Check if Google Maps is installed
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
      } else {
        // Fallback to browser-based Google Maps
        final Uri webUri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${patientLocation.latitude},${patientLocation.longitude}&travelmode=driving'
        );

        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch maps application';
        }
      }
    } catch (e) {
      print('Error opening maps: $e');
      if (mounted) {
        // Show a fallback dialog with coordinates
        final GeoPoint patientLocation = widget.emergencyRequest['location'];
        final String coordinates = '${patientLocation.latitude}, ${patientLocation.longitude}';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Navigation Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not open Google Maps. Patient location:'),
                const SizedBox(height: 8),
                SelectableText(
                  coordinates,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Copy these coordinates to use in your maps application.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency Details',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          // Background elements for consistency
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
            child: _isLoading || _isCompleting
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emergency_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isAccepted ? 'Emergency in Progress' : 'Emergency Request',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoChip(
                              '${_distanceToPatient.toStringAsFixed(1)} km',
                              'Distance',
                              Icons.route,
                              textColor,
                            ),
                            _buildInfoChip(
                              _estimatedTime,
                              'Est. Time',
                              Icons.access_time,
                              textColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _openMapsNavigation,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Navigate to Patient'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Patient Information
                  Text(
                    'Patient Information',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
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
                        _buildInfoRow(
                          'Name',
                          widget.emergencyRequest['userName'] ?? 'Unknown',
                          Icons.person_outline,
                          textColor,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Emergency Contact',
                          widget.emergencyRequest['emergencyContact'] ?? 'None',
                          Icons.phone_outlined,
                          textColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Medical Information
                  Text(
                    'Medical Information',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
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
                        _buildInfoRow(
                          'Blood Type',
                          widget.emergencyRequest['medicalInfo']?['bloodType'] ?? 'Unknown',
                          Icons.bloodtype_outlined,
                          textColor,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Allergies',
                          widget.emergencyRequest['medicalInfo']?['allergies'] ?? 'None',
                          Icons.coronavirus_outlined,
                          textColor,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Medical Conditions',
                          widget.emergencyRequest['medicalInfo']?['medicalConditions'] ?? 'None',
                          Icons.medical_information_outlined,
                          textColor,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Medications',
                          widget.emergencyRequest['medicalInfo']?['medications'] ?? 'None',
                          Icons.medication_outlined,
                          textColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Accept/Complete Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isAccepted ? _completeTrip : _acceptEmergencyRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAccepted ? Colors.green : primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isAccepted ? 'Done' : 'Accept Emergency Request',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildInfoChip(String value, String label, IconData icon, Color textColor) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFE53935),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFE53935),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}