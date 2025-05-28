import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quickcare_user/widgets/location_picker.dart';
import 'package:quickcare_user/screens/ambulance_tracking_screen.dart';
import 'package:quickcare_user/services/ambulance_service.dart';
import 'package:quickcare_user/widgets/finding_driver_animation.dart';
import 'package:quickcare_user/services/email_service.dart';

class AmbulanceBookingScreen extends StatefulWidget {
  const AmbulanceBookingScreen({super.key});

  @override
  State<AmbulanceBookingScreen> createState() => _AmbulanceBookingScreenState();
}

class _AmbulanceBookingScreenState extends State<AmbulanceBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _injuredController = TextEditingController();
  final _ambulanceService = AmbulanceService();
  bool _isLoading = false;
  bool _isSubmitting = false;
  LatLng? _selectedLocation;
  String? _currentRequestId;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  String _emergencyType = 'Normal Emergency'; // Use string for dropdown

  @override
  void initState() {
    super.initState();
    _checkActiveRequest();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _injuredController.dispose();
    _requestSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveRequest() async {
    setState(() => _isLoading = true);
    
    try {
      final activeRequestId = await _ambulanceService.checkActiveRequest();
      if (activeRequestId != null && mounted) {
        // Navigate to tracking screen if there's an active request
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AmbulanceTrackingScreen(
              requestId: activeRequestId,
              driverId: '',  // Initially empty, will be updated when driver accepts
            ),
          ),
        );
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (_currentRequestId == null) return;

    try {
      final success = await _ambulanceService.cancelRequest(_currentRequestId!);
      if (success && mounted) {
        setState(() {
          _isLoading = false;
          _currentRequestId = null;
        });
        _requestSubscription?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenForDriverAcceptance(String requestId) {
    _requestSubscription?.cancel();
    _requestSubscription = FirebaseFirestore.instance
        .collection('ambulance_bookings')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      final driverId = data['driverId'] as String?;

      if (status == 'accepted' && driverId != null && mounted) {
        // Get driver details from driver_profiles collection
        final driverDoc = await FirebaseFirestore.instance
            .collection('driver_profiles')
            .doc(driverId)
            .get();
            
        if (driverDoc.exists) {
          final driverData = driverDoc.data() as Map<String, dynamic>;
          
          // Update the booking with driver details
          await FirebaseFirestore.instance
              .collection('ambulance_bookings')
              .doc(requestId)
              .update({
            'driverName': driverData['fullName'] ?? '',
            'driverPhone': driverData['phoneNumber'] ?? '',
            'driverLicenseNumber': driverData['licenseNumber'] ?? '',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // Navigate to tracking screen when driver accepts
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AmbulanceTrackingScreen(
              requestId: requestId,
              driverId: driverId,
            ),
          ),
        );
      } else if (status == 'cancelled' && mounted) {
        setState(() {
          _isLoading = false;
          _currentRequestId = null;
        });
        _requestSubscription?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request was cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _bookAmbulance() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a pickup location on the map'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final requestId = await _ambulanceService.createRequest(
        patientName: _nameController.text,
        patientPhone: _phoneController.text,
        address: _addressController.text,
        location: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        notes: _notesController.text,
        emergencyType: _emergencyType,
        injuredPersons: _injuredController.text.isNotEmpty ? _injuredController.text : null,
      );

      bool isPoliceEmergency = _emergencyType == 'Police Emergency';

      // If police emergency, send email to police
      if (isPoliceEmergency && _selectedLocation != null) {
        String locationString = '${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}';
        String mapsLink = 'https://maps.google.com/?q=${_selectedLocation!.latitude},${_selectedLocation!.longitude}';
        String injuredText = _injuredController.text.trim().isNotEmpty
            ? '\nEstimated injured persons: ${_injuredController.text.trim()}'
            : '';
        String body =
            'This location has an emergency. Please come to this location immediately.\nLocation: $locationString\nGoogle Maps: $mapsLink$injuredText';
        await EmailService.sendEmergencyAlert(
          userName: '',
          userLocation: Position(
            latitude: _selectedLocation!.latitude,
            longitude: _selectedLocation!.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ),
          userPhone: '',
          emergencyEmail: 'quickcarepolice@gmail.com',
          additionalNotes: body,
        );
      }

      if (requestId != null && mounted) {
        setState(() {
          _currentRequestId = requestId;
          _isSubmitting = false;
          _isLoading = true;
        });
        _listenForDriverAcceptance(requestId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ambulance booking request sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to create request');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE53935);
    final Color cardColor = Colors.white;
    final Color backgroundColor = Colors.white;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: FindingDriverAnimation(
          title: 'Finding Driver',
          subtitle: 'Please wait while we connect you\nwith a nearby driver',
          icon: Icons.local_taxi,
          backgroundColor: primaryColor,
          iconColor: primaryColor,
          onCancel: _currentRequestId != null ? _cancelRequest : null,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Ambulance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background circles
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
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Center(
                child: Card(
                  color: cardColor,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Select Pickup Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LocationPicker(
                            onLocationSelected: (location) {
                              setState(() {
                                _selectedLocation = location;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Patient Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the patient name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a contact number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Pickup Address Details',
                              hintText: 'Building name, floor, landmark, etc.',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter pickup address details';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Additional Notes (Optional)',
                              hintText: 'Any special instructions or medical conditions',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _injuredController,
                            decoration: const InputDecoration(
                              labelText: 'Estimated Number of Injured Persons (Optional)',
                              hintText: 'e.g. 2, 3, 5+',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 24),
                          // Emergency type selection
                          DropdownButtonFormField<String>(
                            value: _emergencyType,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Normal Emergency',
                                child: Text('Normal Emergency'),
                              ),
                              DropdownMenuItem(
                                value: 'Police Emergency',
                                child: Text('Police Emergency'),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _emergencyType = val!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _bookAmbulance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Request Ambulance',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 