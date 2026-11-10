import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ikon Permainan: Dadu Miring -12° (viewBox 64x64)
/// Sesuai design/source/Games.dc.html
class DiceIconPainter extends CustomPainter {
  final Color diceColor;
  final Color dotColor;
  final Color strokeColor;
  final double strokeWidth;

  const DiceIconPainter({
    this.diceColor = AppColors.surface,
    this.dotColor = AppColors.ink,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Rotasi -12 derajat di sekitar pusat (32, 32)
    canvas.translate(32, 32);
    canvas.rotate(-12 * math.pi / 180);
    canvas.translate(-32, -32);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = diceColor
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    // Kotak dadu rect x=9, y=9, width=46, height=46, rx=11
    final diceRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9, 9, 46, 46),
      const Radius.circular(11),
    );

    canvas.drawRRect(diceRRect, fillPaint);
    canvas.drawRRect(diceRRect, strokePaint);

    // Tiga titik diagonal (22, 22), (32, 32), (42, 42) r = 3.5
    canvas.drawCircle(const Offset(22, 22), 3.5, dotPaint);
    canvas.drawCircle(const Offset(32, 32), 3.5, dotPaint);
    canvas.drawCircle(const Offset(42, 42), 3.5, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DiceIconPainter oldDelegate) =>
      oldDelegate.diceColor != diceColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Permainan: Kapsul Miring 35° Dua Warna (viewBox 64x64)
/// Sesuai design/source/Games.dc.html
class CapsuleIconPainter extends CustomPainter {
  final Color topColor;
  final Color bottomColor;
  final Color strokeColor;
  final double strokeWidth;

  const CapsuleIconPainter({
    this.topColor = AppColors.tomat,
    this.bottomColor = AppColors.surface,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Rotasi 35 derajat di sekitar pusat (32, 32)
    canvas.translate(32, 32);
    canvas.rotate(35 * math.pi / 180);
    canvas.translate(-32, -32);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final bottomFill = Paint()
      ..color = bottomColor
      ..style = PaintingStyle.fill;

    final topFill = Paint()
      ..color = topColor
      ..style = PaintingStyle.fill;

    // Body kapsul utuh rect x=19, y=6, w=26, h=52, rx=13
    final capsuleRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(19, 6, 26, 52),
      const Radius.circular(13),
    );

    // Gambar background/bottom half (putih)
    canvas.drawRRect(capsuleRRect, bottomFill);

    // Bagian atas kapsul (Tomat): M19 32V19a13 13 0 0 1 26 0V32Z
    final topHalfPath = Path();
    topHalfPath.moveTo(19, 32);
    topHalfPath.lineTo(19, 19);
    topHalfPath.arcTo(
      const Rect.fromLTWH(19, 6, 26, 26),
      math.pi,
      math.pi,
      false,
    );
    topHalfPath.lineTo(45, 32);
    topHalfPath.close();

    canvas.drawPath(topHalfPath, topFill);
    canvas.drawPath(topHalfPath, strokePaint);

    // Gambar outline kapsul secara utuh
    canvas.drawRRect(capsuleRRect, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CapsuleIconPainter oldDelegate) =>
      oldDelegate.topColor != topColor ||
      oldDelegate.bottomColor != bottomColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Permainan: Amplop dengan Koin Menyembul (viewBox 64x64)
/// Sesuai design/source/Games.dc.html
class EnvelopeIconPainter extends CustomPainter {
  final Color envelopeColor;
  final Color coinColor;
  final Color strokeColor;
  final double strokeWidth;

  const EnvelopeIconPainter({
    this.envelopeColor = AppColors.surface,
    this.coinColor = AppColors.matahari,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final coinFill = Paint()
      ..color = coinColor
      ..style = PaintingStyle.fill;

    final envelopeFill = Paint()
      ..color = envelopeColor
      ..style = PaintingStyle.fill;

    // 1. Koin menyembul di atas: cx=32, cy=18, r=10
    canvas.drawCircle(const Offset(32, 18), 10, coinFill);
    canvas.drawCircle(const Offset(32, 18), 10, strokePaint);

    // 2. Kotak amplop: rect x=7, y=22, w=50, h=34, rx=7
    final envRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(7, 22, 50, 34),
      const Radius.circular(7),
    );
    canvas.drawRRect(envRRect, envelopeFill);
    canvas.drawRRect(envRRect, strokePaint);

    // 3. Garis lipatan V: M8 26 L32 44 L56 26
    final flapPath = Path();
    flapPath.moveTo(8, 26);
    flapPath.lineTo(32, 44);
    flapPath.lineTo(56, 26);
    canvas.drawPath(flapPath, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EnvelopeIconPainter oldDelegate) =>
      oldDelegate.envelopeColor != envelopeColor ||
      oldDelegate.coinColor != coinColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Permainan: Koin Kuning Bercincin (viewBox 64x64)
/// Sesuai design/source/Games.dc.html
class CoinIconPainter extends CustomPainter {
  final Color coinColor;
  final Color strokeColor;
  final double strokeWidth;

  const CoinIconPainter({
    this.coinColor = AppColors.matahari,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final coinFill = Paint()
      ..color = coinColor
      ..style = PaintingStyle.fill;

    // 1. Lingkaran luar: cx=32, cy=32, r=23
    canvas.drawCircle(const Offset(32, 32), 23, coinFill);
    canvas.drawCircle(const Offset(32, 32), 23, strokePaint);

    // 2. Cincin dalam: cx=32, cy=32, r=15
    canvas.drawCircle(const Offset(32, 32), 15, strokePaint);

    // 3. Lengkungan kilau: M24 22 Q28 18 34 18
    final highlightPath = Path();
    highlightPath.moveTo(24, 22);
    highlightPath.quadraticBezierTo(28, 18, 34, 18);
    canvas.drawPath(highlightPath, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CoinIconPainter oldDelegate) =>
      oldDelegate.coinColor != coinColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Ikon Acak / Shuffle: Crossed arrows (viewBox 24x24)
/// Sesuai design/source/Games.dc.html
class ShuffleIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const ShuffleIconPainter({
    this.color = AppColors.matahari,
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

    // Path 1: M3 7h4l9 10h5
    final path1 = Path();
    path1.moveTo(3, 7);
    path1.lineTo(7, 7);
    path1.lineTo(16, 17);
    path1.lineTo(21, 17);
    canvas.drawPath(path1, strokePaint);

    // Path 2: M3 17h4l2.5-2.8
    final path2 = Path();
    path2.moveTo(3, 17);
    path2.lineTo(7, 17);
    path2.lineTo(9.5, 14.2);
    canvas.drawPath(path2, strokePaint);

    // Path 3: M14 9l2-2h5
    final path3 = Path();
    path3.moveTo(14, 9);
    path3.lineTo(16, 7);
    path3.lineTo(21, 7);
    canvas.drawPath(path3, strokePaint);

    // Arrowhead atas: M18 4l3 3-3 3
    final arrow1 = Path();
    arrow1.moveTo(18, 4);
    arrow1.lineTo(21, 7);
    arrow1.lineTo(18, 10);
    canvas.drawPath(arrow1, strokePaint);

    // Arrowhead bawah: M18 14l3 3-3 3
    final arrow2 = Path();
    arrow2.moveTo(18, 14);
    arrow2.lineTo(21, 17);
    arrow2.lineTo(18, 20);
    canvas.drawPath(arrow2, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShuffleIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Widget siap pakai untuk masing-masing ikon permainan
class GameIconWidget extends StatelessWidget {
  final String gameType; // 'dice', 'capsule', 'envelope', 'coin', 'shuffle'
  final double size;
  final Color? color;

  const GameIconWidget({
    super.key,
    required this.gameType,
    this.size = 64.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    CustomPainter painter;
    switch (gameType.toLowerCase()) {
      case 'dice':
      case 'dadu':
        painter = const DiceIconPainter();
        break;
      case 'capsule':
      case 'kapsul':
        painter = const CapsuleIconPainter();
        break;
      case 'envelope':
      case 'amplop':
        painter = const EnvelopeIconPainter();
        break;
      case 'coin':
      case 'koin':
        painter = const CoinIconPainter();
        break;
      case 'shuffle':
      case 'acak':
        painter = ShuffleIconPainter(
          color: color ?? AppColors.matahari,
        );
        break;
      default:
        painter = const DiceIconPainter();
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: painter,
      ),
    );
  }
}

