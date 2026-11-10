import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ikon Custom: Panah Kembali (Back)
class CustomBackIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomBackIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(15, 6);
    path.lineTo(9, 12);
    path.lineTo(15, 18);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomBackIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Panah Maju (Forward / Chevron Right)
class CustomForwardIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomForwardIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(9, 6);
    path.lineTo(15, 12);
    path.lineTo(9, 18);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomForwardIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Centang (Checkmark)
class CustomCheckIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCheckIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(5, 13);
    path.lineTo(10, 18);
    path.lineTo(19, 7);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomCheckIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Peringatan (Warning Triangle + Exclamation Mark)
class CustomWarningIconPainter extends CustomPainter {
  final Color color;
  final Color markColor;
  final double strokeWidth;

  const CustomWarningIconPainter({
    this.color = AppColors.ink,
    this.markColor = AppColors.ink,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Segitiga membulat
    final triangle = Path();
    triangle.moveTo(12, 4);
    triangle.lineTo(21, 19);
    triangle.quadraticBezierTo(21.5, 20, 20.5, 20);
    triangle.lineTo(3.5, 20);
    triangle.quadraticBezierTo(2.5, 20, 3, 19);
    triangle.close();
    canvas.drawPath(triangle, strokePaint);

    // Tanda seru
    final markStroke = Paint()
      ..color = markColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(12, 9), const Offset(12, 13.5), markStroke);

    final dotPaint = Paint()
      ..color = markColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(12, 17), strokeWidth / 2, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomWarningIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Silang (Close / Delete 'X')
class CustomCloseIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCloseIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), paint);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomCloseIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Tambah (Plus)
class CustomPlusIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomPlusIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(12, 5), const Offset(12, 19), paint);
    canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPlusIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Bagikan (Share)
class CustomShareIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomShareIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Node 1: kiri (6, 12)
    // Node 2: kanan atas (18, 6)
    // Node 3: kanan bawah (18, 18)
    canvas.drawLine(const Offset(6, 12), const Offset(18, 6), strokePaint);
    canvas.drawLine(const Offset(6, 12), const Offset(18, 18), strokePaint);

    canvas.drawCircle(const Offset(6, 12), 2.8, fillPaint);
    canvas.drawCircle(const Offset(18, 6), 2.8, fillPaint);
    canvas.drawCircle(const Offset(18, 18), 2.8, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomShareIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Speaker / Suara (Mute & Unmute)
class CustomVolumeIconPainter extends CustomPainter {
  final bool isMuted;
  final Color color;
  final double strokeWidth;

  const CustomVolumeIconPainter({
    required this.isMuted,
    this.color = AppColors.ink,
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Badan speaker / megaphone
    final speakerPath = Path();
    speakerPath.moveTo(4, 9);
    speakerPath.lineTo(7.5, 9);
    speakerPath.lineTo(12, 5.5);
    speakerPath.lineTo(12, 18.5);
    speakerPath.lineTo(7.5, 15);
    speakerPath.lineTo(4, 15);
    speakerPath.close();

    canvas.drawPath(speakerPath, fillPaint);
    canvas.drawPath(speakerPath, strokePaint);

    if (isMuted) {
      // Garis silang diagonal jika suara nonaktif
      canvas.drawLine(const Offset(15, 8.5), const Offset(20.5, 15.5), strokePaint);
      canvas.drawLine(const Offset(20.5, 8.5), const Offset(15, 15.5), strokePaint);
    } else {
      // Gelombang suara 1 (dekat)
      final wave1 = Path();
      wave1.moveTo(15, 9.5);
      wave1.quadraticBezierTo(17, 12, 15, 14.5);
      canvas.drawPath(wave1, strokePaint);

      // Gelombang suara 2 (jauh)
      final wave2 = Path();
      wave2.moveTo(18, 7.5);
      wave2.quadraticBezierTo(21.5, 12, 18, 16.5);
      canvas.drawPath(wave2, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomVolumeIconPainter oldDelegate) =>
      oldDelegate.isMuted != isMuted ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Custom: Pengaturan / Gear / Edit
class CustomSettingsIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomSettingsIconPainter({
    this.color = AppColors.ink,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = const Offset(12, 12);
    canvas.drawCircle(center, 3.5, strokePaint);

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final x1 = 12 + 6.0 * math.cos(angle);
      final y1 = 12 + 6.0 * math.sin(angle);
      final x2 = 12 + 9.0 * math.cos(angle);
      final y2 = 12 + 9.0 * math.sin(angle);
      path.moveTo(x1, y1);
      path.lineTo(x2, y2);
    }
    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomSettingsIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
