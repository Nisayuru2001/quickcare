import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AmbulanceBookingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all pending ambulance bookings
  static Stream<List<Map<String, dynamic>>> getPendingBookings() {
    return _firestore
        .collection('ambulance_bookings')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Get active booking for current driver
  static Future<Map<String, dynamic>?> getActiveBooking() async {
    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) return null;

      QuerySnapshot snapshot = await _firestore
          .collection('ambulance_bookings')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return {
        'id': snapshot.docs[0].id,
        ...snapshot.docs[0].data() as Map<String, dynamic>,
      };
    } catch (e) {
      print('Error getting active booking: $e');
      return null;
    }
  }

  // Accept an ambulance booking
  static Future<void> acceptBooking(String bookingId) async {
    try {
      String? driverId = _auth.currentUser?.uid;
      if (driverId == null) throw Exception('Driver not authenticated');

      await _firestore.collection('ambulance_bookings').doc(bookingId).update({
        'status': 'accepted',
        'driverId': driverId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error accepting booking: $e');
      rethrow;
    }
  }

  // Complete an ambulance booking
  static Future<void> completeBooking(String bookingId) async {
    try {
      await _firestore.collection('ambulance_bookings').doc(bookingId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error completing booking: $e');
      rethrow;
    }
  }

  // Cancel an ambulance booking
  static Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      await _firestore.collection('ambulance_bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
      });
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }
} 