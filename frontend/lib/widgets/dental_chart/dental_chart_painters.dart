import 'package:flutter/material.dart';

class ToothShapePainter extends CustomPainter {
  final Color borderColor;
  final bool isUpper;
  final double strokeWidth;
  final String toothKind;

  ToothShapePainter({
    required this.borderColor,
    required this.isUpper,
    required this.strokeWidth,
    required this.toothKind,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isUpper) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }

    final Path path = buildPath(toothKind: toothKind, size: size);

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  static Path buildPath({
    required String toothKind,
    required Size size,
  }) {
    switch (toothKind) {
      case 'incisor':
        return _incisorPath(size);
      case 'canine':
        return _caninePath(size);
      case 'premolar':
        return _premolarPath(size);
      default:
        return _molarPath(size);
    }
  }

  @override
  bool shouldRepaint(covariant ToothShapePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.isUpper != isUpper ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.toothKind != toothKind;
  }

  static Path _incisorPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.30, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.02,
        size.width * 0.70,
        size.height * 0.15,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.32,
        size.width * 0.77,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.84,
        size.width * 0.57,
        size.height * 0.97,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 1.02,
        size.width * 0.50,
        size.height * 0.92,
      )
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 1.02,
        size.width * 0.43,
        size.height * 0.97,
      )
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.84,
        size.width * 0.23,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.32,
        size.width * 0.30,
        size.height * 0.15,
      )
      ..close();
  }

  static Path _caninePath(Size size) {
    return Path()
      ..moveTo(size.width * 0.26, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.02,
        size.width * 0.50,
        size.height * 0.04,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.02,
        size.width * 0.74,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.35,
        size.width * 0.81,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.84,
        size.width * 0.60,
        size.height * 0.97,
      )
      ..quadraticBezierTo(
        size.width * 0.54,
        size.height * 1.00,
        size.width * 0.50,
        size.height * 0.89,
      )
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height * 1.00,
        size.width * 0.40,
        size.height * 0.97,
      )
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.84,
        size.width * 0.19,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.14,
        size.height * 0.35,
        size.width * 0.26,
        size.height * 0.18,
      )
      ..close();
  }

  static Path _premolarPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.22, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.04,
        size.width * 0.50,
        size.height * 0.07,
      )
      ..quadraticBezierTo(
        size.width * 0.64,
        size.height * 0.04,
        size.width * 0.78,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.90,
        size.height * 0.35,
        size.width * 0.84,
        size.height * 0.57,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.82,
        size.width * 0.62,
        size.height * 0.96,
      )
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 1.00,
        size.width * 0.50,
        size.height * 0.89,
      )
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 1.00,
        size.width * 0.38,
        size.height * 0.96,
      )
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.82,
        size.width * 0.16,
        size.height * 0.57,
      )
      ..quadraticBezierTo(
        size.width * 0.10,
        size.height * 0.35,
        size.width * 0.22,
        size.height * 0.18,
      )
      ..close();
  }

  static Path _molarPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.18, size.height * 0.20)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.05,
        size.width * 0.42,
        size.height * 0.08,
      )
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.02,
        size.width * 0.58,
        size.height * 0.08,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.05,
        size.width * 0.82,
        size.height * 0.20,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.36,
        size.width * 0.88,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.82,
        size.width * 0.66,
        size.height * 0.96,
      )
      ..quadraticBezierTo(
        size.width * 0.57,
        size.height * 1.01,
        size.width * 0.50,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.43,
        size.height * 1.01,
        size.width * 0.34,
        size.height * 0.96,
      )
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.82,
        size.width * 0.12,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.08,
        size.height * 0.36,
        size.width * 0.18,
        size.height * 0.20,
      )
      ..close();
  }
}

/// طبقة تغليف ابتسامة تتبع شكل السن — ألوان مينا/عاج طبيعية.
class ToothSmileCoatingPainter extends CustomPainter {
  final bool isUpper;
  final String toothKind;

  ToothSmileCoatingPainter({
    required this.isUpper,
    required this.toothKind,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isUpper) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }

    final path = ToothShapePainter.buildPath(
      toothKind: toothKind,
      size: size,
    );
    final bounds = path.getBounds();

    final coatingPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFF8),
          Color(0xFFF8F4EC),
          Color(0xFFEDE4D4),
          Color(0xFFD9CCB8),
        ],
        stops: [0.0, 0.28, 0.62, 1.0],
      ).createShader(bounds.inflate(4));
    canvas.drawPath(path, coatingPaint);

    canvas.save();
    canvas.clipPath(path);

    final shineRect = Rect.fromLTWH(
      bounds.left + bounds.width * 0.14,
      bounds.top + bounds.height * 0.06,
      bounds.width * 0.72,
      bounds.height * 0.34,
    );
    final shinePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.55),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: 0.82),
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(shineRect);
    canvas.drawOval(shineRect, shinePaint);

    final sideGloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, sideGloss);

    final depthPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFA89578).withValues(alpha: 0.2),
        ],
        stops: const [0.55, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, depthPaint);

    canvas.restore();

    final outerEdge = Paint()
      ..color = const Color(0xFFC4B5A0).withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawPath(path, outerEdge);

    final innerEdge = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawPath(path, innerEdge);
  }

  @override
  bool shouldRepaint(covariant ToothSmileCoatingPainter oldDelegate) {
    return oldDelegate.isUpper != isUpper || oldDelegate.toothKind != toothKind;
  }
}
