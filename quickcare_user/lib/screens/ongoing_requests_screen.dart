import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickcare_user/models/ambulance_request.dart';
import 'package:quickcare_user/screens/ambulance_tracking_screen.dart';
import 'package:quickcare_user/screens/emergency_tracking_screen.dart';
import 'package:quickcare_user/services/ambulance_service.dart';
import 'package:quickcare_user/widgets/finding_driver_animation.dart';
import 'package:rxdart/rxdart.dart';

class OngoingRequestsScreen extends StatefulWidget {
  const OngoingRequestsScreen({super.key});

  @override
  State<OngoingRequestsScreen> createState() => _OngoingRequestsScreenState();
}

class _OngoingRequestsScreenState extends State<OngoingRequestsScreen> {
  final _ambulanceService = AmbulanceService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  final Color primaryColor = const Color(0xFFE53935); // Modern red

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _getOngoingRequests() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Get ambulance bookings stream
    final ambulanceStream = _firestore
        .collection('ambulance_bookings')
        .where('requesterId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'accepted', 'enRoute', 'arrived'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'type': 'ambulance',
              'createdAt': data['createdAt'] ?? Timestamp.now(),
            };
          }).toList();
        });

    // Get emergency requests stream
    final emergencyStream = _firestore
        .collection('emergency_requests')
        .where('requesterId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'accepted', 'enRoute', 'arrived'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'type': 'emergency',
              'createdAt': data['createdAt'] ?? Timestamp.now(),
            };
          }).toList();
        });

    // Combine and sort both streams
    return Rx.combineLatest2(
      ambulanceStream,
      emergencyStream,
      (ambulanceRequests, emergencyRequests) {
        final allRequests = [...ambulanceRequests, ...emergencyRequests];
        allRequests.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
        return allRequests;
      },
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Finding Driver';
      case 'accepted':
        return 'Driver Assigned';
      case 'enroute':
        return 'On the Way';
      case 'arrived':
        return 'Arrived';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'enroute':
        return Colors.green;
      case 'arrived':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelRequest(String requestId, String type) async {
    try {
      if (type == 'emergency') {
        await _firestore
            .collection('emergency_requests')
            .doc(requestId)
            .update({'status': 'cancelled'});
      } else {
        await _ambulanceService.cancelRequest(requestId);
      }
      
      if (mounted) {
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

  void _listenForDriverAcceptance(String requestId, String type) {
    _requestSubscription?.cancel();
    _requestSubscription = _firestore
        .collection(type == 'emergency' ? 'emergency_requests' : 'ambulance_bookings')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      final driverId = data['driverId'] as String?;

      if (status == 'accepted' && driverId != null && mounted) {
        // Navigate to appropriate tracking screen when driver accepts
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => type == 'emergency'
                ? EmergencyTrackingScreen(
                    requestId: requestId,
                    driverId: driverId,
                  )
                : AmbulanceTrackingScreen(
                    requestId: requestId,
                    driverId: driverId,
                  ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongoing Requests'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Stack(
        children: [
          // Background decorative elements
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
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getOngoingRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ongoing requests',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your active requests will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Check if there's a pending request
              final pendingRequest = requests.firstWhere(
                (request) => request['status'] == 'pending',
                orElse: () => requests.first,
              );

              if (pendingRequest['status'] == 'pending') {
                // Start listening for driver acceptance
                _listenForDriverAcceptance(
                  pendingRequest['id'],
                  pendingRequest['type'],
                );
                
                // Show loading screen for pending request
                return FindingDriverAnimation(
                  title: 'Finding Driver',
                  subtitle: 'Please wait while we connect you\nwith a nearby driver',
                  icon: pendingRequest['type'] == 'emergency'
                      ? Icons.emergency
                      : Icons.local_taxi,
                  backgroundColor: primaryColor,
                  iconColor: primaryColor,
                  onCancel: () => _cancelRequest(
                    pendingRequest['id'],
                    pendingRequest['type'],
                  ),
                );
              }

              // Show list of other ongoing requests
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final status = _getStatusText(request['status']);
                  final statusColor = _getStatusColor(request['status']);
                  final isEmergency = request['type'] == 'emergency';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => isEmergency
                                ? EmergencyTrackingScreen(
                                    requestId: request['id'],
                                    driverId: request['driverId'] ?? '',
                                  )
                                : AmbulanceTrackingScreen(
                                    requestId: request['id'],
                                    driverId: request['driverId'] ?? '',
                                  ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isEmergency)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.emergency,
                                            color: primaryColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'EMERGENCY',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const Spacer(),
                                  if (request['estimatedArrival'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        'ETA: ${request['estimatedArrival'].toDate().difference(DateTime.now()).inMinutes} mins',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                request['patientName'] ?? 'Emergency Request',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      request['address'] ?? 'Location',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
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
            },
          ),
        ],
      ),
    );
  }
} 