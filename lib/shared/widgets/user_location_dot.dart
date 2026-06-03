import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Google Maps-style user location indicator:
/// pulsing accuracy ring + heading cone + glowing dot.
class UserLocationDot extends StatefulWidget {
  final double? heading; // degrees from north, -1 or null = unknown
  const UserLocationDot({super.key, this.heading});

  @override
  State<UserLocationDot> createState() => _UserLocationDotState();
}

class _UserLocationDotState extends State<UserLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _hasHeading => widget.heading != null && widget.heading! >= 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Static accuracy ring
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.yellow.withValues(alpha: 0.10),
            border: Border.all(
              color: AppColors.yellow.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
        ),
        // Animated pulse (sonar-style)
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value; // 0.0 → 1.0
            return Transform.scale(
              scale: 0.4 + t * 0.9,
              child: Opacity(
                opacity: math.max(0.0, 1.0 - t),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.yellow.withValues(alpha: 0.28),
                  ),
                ),
              ),
            );
          },
        ),
        // Heading cone (rotated to face direction of travel)
        if (_hasHeading)
          Transform.rotate(
            angle: widget.heading! * math.pi / 180,
            child: CustomPaint(
              size: const Size(38, 38),
              painter: _HeadingConePainter(),
            ),
          ),
        // Main dot
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.yellow,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withValues(alpha: 0.65),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  const _HeadingConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = const Color(0x88FFCC00) // yellow ~53% opacity
      ..style = PaintingStyle.fill;
    // Triangle pointing upward (north); rotated externally by heading angle
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 11, cy)
      ..lineTo(cx + 11, cy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
