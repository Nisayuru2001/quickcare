import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum AmbulanceRequestStatus {
  pending,
  accepted,
  enRoute,
  arrived,
  completed,
  cancelled
}

class AmbulanceRequest {
  final String id;
  final String requesterId;
  final String patientName;
  final String patientPhone;
  final String address;
  final String? notes;
  final GeoPoint pickupLocation;
  final AmbulanceRequestStatus status;
  final DateTime createdAt;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final GeoPoint? driverLocation;
  final DateTime? estimatedArrival;

  AmbulanceRequest({
    required this.id,
    required this.requesterId,
    required this.patientName,
    required this.patientPhone,
    required this.address,
    this.notes,
    required this.pickupLocation,
    required this.status,
    required this.createdAt,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverLocation,
    this.estimatedArrival,
  });

  factory AmbulanceRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AmbulanceRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientPhone: data['patientPhone'] ?? '',
      address: data['address'] ?? '',
      notes: data['notes'],
      pickupLocation: data['location'] as GeoPoint,
      status: AmbulanceRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => AmbulanceRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      driverLocation: data['driverLocation'] as GeoPoint?,
      estimatedArrival: data['estimatedArrival'] != null
          ? (data['estimatedArrival'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'address': address,
      'notes': notes,
      'location': pickupLocation,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverLocation': driverLocation,
      'estimatedArrival':
          estimatedArrival != null ? Timestamp.fromDate(estimatedArrival!) : null,
    };
  }
} 