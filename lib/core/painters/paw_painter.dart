import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter untuk telapak kaki kucing (viewBox 40x40).
/// Dipakai sebagai pointer roda tema Kucing Manis (diputar 180 derajat)
/// maupun watermark dekoratif latar.
class PawPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool pointDown;

  const PawPainter({
    this.fillColor = const Color(0xFFFF8FB1),
    this.strokeColor = const Color(0xFF3A2E4F),
    this.strokeWidth = 2.5,
    this.pointDown = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 40.0;
    canvas.save();
    canvas.translate(
      (size.width - 40.0 * scale) / 2,
      (size.height - 40.0 * scale) / 2,
    );
    canvas.scale(scale, scale);

    if (pointDown) {
      canvas.translate(20, 20);
      canvas.rotate(math.pi);
      canvas.translate(-20, -20);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bantalan utama: M20 36 C11 36 7 28 11 23 C14 19 26 19 29 23 C33 28 29 36 20 36 Z
    final padPath = Path()
      ..moveTo(20, 36)
      ..cubicTo(11, 36, 7, 28, 11, 23)
      ..cubicTo(14, 19, 26, 19, 29, 23)
      ..cubicTo(33, 28, 29, 36, 20, 36)
      ..close();

    canvas.drawPath(padPath, fillPaint);
    canvas.drawPath(padPath, strokePaint);

    // 4 jari telapak
    const toes = <(Offset, double)>[
      (Offset(7, 17), 4.3),
      (Offset(15, 9), 4.5),
      (Offset(25, 9), 4.5),
      (Offset(33, 17), 4.3),
    ];

    for (final (center, radius) in toes) {
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PawPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.pointDown != pointDown;
}

/// CustomPainter untuk satu kuping kucing di belakang tepi atas Roda Putar (viewBox 64x64).
class WheelEarPainter extends CustomPainter {
  final Color furColor;
  final Color innerEarColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool mirrorHorizontal;

  const WheelEarPainter({
    this.furColor = const Color(0xFFFFB066),
    this.innerEarColor = const Color(0xFFFF8FB1),
    this.strokeColor = const Color(0xFF3A2E4F),
    this.strokeWidth = 4.0,
    this.mirrorHorizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 64.0;
    canvas.save();
    canvas.translate(
      (size.width - 64.0 * scale) / 2,
      (size.height - 64.0 * scale) / 2,
    );
    canvas.scale(scale, scale);

    if (mirrorHorizontal) {
      canvas.translate(64, 0);
      canvas.scale(-1, 1);
    }

    final outerFill = Paint()
      ..color = furColor
      ..style = PaintingStyle.fill;

    final outerStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final outerPath = Path()
      ..moveTo(6, 58)
      ..lineTo(10, 6)
      ..lineTo(58, 32)
      ..close();

    canvas.drawPath(outerPath, outerFill);
    canvas.drawPath(outerPath, outerStroke);

    final innerFill = Paint()
      ..color = innerEarColor
      ..style = PaintingStyle.fill;

    final innerPath = Path()
      ..moveTo(16, 46)
      ..lineTo(18, 20)
      ..lineTo(38, 32)
      ..close();

    canvas.drawPath(innerPath, innerFill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WheelEarPainter oldDelegate) =>
      oldDelegate.furColor != furColor ||
      oldDelegate.innerEarColor != innerEarColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.mirrorHorizontal != mirrorHorizontal;
}
