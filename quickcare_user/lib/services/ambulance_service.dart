import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickcare_user/models/ambulance_request.dart';

class AmbulanceService {
  static final AmbulanceService _instance = AmbulanceService._internal();
  factory AmbulanceService() => _instance;
  AmbulanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache the current active request ID
  String? _activeRequestId;

  // Get the current active request ID
  String? get activeRequestId => _activeRequestId;

  // Set the current active request ID
  set activeRequestId(String? requestId) {
    _activeRequestId = requestId;
  }

  // Check if there's an active request for the current user
  Future<String?> checkActiveRequest() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection('ambulance_bookings')
          .where('requesterId', isEqualTo: user.uid)
          .where('status', whereIn: [
            'pending',
            'accepted',
            'enRoute',
            'arrived'
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _activeRequestId = null;
        return null;
      }

      _activeRequestId = snapshot.docs.first.id;
      return _activeRequestId;
    } catch (e) {
      print('Error checking active request: $e');
      return null;
    }
  }

  // Stream the current request
  Stream<AmbulanceRequest?> streamRequest(String requestId) {
    return _firestore
        .collection('ambulance_bookings')
        .doc(requestId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return AmbulanceRequest.fromFirestore(snapshot);
    });
  }

  // Create a new request
  Future<String?> createRequest({
    required String patientName,
    required String patientPhone,
    required String address,
    required GeoPoint location,
    String? notes,
    String emergencyType = 'Normal Emergency',
    String? injuredPersons,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final docRef = await _firestore.collection('ambulance_bookings').add({
        'requesterId': user.uid,
        'patientName': patientName,
        'patientPhone': patientPhone,
        'address': address,
        'notes': notes,
        'location': location,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'emergencyType': emergencyType,
        'injuredPersons': injuredPersons,
        'lastUpdated': FieldValue.serverTimestamp(),
        'paymentStatus': 'pending',
        'bookingSource': 'mobile_app',
        'deviceInfo': {
          'platform': 'mobile',
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      _activeRequestId = docRef.id;
      return docRef.id;
    } catch (e) {
      print('Error creating request: $e');
      return null;
    }
  }

  // Cancel a request
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _firestore.collection('ambulance_bookings').doc(requestId).update({
        'status': 'cancelled',
      });
      
      if (_activeRequestId == requestId) {
        _activeRequestId = null;
      }
      
      return true;
    } catch (e) {
      print('Error cancelling request: $e');
      return false;
    }
  }
} 