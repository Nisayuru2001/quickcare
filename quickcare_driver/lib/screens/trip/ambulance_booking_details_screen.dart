import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/ambulance_booking_service.dart';
import 'package:intl/intl.dart';

class AmbulanceBookingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const AmbulanceBookingDetailsScreen({
    super.key,
    required this.booking,
  });

  @override
  State<AmbulanceBookingDetailsScreen> createState() => _AmbulanceBookingDetailsScreenState();
}

class _AmbulanceBookingDetailsScreenState extends State<AmbulanceBookingDetailsScreen> {
  bool _isLoading = false;
  bool _isCompleting = false;
  Position? _driverPosition;
  double _distanceToPatient = 0;
  String _estimatedTime = 'Calculating...';
  final Color primaryColor = const Color(0xFFE53935);
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

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
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _driverPosition = position;
      });

      _calculateDistanceToPatient();

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
    if (_driverPosition == null || widget.booking['location'] == null) return;

    try {
      // Handle location as GeoPoint
      GeoPoint location = widget.booking['location'];

      double distanceInMeters = Geolocator.distanceBetween(
        _driverPosition!.latitude,
        _driverPosition!.longitude,
        location.latitude,
        location.longitude,
      );

      double timeInMinutes = (distanceInMeters / 1000) / 40 * 60;

      setState(() {
        _distanceToPatient = distanceInMeters / 1000;
        _estimatedTime = timeInMinutes < 1
            ? 'Less than 1 min'
            : '${timeInMinutes.round()} mins';
      });
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  Future<void> _completeBooking() async {
    setState(() => _isCompleting = true);

    try {
      await AmbulanceBookingService.completeBooking(widget.booking['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking completed successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error completing booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing booking: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isCompleting = false);
      }
    }
  }

  Future<void> _cancelBooking() async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await AmbulanceBookingService.cancelBooking(
        widget.booking['id'],
        'Cancelled by driver',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openMapsNavigation() async {
    if (widget.booking['location'] == null) return;

    try {
      GeoPoint location = widget.booking['location'];
      final url = 'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}&travelmode=driving';

      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      print('Error opening maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _callPatient() async {
    final phone = widget.booking['patientPhone'];
    if (phone == null) return;

    final url = 'tel:$phone';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      }
    } catch (e) {
      print('Error making phone call: $e');
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color textColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withOpacity(0.3),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'accepted':
        badgeColor = Colors.blue;
        icon = Icons.check_circle;
        break;
      case 'completed':
        badgeColor = Colors.green;
        icon = Icons.done_all;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 16),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final String bookingStatus = widget.booking['status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Status Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              color: primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emergency Type: ${widget.booking['emergencyType'] ?? 'Unknown'}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(bookingStatus),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          '${_distanceToPatient.toStringAsFixed(1)} km',
                          'Distance',
                          Icons.route,
                          textColor,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          _estimatedTime,
                          'Est. Time',
                          Icons.access_time,
                          textColor,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoChip(
                          widget.booking['injuredPersons']?.toString() ?? '0',
                          'Injured',
                          Icons.personal_injury,
                          textColor,
                        ),
                      ),
                    ],
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
                    widget.booking['patientName'] ?? 'Unknown',
                    Icons.person_outline,
                    textColor,
                  ),
                  const Divider(),
                  _buildInfoRow(
                    'Contact',
                    widget.booking['patientPhone'] ?? 'None',
                    Icons.phone_outlined,
                    textColor,
                    onTap: widget.booking['patientPhone'] != null ? _callPatient : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Location Details
            Text(
              'Location Details',
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
                  InkWell(
                    onTap: _openMapsNavigation,
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.booking['location'] != null
                                    ? '${(widget.booking['location'] as GeoPoint).latitude.toStringAsFixed(6)}°N,\n${(widget.booking['location'] as GeoPoint).longitude.toStringAsFixed(6)}°W'
                                    : 'Unknown',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.navigation,
                          color: primaryColor,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // After Location Details section
            const SizedBox(height: 24),

            // Special Notes Section
            if (widget.booking['notes'] != null && widget.booking['notes'] != "No") ...[
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Special Notes',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.booking['notes'] ?? '',
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (bookingStatus.toLowerCase() == 'accepted') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openMapsNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCompleting ? null : _completeBooking,
                      icon: const Icon(Icons.check),
                      label: Text(_isCompleting ? 'Completing...' : 'Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _cancelBooking,
                  icon: const Icon(Icons.close),
                  label: Text(_isLoading ? 'Cancelling...' : 'Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String value, String label, IconData icon, Color textColor) {
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
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 