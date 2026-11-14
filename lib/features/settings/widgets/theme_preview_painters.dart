import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/painters/mochi_painter.dart';
import '../../../core/theme/putar_theme.dart';

/// Painter 100% vector untuk roda mini bertema (default: Pasar Malam sesuai Setelan1.dc.html)
class PasarMalamWheelPainter extends CustomPainter {
  final List<Color> colors;
  final Color inkColor;
  final Color hubColor;

  const PasarMalamWheelPainter({
    this.colors = sliceColors,
    this.inkColor = PutarTheme.kPasarMalamInk,
    this.hubColor = PutarTheme.kPasarMalamSurface,
  });

  /// Membangun painter pratinjau roda mini langsung dari token `PutarTheme`.
  factory PasarMalamWheelPainter.fromTheme(PutarTheme theme) {
    return PasarMalamWheelPainter(
      colors: theme.wheelPalette.isNotEmpty ? theme.wheelPalette : sliceColors,
      inkColor: theme.ink,
      hubColor: theme.surface,
    );
  }

  static const List<Color> sliceColors = [
    Color(0xFFFF6B5A), // Tomat
    Color(0xFFFF9F1C), // Jeruk
    Color(0xFFFFD23F), // Matahari
    Color(0xFF3DDBB0), // Mint
    Color(0xFF6FB1FF), // Langit
    Color(0xFFB8A4FF), // Lavender
    Color(0xFFFF8FC0), // Permen
    Color(0xFFB8E986), // Melon
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final palette = colors.isNotEmpty ? colors : sliceColors;
    final sweepAngle = (2 * math.pi) / palette.length;

    // Irisan warna-warni
    final slicePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < palette.length; i++) {
      slicePaint.color = palette[i];
      canvas.drawArc(rect, i * sweepAngle, sweepAngle, true, slicePaint);
    }

    // Garis pembagi radial
    final linePaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < palette.length; i++) {
      final angle = i * sweepAngle;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), linePaint);
    }

    // Border lingkaran luar
    final borderPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Titik pusat putih (center hub)
    final hubPaint = Paint()
      ..color = hubColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.3, hubPaint);
    canvas.drawCircle(center, radius * 0.3, borderPaint..strokeWidth = 2.0);

    // Titik pusat tinta (center dot)
    final dotPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.1, dotPaint);
  }

  @override
  bool shouldRepaint(covariant PasarMalamWheelPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.hubColor != hubColor;
}

/// Painter 100% vector untuk kucing manis (sesuai SVG Setelan1.dc.html)
class KucingManisPainter extends CustomPainter {
  const KucingManisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    canvas.save();
    canvas.scale(s, s);

    final strokePaint = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    // 1. Telinga Kiri
    final leftEar = Path()
      ..moveTo(16, 44)
      ..quadraticBezierTo(14, 16, 24, 11)
      ..quadraticBezierTo(38, 16, 44, 29)
      ..close();
    fillPaint.color = const Color(0xFFFFB066);
    canvas.drawPath(leftEar, fillPaint);
    canvas.drawPath(leftEar, strokePaint);

    // 2. Telinga Kanan
    final rightEar = Path()
      ..moveTo(84, 44)
      ..quadraticBezierTo(86, 16, 76, 11)
      ..quadraticBezierTo(62, 16, 56, 29)
      ..close();
    canvas.drawPath(rightEar, fillPaint);
    canvas.drawPath(rightEar, strokePaint);

    // 3. Daun Telinga Bagian Dalam Kiri
    final innerEarLeft = Path()
      ..moveTo(22, 36)
      ..quadraticBezierTo(22, 22, 27, 19)
      ..quadraticBezierTo(34, 22, 37, 29)
      ..close();
    fillPaint.color = const Color(0xFFFF8FB1);
    canvas.drawPath(innerEarLeft, fillPaint);

    // 4. Daun Telinga Bagian Dalam Kanan
    final innerEarRight = Path()
      ..moveTo(78, 36)
      ..quadraticBezierTo(78, 22, 73, 19)
      ..quadraticBezierTo(66, 22, 63, 29)
      ..close();
    canvas.drawPath(innerEarRight, fillPaint);

    // 5. Kepala Utama
    fillPaint.color = const Color(0xFFFFB066);
    final headRect = Rect.fromCenter(center: const Offset(50, 58), width: 80, height: 68);
    canvas.drawOval(headRect, fillPaint);
    canvas.drawOval(headRect, strokePaint);

    // 6. Garis Dahi
    final dahiPaint = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 26), const Offset(50, 33), dahiPaint);
    canvas.drawLine(const Offset(42, 27.5), const Offset(43.5, 33.5), dahiPaint);
    canvas.drawLine(const Offset(58, 27.5), const Offset(56.5, 33.5), dahiPaint);

    // 7. Area Mulut & Hidung
    fillPaint.color = const Color(0xFFFFF3E0);
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 69), width: 24, height: 17), fillPaint);

    // 8. Pipi Merona Kiri & Kanan
    fillPaint.color = const Color(0xFFFF9FB8).withValues(alpha: 0.75);
    canvas.drawOval(Rect.fromCenter(center: const Offset(23, 69), width: 14, height: 9), fillPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(77, 69), width: 14, height: 9), fillPaint);

    // 9. Mata Kiri & Kanan
    fillPaint.color = const Color(0xFF3A2E4F);
    canvas.drawOval(Rect.fromCenter(center: const Offset(34, 56), width: 12, height: 15), fillPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(66, 56), width: 12, height: 15), fillPaint);

    // 10. Kilau Mata Putih
    fillPaint.color = Colors.white;
    canvas.drawCircle(const Offset(36, 53), 2.6, fillPaint);
    canvas.drawCircle(const Offset(68, 53), 2.6, fillPaint);
    canvas.drawCircle(const Offset(32.5, 60), 1.3, fillPaint);
    canvas.drawCircle(const Offset(64.5, 60), 1.3, fillPaint);

    // 11. Hidung Segitiga Lucu
    final nosePath = Path()
      ..moveTo(47.5, 62.5)
      ..lineTo(52.5, 62.5)
      ..quadraticBezierTo(52.5, 65.5, 50, 66.7)
      ..quadraticBezierTo(47.5, 65.5, 47.5, 62.5)
      ..close();
    fillPaint.color = const Color(0xFFFF7A9C);
    canvas.drawPath(nosePath, fillPaint);
    final noseStroke = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(nosePath, noseStroke);

    // 12. Garis Mulut Kucing
    final mouthPaint = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 66.7), const Offset(50, 68.3), mouthPaint);
    final mouthLeft = Path()
      ..moveTo(50, 68.3)
      ..quadraticBezierTo(46.5, 72.1, 43, 68.9);
    canvas.drawPath(mouthLeft, mouthPaint);
    final mouthRight = Path()
      ..moveTo(50, 68.3)
      ..quadraticBezierTo(53.5, 72.1, 57, 68.9);
    canvas.drawPath(mouthRight, mouthPaint);

    // 13. Kumis Kucing Kiri & Kanan
    final whiskerPaint = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(15, 62), const Offset(6, 59.5), whiskerPaint);
    canvas.drawLine(const Offset(15, 68), const Offset(6, 70), whiskerPaint);
    canvas.drawLine(const Offset(85, 62), const Offset(94, 59.5), whiskerPaint);
    canvas.drawLine(const Offset(85, 68), const Offset(94, 70), whiskerPaint);

    // 14. Kalung Pita
    final collarPath = Path()
      ..moveTo(29, 85)
      ..quadraticBezierTo(50, 97, 71, 85);
    final collarBorder = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(collarPath, collarBorder);

    final collarInner = Paint()
      ..color = const Color(0xFFFF8FB1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(collarPath, collarInner);

    // 15. Lonceng Emas
    fillPaint.color = const Color(0xFFFFD23F);
    canvas.drawCircle(const Offset(50, 95), 5.0, fillPaint);
    final bellStroke = Paint()
      ..color = const Color(0xFF3A2E4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(50, 95), 5.0, bellStroke);
    canvas.drawLine(
      const Offset(47, 95.5),
      const Offset(53, 95.5),
      whiskerPaint..strokeWidth = 1.8,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Thumbnail pratinjau bertema yang sepenuhnya data-driven terhadap `PutarTheme`.
/// Mendukung animasi naik-turun lembut untuk tema bermaskot (Tema1.dc.html)
/// dan tetap menghormati `MediaQuery.disableAnimations`.
class ThemePreviewThumbnail extends StatefulWidget {
  final PutarTheme themeOption;
  final double size;
  final bool animate;

  const ThemePreviewThumbnail({
    super.key,
    required this.themeOption,
    this.size = 54.0,
    this.animate = false,
  });

  @override
  State<ThemePreviewThumbnail> createState() => _ThemePreviewThumbnailState();
}

class _ThemePreviewThumbnailState extends State<ThemePreviewThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBobAnimation();
  }

  @override
  void didUpdateWidget(covariant ThemePreviewThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        oldWidget.themeOption.mascot != widget.themeOption.mascot) {
      _syncBobAnimation();
    }
  }

  void _syncBobAnimation() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate =
        widget.animate && widget.themeOption.mascot != null && !disableAnimations;
    if (shouldAnimate) {
      if (!_bobController.isAnimating) {
        _bobController.repeat(reverse: true);
      }
    } else {
      _bobController.stop();
      _bobController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = widget.themeOption.mascot == PutarMascotKind.mochi
        ? MochiPainter.fromTheme(widget.themeOption)
        : PasarMalamWheelPainter.fromTheme(widget.themeOption);

    final art = ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: painter),
      ),
    );

    if (!widget.animate || widget.themeOption.mascot == null) {
      return art;
    }

    return AnimatedBuilder(
      animation: _bobController,
      builder: (context, child) {
        final dy =
            -6.0 * Curves.easeInOut.transform(_bobController.value);
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: art,
    );
  }
}

