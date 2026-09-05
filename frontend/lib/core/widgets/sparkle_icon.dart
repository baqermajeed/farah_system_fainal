import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:farah_sys_final/core/constants/app_colors.dart';

/// نجمة/بريق زخرفي مع نبض خفيف في الخلفية.
class SparkleIcon extends StatelessWidget {
  const SparkleIcon({
    super.key,
    this.size = 16,
    this.color = AppColors.primary,
    this.filled = true,
    this.animate = true,
    this.delay = Duration.zero,
  });

  final double size;
  final Color color;
  final bool filled;
  final bool animate;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(color: color, filled: filled),
    );

    if (!animate) return icon;

    return icon
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 600.ms, delay: delay)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.15, 1.15),
          duration: 1400.ms,
          curve: Curves.easeInOut,
        )
        .then(delay: delay)
        .shimmer(
          duration: 2000.ms,
          color: color.withValues(alpha: 0.35),
        );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    const points = 4;
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.35;

    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (math.pi / points) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
