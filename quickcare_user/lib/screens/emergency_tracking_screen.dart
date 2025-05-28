import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class EmergencyTrackingScreen extends StatefulWidget {
  final String requestId;
  final String driverId;

  const EmergencyTrackingScreen({
    required this.requestId,
    required this.driverId,
    super.key,
  });

  @override
  State<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

class _EmergencyTrackingScreenState extends State<EmergencyTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  LatLng? _driverLocation;
  LatLng? _emergencyLocation;
  String _driverName = '';
  String _driverPhone = '';
  String _driverLicenseNumber = '';
  String _estimatedTime = '';
  String _status = '';
  Map<String, dynamic> _medicalInfo = {};
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  bool _isCardExpanded = true;

  // Custom map style
  static const String _mapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      }
    ]
  ''';

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    // Listen to emergency request updates
    _requestSubscription = FirebaseFirestore.instance
        .collection('emergency_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final locationGeoPoint = data['location'] as GeoPoint;
      final status = data['status'] as String;
      final medicalInfo = data['medicalInfo'] as Map<String, dynamic>;
      final eta = data['estimatedArrival'] as Timestamp?;

      setState(() {
        _emergencyLocation = LatLng(
          locationGeoPoint.latitude,
          locationGeoPoint.longitude,
        );
        _status = status;
        _medicalInfo = medicalInfo;
        if (eta != null) {
          final arrival = eta.toDate();
          final now = DateTime.now();
          final minutes = arrival.difference(now).inMinutes;
          _estimatedTime = '$minutes mins';
        }
      });

      // Add emergency location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('emergency'),
          position: _emergencyLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Emergency Location',
          ),
        ),
      );

      // Get driver details
      if (widget.driverId.isNotEmpty) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('driver_profiles')
            .doc(widget.driverId)
            .get();
        if (driverDoc.exists) {
          setState(() {
            _driverName = driverDoc.get('fullName') as String;
            _driverPhone = driverDoc.get('phoneNumber') as String;
            _driverLicenseNumber = driverDoc.get('licenseNumber') as String;
          });
        }

        // Listen to driver location updates
        _locationSubscription = FirebaseFirestore.instance
            .collection('driver_locations')
            .doc(widget.driverId)
            .snapshots()
            .listen((snapshot) async {
          if (!snapshot.exists) return;

          final data = snapshot.data() as Map<String, dynamic>;
          final location = data['location'] as GeoPoint;
          final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

          final newDriverLocation = LatLng(location.latitude, location.longitude);

          setState(() {
            _driverLocation = newDriverLocation;
            _markers.removeWhere(
              (marker) => marker.markerId == const MarkerId('driver'),
            );
            _markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: newDriverLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                infoWindow: InfoWindow(
                  title: 'Ambulance Driver',
                  snippet: _driverName,
                ),
                flat: true,
                anchor: const Offset(0.5, 0.5),
                rotation: heading,
              ),
            );
          });

          // Update camera and route
          if (_emergencyLocation != null) {
            await _updateCameraPosition();
            await _updateRoute();
          }
        });
      }

      // Initialize map camera position
      final controller = await _controller.future;
      if (_driverLocation != null && _emergencyLocation != null) {
        await _updateCameraPosition();
      } else if (_emergencyLocation != null) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _emergencyLocation!,
              zoom: 15,
            ),
          ),
        );
      }
    });
  }

  Future<void> _updateCameraPosition() async {
    if (_driverLocation == null || _emergencyLocation == null) return;

    final controller = await _controller.future;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_driverLocation!.latitude, _emergencyLocation!.latitude),
        math.min(_driverLocation!.longitude, _emergencyLocation!.longitude),
      ),
      northeast: LatLng(
        math.max(_driverLocation!.latitude, _emergencyLocation!.latitude),
        math.max(_driverLocation!.longitude, _emergencyLocation!.longitude),
      ),
    );

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _updateRoute() async {
    if (_driverLocation == null || _emergencyLocation == null) return;

    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: 'AIzaSyA5rVo3_43wGSO-gas7PT9LWm5irS_ZOjY',
      request: PolylineRequest(
        origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
        destination: PointLatLng(_emergencyLocation!.latitude, _emergencyLocation!.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: const Color(0xFFE53935),
            points: result.points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
            width: 5,
            patterns: [
              PatternItem.dash(20),
              PatternItem.gap(10),
            ],
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _emergencyLocation ?? const LatLng(0, 0),
              zoom: 15,
              tilt: 45.0,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) async {
              _controller.complete(controller);
              await controller.setMapStyle(_mapStyle);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            trafficEnabled: true,
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.black,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Status panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status bar (always visible)
                GestureDetector(
                  onTap: () => setState(() => _isCardExpanded = !_isCardExpanded),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(_isCardExpanded ? 0 : 24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emergency,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _status,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _isCardExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                // Expandable details
                if (_isCardExpanded)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_estimatedTime.isNotEmpty) ...[
                          Text(
                            'Estimated arrival in $_estimatedTime',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Medical Info
                        if (_medicalInfo.isNotEmpty) ...[
                          const Text(
                            'Medical Information',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMedicalInfoRow('Blood Type', _medicalInfo['bloodType'] ?? 'Unknown'),
                                _buildMedicalInfoRow('Allergies', _medicalInfo['allergies'] ?? 'None'),
                                _buildMedicalInfoRow('Medical Conditions', _medicalInfo['medicalConditions'] ?? 'None'),
                                _buildMedicalInfoRow('Medications', _medicalInfo['medications'] ?? 'None'),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_driverName.isNotEmpty) ...[
                          const Text(
                            'Emergency Responder',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFFE53935),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _driverName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'License: $_driverLicenseNumber',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final Uri phoneUri = Uri(
                                    scheme: 'tel',
                                    path: _driverPhone,
                                  );
                                  if (await url_launcher.canLaunchUrl(phoneUri)) {
                                    await url_launcher.launchUrl(phoneUri);
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not launch phone dialer'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.phone,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
} 