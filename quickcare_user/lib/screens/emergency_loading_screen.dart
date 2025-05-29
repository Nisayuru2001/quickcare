import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickcare_user/screens/emergency_tracking_screen.dart';

class EmergencyLoadingScreen extends StatefulWidget {
  final String requestId;

  const EmergencyLoadingScreen({
    required this.requestId,
    super.key,
  });

  @override
  State<EmergencyLoadingScreen> createState() => _EmergencyLoadingScreenState();
}

class _EmergencyLoadingScreenState extends State<EmergencyLoadingScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for the center icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Setup rotation animation for the searching effect
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Start animations
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    
    // Listen for request updates
    _listenForDriverAcceptance();
  }
  
  void _listenForDriverAcceptance() {
    FirebaseFirestore.instance
        .collection('emergency_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      final driverId = data['driverId'] as String?;
      
      if (status == 'accepted' && driverId != null) {
        // Navigate to tracking screen when driver accepts
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyTrackingScreen(
              requestId: widget.requestId,
              driverId: driverId,
            ),
          ),
        );
      }
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE53935),
      body: SafeArea(
        child: Stack(
          children: [
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFFE53935).withOpacity(0.8),
                    const Color(0xFFE53935),
                    const Color(0xFFD32F2F),
                  ],
                ),
              ),
            ),

            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Searching animation
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rotating circles
                        RotationTransition(
                          turns: _rotationController,
                          child: CustomPaint(
                            size: const Size(200, 200),
                            painter: _SearchingPainter(),
                          ),
                        ),
                        // Center pulsing icon
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_hospital,
                                  color: Color(0xFFE53935),
                                  size: 50,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    // Modern typography
                    const Text(
                      'Finding Nearest Ambulance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 60,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Please wait while we connect you\nwith emergency services',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Cancel button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: TextButton(
                        onPressed: () async {
                          // Cancel the request
                          await FirebaseFirestore.instance
                              .collection('emergency_requests')
                              .doc(widget.requestId)
                              .update({'status': 'cancelled'});
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Cancel Request',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw dots in a circle
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    const numberOfDots = 12;
    const dotRadius = 6.0;

    for (var i = 0; i < numberOfDots; i++) {
      final angle = 2 * math.pi * i / numberOfDots;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      // Make dots smaller as they go around
      final scale = 1.0 - (i / numberOfDots) * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        dotRadius * scale,
        paint..color = Colors.white.withOpacity(0.5 - (i / numberOfDots) * 0.3),
      );
    }

    // Draw connecting lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < numberOfDots; i++) {
      final angle1 = 2 * math.pi * i / numberOfDots;
      final x1 = center.dx + radius * math.cos(angle1);
      final y1 = center.dy + radius * math.sin(angle1);

      final angle2 = 2 * math.pi * ((i + 1) % numberOfDots) / numberOfDots;
      final x2 = center.dx + radius * math.cos(angle2);
      final y2 = center.dy + radius * math.sin(angle2);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}