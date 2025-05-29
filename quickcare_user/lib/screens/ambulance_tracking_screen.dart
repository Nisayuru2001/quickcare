import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickcare_user/models/ambulance_request.dart';
import 'package:quickcare_user/widgets/finding_driver_animation.dart';
import 'package:quickcare_user/services/ambulance_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickcare_user/services/location_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class AmbulanceTrackingScreen extends StatefulWidget {
  final String requestId;
  final String driverId;

  const AmbulanceTrackingScreen({
    required this.requestId,
    required this.driverId,
    super.key,
  });

  @override
  State<AmbulanceTrackingScreen> createState() => _AmbulanceTrackingScreenState();
}

class _AmbulanceTrackingScreenState extends State<AmbulanceTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  String _driverName = '';
  String _driverPhone = '';
  String _driverLicenseNumber = '';
  String _estimatedTime = '';
  String _status = '';
  StreamSubscription<DocumentSnapshot>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  StreamSubscription<Position>? _positionSubscription;

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
    // Listen to request updates
    _requestSubscription = FirebaseFirestore.instance
        .collection('ambulance_bookings')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final pickupGeoPoint = data['location'] as GeoPoint;
      final status = data['status'] as String;
      final eta = data['estimatedArrival'] as Timestamp?;

      setState(() {
        _pickupLocation = LatLng(
          pickupGeoPoint.latitude,
          pickupGeoPoint.longitude,
        );
        _status = status;
        _driverName = data['driverName'] ?? '';
        _driverPhone = data['driverPhone'] ?? '';
        _driverLicenseNumber = data['driverLicenseNumber'] ?? '';
        if (eta != null) {
          final arrival = eta.toDate();
          final now = DateTime.now();
          final minutes = arrival.difference(now).inMinutes;
          _estimatedTime = '$minutes mins';
        }
      });

      // Add pickup marker
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Pickup Location',
          ),
        ),
      );

      // Get driver details
      if (widget.driverId.isNotEmpty) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .get();
        if (driverDoc.exists) {
          setState(() {
            _driverName = driverDoc.get('name') as String;
          });
        }
      }

      // Initialize map camera position
      final controller = await _controller.future;
      if (_driverLocation != null && _pickupLocation != null) {
        // If both locations are available, show both
        final bounds = LatLngBounds(
          southwest: LatLng(
            math.min(_driverLocation!.latitude, _pickupLocation!.latitude),
            math.min(_driverLocation!.longitude, _pickupLocation!.longitude),
          ),
          northeast: LatLng(
            math.max(_driverLocation!.latitude, _pickupLocation!.latitude),
            math.max(_driverLocation!.longitude, _pickupLocation!.longitude),
          ),
        );
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      } else {
        // If only pickup location is available, center on it
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _pickupLocation!,
              zoom: 15,
            ),
          ),
        );
      }
    });

    // Listen to driver location updates with distance filter
    if (widget.driverId.isNotEmpty) {
      _locationSubscription = FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(widget.driverId)
          .snapshots()
          .listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final location = data['location'] as GeoPoint;
        final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
        final isOnline = data['isOnline'] as bool? ?? false;
        final status = data['status'] as String? ?? 'unknown';

        if (!isOnline || status != 'active') {
          print('Driver is offline or inactive. Status: $status, Online: $isOnline');
          return;
        }

        final newDriverLocation = LatLng(location.latitude, location.longitude);

        // Update driver marker
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

        // Update camera position to include both markers
        if (_pickupLocation != null) {
          await _updateCameraPosition();
          await _updateRoute();
        }
      });
    }
  }

  Future<void> _updateCameraPosition() async {
    if (_driverLocation == null || _pickupLocation == null) return;

    final controller = await _controller.future;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_driverLocation!.latitude, _pickupLocation!.latitude),
        math.min(_driverLocation!.longitude, _pickupLocation!.longitude),
      ),
      northeast: LatLng(
        math.max(_driverLocation!.latitude, _pickupLocation!.latitude),
        math.max(_driverLocation!.longitude, _pickupLocation!.longitude),
      ),
    );

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _updateRoute() async {
    if (_driverLocation == null || _pickupLocation == null) return;

    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: 'AIzaSyA5rVo3_43wGSO-gas7PT9LWm5irS_ZOjY',
      request: PolylineRequest(
        origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
        destination: PointLatLng(_pickupLocation!.latitude, _pickupLocation!.longitude),
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
    } else {
      // fallback: straight line if no route found
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: const Color(0xFFE53935),
            points: [_driverLocation!, _pickupLocation!],
            width: 4,
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
          Stack(
            children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLocation ?? const LatLng(0, 0),
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
                zoomControlsEnabled: false, // We'll add custom zoom controls
            mapToolbarEnabled: false,
                compassEnabled: true,
                mapType: MapType.normal,
                trafficEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: true,
              ),
              // Custom zoom controls
              Positioned(
                right: 16,
                bottom: 200,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Zoom in button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final controller = await _controller.future;
                                final position = await controller.getZoomLevel();
                                controller.animateCamera(
                                  CameraUpdate.zoomTo(position + 1),
                                );
                              },
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.add,
                                  size: 24,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          // Zoom out button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final controller = await _controller.future;
                                final position = await controller.getZoomLevel();
                                controller.animateCamera(
                                  CameraUpdate.zoomTo(position - 1),
                                );
                              },
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              ),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.remove,
                                  size: 24,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                  Text(
                    _status,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_estimatedTime.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Estimated arrival in $_estimatedTime',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_driverName.isNotEmpty) ...[
                    const Text(
                      'Your Driver',
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
                            // Launch phone dialer with driver's number
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
          ),
        ],
      ),
    );
  }
} 