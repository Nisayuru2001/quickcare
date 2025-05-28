import 'dart:math' as math;
import 'package:flutter/material.dart';

class FindingDriverAnimation extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onCancel;

  const FindingDriverAnimation({
    super.key,
    this.title = 'Processing Your Request',
    this.subtitle = 'Please wait while we process\nyour ambulance booking',
    this.icon = Icons.local_taxi,
    this.backgroundColor = const Color(0xFFE53935),
    this.iconColor = const Color(0xFFE53935),
    this.onCancel,
  });

  @override
  State<FindingDriverAnimation> createState() => _FindingDriverAnimationState();
}

class _FindingDriverAnimationState extends State<FindingDriverAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            widget.backgroundColor.withOpacity(0.8),
            widget.backgroundColor,
            widget.backgroundColor.withOpacity(0.9),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (widget.onCancel != null)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black26,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _rotationController,
                            child: CustomPaint(
                              size: const Size(200, 200),
                              painter: _SearchingPainter(),
                            ),
                          ),
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
                                  child: Icon(
                                    widget.icon,
                                    color: widget.iconColor,
                                    size: 50,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text(
                        widget.title,
                        style: const TextStyle(
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
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
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
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    const numberOfDots = 12;
    const dotRadius = 6.0;

    for (var i = 0; i < numberOfDots; i++) {
      final angle = 2 * math.pi * i / numberOfDots;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      final scale = 1.0 - (i / numberOfDots) * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        dotRadius * scale,
        paint..color = Colors.white.withOpacity(0.5 - (i / numberOfDots) * 0.3),
      );
    }

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