import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/utils/rupiah_formatter.dart';

/// CustomPainter untuk Roda Putar 300dp
/// Roda digambar dengan CustomPainter, label di-cache, dibungkus RepaintBoundary,
/// tanpa saveLayer di loop animasi.
class WheelPainter extends CustomPainter {
  final List<int> slots;
  final double rotationAngleDegrees;
  final Map<int, TextPainter> cachedTextPainters;
  final bool isMiniPreview;
  final double pointerFlickAngleDegrees;

  WheelPainter({
    required this.slots,
    required this.rotationAngleDegrees,
    required this.cachedTextPainters,
    this.isMiniPreview = false,
    this.pointerFlickAngleDegrees = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final totalSlots = slots.length;
    if (totalSlots == 0) return;

    final segAngleRad = (2 * math.pi) / totalSlots;
    final segAngleDeg = 360.0 / totalSlots;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final dividerPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMiniPreview ? 2.5 : 3.0;

    final outerBorderPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMiniPreview ? 3.5 : 5.0;

    // Simpan rotasi roda
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Konversi rotasi derajat ke radian (arah jarum jam)
    // Offset -90 derajat agar irisan ke-0 dimulai dari puncak (12 o'clock)
    canvas.rotate((rotationAngleDegrees - 90) * math.pi / 180);

    // 1. Gambar irisan roda
    for (int i = 0; i < totalSlots; i++) {
      fillPaint.color = AppColors.getWheelColor(i);
      final startAngle = i * segAngleRad;

      // Gambar potongan irisan
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        segAngleRad,
        true,
        fillPaint,
      );

      // Gambar garis pemisah irisan
      final endX = radius * math.cos(startAngle);
      final endY = radius * math.sin(startAngle);
      canvas.drawLine(Offset.zero, Offset(endX, endY), dividerPaint);
    }

    // 2. Gambar label nominal di tiap irisan (hanya pada roda utama, lewati untuk preview mini)
    if (!isMiniPreview) {
      for (int i = 0; i < totalSlots; i++) {
        final textPainter = cachedTextPainters[slots[i]];
        if (textPainter != null) {
          final midAngle = (i * segAngleDeg) + (segAngleDeg / 2);
          canvas.save();
          // Putar ke arah tengah irisan
          canvas.rotate(midAngle * math.pi / 180);

          // Geser ke posisi teks (sekitar 68% dari radius pusat)
          final textDist = radius * 0.68;
          canvas.translate(textDist, 0);

          // Putar teks agar terbaca tegak lurus radial
          canvas.rotate(math.pi / 2);

          // Pusatkan teks
          textPainter.paint(
            canvas,
            Offset(-textPainter.width / 2, -textPainter.height / 2),
          );

          canvas.restore();
        }
      }
    }

    canvas.restore(); // Kembali dari rotasi roda

    // 3. Border luar roda
    canvas.drawCircle(
      center,
      radius - (isMiniPreview ? 1.75 : 2.5),
      outerBorderPaint,
    );

    // Elemen hub tengah dan pointer hanya untuk roda interaktif utama
    if (!isMiniPreview) {
      // 4. Center Hub putih r=34 dengan border ink 3.5px & logo miniatur di tengah
      final hubRadius = 34.0;
      final hubFillPaint = Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.fill;
      final hubBorderPaint = Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      canvas.drawCircle(center, hubRadius, hubFillPaint);
      canvas.drawCircle(center, hubRadius, hubBorderPaint);

      // Gambar logo di dalam hub
      canvas.save();
      final logoSize = 38.0;
      canvas.translate(center.dx - logoSize / 2, center.dy - logoSize / 2);
      final logoPainter = const LogoPainter(strokeWidthRatio: 4.0);
      logoPainter.paint(canvas, Size(logoSize, logoSize));
      canvas.restore();

      // 5. Pointer segitiga Tomat di atas (posisi 12 jam) dengan efek pantul / flick
      canvas.save();
      final topAnchor = Offset(center.dx, center.dy - radius - 14.0);
      canvas.translate(topAnchor.dx, topAnchor.dy);
      canvas.rotate(pointerFlickAngleDegrees * math.pi / 180);
      canvas.translate(-topAnchor.dx, -topAnchor.dy);
      _drawPointer(canvas, center, radius);
      canvas.restore();
    }
  }

  void _drawPointer(Canvas canvas, Offset center, double radius) {
    final pointerPaint = Paint()
      ..color = AppColors.tomat
      ..style = PaintingStyle.fill;

    final pointerBorderPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Pointer di puncak (x = center.dx, y = center.dy - radius)
    // Menunjuk ke bawah ke dalam roda sepanjang ~22dp
    final tipY = center.dy - radius + 22.0;
    final topY = center.dy - radius - 14.0;
    final halfWidth = 16.0;

    final pointerPath = Path();
    pointerPath.moveTo(center.dx - halfWidth, topY);
    pointerPath.quadraticBezierTo(center.dx, topY - 5, center.dx + halfWidth, topY);
    pointerPath.lineTo(center.dx + 4, tipY - 5);
    pointerPath.quadraticBezierTo(center.dx, tipY, center.dx - 4, tipY - 5);
    pointerPath.close();

    canvas.drawPath(pointerPath, pointerPaint);
    canvas.drawPath(pointerPath, pointerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) {
    return oldDelegate.rotationAngleDegrees != rotationAngleDegrees ||
        oldDelegate.pointerFlickAngleDegrees != pointerFlickAngleDegrees ||
        oldDelegate.slots != slots;
  }

  /// Helper untuk membangun cache TextPainter label nominal
  static Map<int, TextPainter> buildTextCache(List<int> amounts) {
    final Map<int, TextPainter> cache = {};
    for (final amount in amounts) {
      if (!cache.containsKey(amount)) {
        final tp = TextPainter(
          text: TextSpan(
            text: RupiahFormatter.formatCompact(amount),
            style: AppTypography.wheelLabel.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        cache[amount] = tp;
      }
    }
    return cache;
  }
}
