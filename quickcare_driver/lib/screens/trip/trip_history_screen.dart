import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _tripHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripHistory();
  }

  Future<void> _loadTripHistory() async {
    setState(() => _isLoading = true);

    try {
      String driverId = _auth.currentUser!.uid;

      // Simplified query - remove the orderBy to avoid index requirement
      QuerySnapshot snapshot = await _firestore
          .collection('emergency_requests')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['completed', 'cancelled'])
          .get();

      setState(() {
        _tripHistory = snapshot.docs
            .map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        })
            .toList();

        // Sort the results in memory instead of in the query
        _tripHistory.sort((a, b) {
          if (a['acceptedAt'] == null) return 1;
          if (b['acceptedAt'] == null) return -1;
          return (b['acceptedAt'] as Timestamp)
              .compareTo(a['acceptedAt'] as Timestamp);
        });

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trip history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF212121);
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Trip History',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Trip History List
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE53935),
                ),
              )
                  : _tripHistory.isEmpty
                  ? _buildEmptyState(textColor)
                  : RefreshIndicator(
                onRefresh: _loadTripHistory,
                color: primaryColor,
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _tripHistory.length,
                  itemBuilder: (context, index) {
                    return _buildTripHistoryItem(
                      _tripHistory[index],
                      cardColor,
                      textColor,
                      primaryColor,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Trip History',
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed trips will appear here',
            style: TextStyle(
              color: textColor.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryItem(
      Map<String, dynamic> trip,
      Color cardColor,
      Color textColor,
      Color primaryColor,
      ) {
    // Format timestamp
    String formattedDate = 'Unknown date';
    if (trip['acceptedAt'] != null) {
      DateTime tripDate = (trip['acceptedAt'] as Timestamp).toDate();
      formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(tripDate);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with date and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(trip['status']).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(trip['status']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _capitalizeStatus(trip['status'] ?? 'Unknown'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Trip details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  Icons.person_outline,
                  'Patient',
                  trip['userName'] ?? 'Unknown',
                  textColor,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.bloodtype_outlined,
                  'Blood Type',
                  trip['medicalInfo']?['bloodType'] ?? 'Unknown',
                  textColor,
                ),
                const SizedBox(height: 8),
                if (trip['completedAt'] != null) ...[
                  _buildDetailRow(
                    Icons.access_time,
                    'Duration',
                    _calculateDuration(trip['acceptedAt'], trip['completedAt']),
                    textColor,
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const SizedBox(height: 8),
                // View Details button (for future implementation)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to trip details screen
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: textColor.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
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
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }

  String _calculateDuration(Timestamp? start, Timestamp? end) {
    if (start == null || end == null) return 'Unknown';

    Duration duration = end.toDate().difference(start.toDate());
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}