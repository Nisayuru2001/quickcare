import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class ActiveTripScreen extends StatefulWidget {
  final Map<String, dynamic> emergencyRequest;

  const ActiveTripScreen({
    super.key,
    required this.emergencyRequest,
  });

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isCompleting = false;
  Position? _driverPosition;
  double _distanceToPatient = 0;
  String _estimatedTime = '';
  final Color primaryColor = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _startLocationTracking();
  }

  Future<void> _checkLocationPermission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      // Get initial location
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _driverPosition = position;
      });

      // Calculate initial distance
      _calculateDistanceToPatient();

      // Set up position stream (continuous updates)
      Geolocator.getPositionStream().listen((Position position) {
        setState(() {
          _driverPosition = position;
        });
        _calculateDistanceToPatient();
      });
    } catch (e) {
      print('Error tracking location: $e');
    }
  }

  void _calculateDistanceToPatient() {
    if (_driverPosition == null || widget.emergencyRequest['location'] == null) return;

    try {
      GeoPoint patientLocation = widget.emergencyRequest['location'];

      // Calculate distance in km
      double distanceInMeters = Geolocator.distanceBetween(
        _driverPosition!.latitude,
        _driverPosition!.longitude,
        patientLocation.latitude,
        patientLocation.longitude,
      );

      // Calculate estimated time (approximation)
      // Assuming average speed of 40 km/h in urban areas
      double timeInMinutes = (distanceInMeters / 1000) / 40 * 60;

      setState(() {
        _distanceToPatient = distanceInMeters / 1000; // Convert to km
        _estimatedTime = timeInMinutes < 1
            ? 'Less than 1 min'
            : '${timeInMinutes.round()} mins';
      });
    } catch (e) {
      print('Error calculating distance: $e');
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

  Future<void> _cancelTrip() async {
    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('emergency_requests')
          .doc(widget.emergencyRequest['id'])
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': 'Cancelled by driver',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error cancelling trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling trip: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openMapsNavigation() async {
    if (widget.emergencyRequest['location'] == null) return;

    try {
      GeoPoint patientLocation = widget.emergencyRequest['location'];
      final url = 'https://www.google.com/maps/dir/?api=1&destination=${patientLocation.latitude},${patientLocation.longitude}&travelmode=driving';

      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      print('Error opening maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening maps: $e')),
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
          'Active Emergency',
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
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _isCompleting ? 'Completing trip...' : 'Loading...',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
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
                              'Emergency in Progress',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatusItem(
                              '${_distanceToPatient.toStringAsFixed(1)} km',
                              'Distance',
                              Icons.route,
                              textColor,
                            ),
                            _buildStatusItem(
                              _estimatedTime,
                              'Est. Time',
                              Icons.access_time,
                              textColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _openMapsNavigation,
                            icon: const Icon(Icons.navigation),
                            label: const Text(
                              'Navigate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
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

                  // Action Buttons
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _cancelTrip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Complete Button
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _completeTrip,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Complete Trip',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String value, String label, IconData icon, Color textColor) {
    return Column(
      children: [
        Icon(
          icon,
          color: primaryColor,
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
            color: primaryColor,
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