import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// CustomPainter untuk Logo resmi "Putar Jajan"
/// Roda dengan satu irisan terlepas: "bagian yang boleh dijajani".
/// ViewBox standar 100x100, pusat (50,50), radius 36, stroke ink 3.5, strokeJoin round.
class LogoPainter extends CustomPainter {
  final Color wheelColor;
  final Color sliceColor;
  final Color inkColor;
  final Color hubColor;
  final Color coinColor;
  final double strokeWidthRatio;

  const LogoPainter({
    this.wheelColor = AppColors.tomat,
    this.sliceColor = AppColors.matahari,
    this.inkColor = AppColors.ink,
    this.hubColor = AppColors.surface,
    this.coinColor = AppColors.ink,
    this.strokeWidthRatio = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthRatio
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final wheelFill = Paint()
      ..color = wheelColor
      ..style = PaintingStyle.fill;

    final sliceFill = Paint()
      ..color = sliceColor
      ..style = PaintingStyle.fill;

    final hubFill = Paint()
      ..color = hubColor
      ..style = PaintingStyle.fill;

    final coinFill = Paint()
      ..color = coinColor
      ..style = PaintingStyle.fill;

    // 1. Badan Roda: M50 50 L81.2 32 A36 36 0 1 1 50 14 Z
    // Dari (50,50) ke (81.2, 32) [-30 deg], lalu busur R36 searah jarum jam ke (50, 14) [-90 deg], lalu Z ke (50,50)
    final wheelPath = Path();
    wheelPath.moveTo(50, 50);
    wheelPath.lineTo(81.177, 32.0); // 50 + 36 * cos(-30 deg), 50 + 36 * sin(-30 deg)
    wheelPath.arcTo(
      Rect.fromCircle(center: const Offset(50, 50), radius: 36),
      -30 * math.pi / 180, // dari -30 derajat
      300 * math.pi / 180, // menyapu 300 derajat searah jarum jam ke -90 derajat (270)
      false,
    );
    wheelPath.close();

    canvas.drawPath(wheelPath, wheelFill);
    canvas.drawPath(wheelPath, strokePaint);

    // 2. Irisan Terlepas: M53 44.8 L53 8.8 A36 36 0 0 1 84.2 26.8 Z
    // Digeser sejauh (+3, -5.2)
    final slicePath = Path();
    slicePath.moveTo(53, 44.8);
    slicePath.lineTo(53, 8.8); // dari atas (50+3, 14-5.2)
    slicePath.arcTo(
      Rect.fromCircle(center: const Offset(53, 44.8), radius: 36),
      -90 * math.pi / 180, // dari 12 jam (-90 deg)
      60 * math.pi / 180,  // menyapu 60 derajat searah jarum jam ke -30 deg
      false,
    );
    slicePath.close();

    canvas.drawPath(slicePath, sliceFill);
    canvas.drawPath(slicePath, strokePaint);

    // 3. Koin di irisan: lingkaran pusat (64, 26) r = 4
    canvas.drawCircle(const Offset(64, 26), 4.0, coinFill);

    // 4. Hub: lingkaran pusat (50, 50) r = 8
    canvas.drawCircle(const Offset(50, 50), 8.0, hubFill);
    canvas.drawCircle(const Offset(50, 50), 8.0, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) {
    return oldDelegate.wheelColor != wheelColor ||
        oldDelegate.sliceColor != sliceColor ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.hubColor != hubColor ||
        oldDelegate.coinColor != coinColor;
  }
}

/// Widget Logo Putar Jajan yang siap pakai dengan ukuran fleksibel
class LogoWidget extends StatelessWidget {
  final double size;
  final Color wheelColor;
  final Color sliceColor;
  final Color inkColor;
  final Color hubColor;
  final Color coinColor;
  final double strokeWidthRatio;

  const LogoWidget({
    super.key,
    this.size = 36.0,
    this.wheelColor = AppColors.tomat,
    this.sliceColor = AppColors.matahari,
    this.inkColor = AppColors.ink,
    this.hubColor = AppColors.surface,
    this.coinColor = AppColors.ink,
    this.strokeWidthRatio = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Putar Jajan',
      child: CustomPaint(
        size: Size(size, size),
        painter: LogoPainter(
          wheelColor: wheelColor,
          sliceColor: sliceColor,
          inkColor: inkColor,
          hubColor: hubColor,
          coinColor: coinColor,
          strokeWidthRatio: strokeWidthRatio,
        ),
      ),
    );
  }
}
