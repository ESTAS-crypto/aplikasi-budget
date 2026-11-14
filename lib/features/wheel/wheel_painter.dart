import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/putar_theme.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/painters/mochi_painter.dart';
import '../../core/painters/paw_painter.dart';
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
  final PutarTheme theme;
  final bool paintHubMascot;
  final MochiExpression mochiExpression;

  WheelPainter({
    required this.slots,
    required this.rotationAngleDegrees,
    required this.cachedTextPainters,
    this.isMiniPreview = false,
    this.pointerFlickAngleDegrees = 0.0,
    this.theme = PutarTheme.pasarMalam,
    this.paintHubMascot = true,
    this.mochiExpression = MochiExpression.normal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final s = size.width / 300.0;
    final totalSlots = slots.length;
    if (totalSlots == 0) return;

    // 0. Kuping kucing di belakang tepi atas roda (khusus tema Kucing)
    if (!isMiniPreview && theme.wheelDecor == PutarWheelDecor.ears) {
      _drawWheelEars(canvas, center, radius, s);
    }

    // Bayangan keras bawah roda bila tema menggunakannya (Kucing: 0, 7)
    if (theme.wheelShadowOffset != Offset.zero) {
      final shadowPaint = Paint()
        ..color = theme.shadowColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        center + theme.wheelShadowOffset * s,
        radius,
        shadowPaint,
      );
    }

    final segAngleRad = (2 * math.pi) / totalSlots;
    final segAngleDeg = 360.0 / totalSlots;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final dividerPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMiniPreview ? 2.5 : 3.0;

    final outerBorderPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMiniPreview ? 3.5 : 5.0;

    // Simpan rotasi roda
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Offset -90 derajat agar irisan ke-0 dimulai dari puncak (12 o'clock)
    canvas.rotate((rotationAngleDegrees - 90) * math.pi / 180);

    // 1. Gambar irisan roda
    for (int i = 0; i < totalSlots; i++) {
      fillPaint.color = theme.getWheelColor(i);
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
          canvas.rotate(midAngle * math.pi / 180);

          final textDist = radius * 0.68;
          canvas.translate(textDist, 0);
          canvas.rotate(math.pi / 2);

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
      // 4. Center Hub putih (34dp di Pasar Malam, 38*s di Kucing) + logo/Mochi di tengah
      final hubRadius =
          theme.mascot == PutarMascotKind.mochi ? 38.0 * s : 34.0;
      final hubFillPaint = Paint()
        ..color = theme.surface
        ..style = PaintingStyle.fill;
      final hubBorderPaint = Paint()
        ..color = theme.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      canvas.drawCircle(center, hubRadius, hubFillPaint);
      canvas.drawCircle(center, hubRadius, hubBorderPaint);

      if (theme.mascot == PutarMascotKind.mochi) {
        if (paintHubMascot) {
          canvas.save();
          final mochiSize = 52.0 * s;
          canvas.translate(
            center.dx - mochiSize / 2,
            center.dy - mochiSize / 2,
          );
          final mochiPainter = MochiPainter.fromTheme(
            theme,
            expression: mochiExpression,
          );
          mochiPainter.paint(canvas, Size(mochiSize, mochiSize));
          canvas.restore();
        }
      } else {
        // Gambar logo Pasar Malam di dalam hub
        canvas.save();
        const logoSize = 38.0;
        canvas.translate(center.dx - logoSize / 2, center.dy - logoSize / 2);
        final logoPainter = LogoPainter(
          wheelColor: theme.primary,
          sliceColor: theme.secondary,
          inkColor: theme.ink,
          hubColor: theme.surface,
          coinColor: theme.ink,
          strokeWidthRatio: 4.0,
        );
        logoPainter.paint(canvas, const Size(logoSize, logoSize));
        canvas.restore();
      }

      // 5. Pointer atas (posisi 12 jam) dengan efek pantul / flick
      canvas.save();
      final topAnchor = Offset(center.dx, center.dy - radius - 14.0 * s);
      canvas.translate(topAnchor.dx, topAnchor.dy);
      canvas.rotate(pointerFlickAngleDegrees * math.pi / 180);
      canvas.translate(-topAnchor.dx, -topAnchor.dy);
      if (theme.pointerStyle == PutarIconStyle.kucing) {
        _drawPawPointer(canvas, center, radius, s);
      } else {
        _drawPointer(canvas, center, radius);
      }
      canvas.restore();
    }
  }

  void _drawWheelEars(Canvas canvas, Offset center, double radius, double s) {
    final earSize = Size(64.0 * s, 64.0 * s);
    final topY = center.dy - radius - 26.0 * s;
    const earTilt = 14.0 * math.pi / 180;
    final earPainterLeft = WheelEarPainter(
      furColor: theme.mascotFur,
      innerEarColor: theme.mascotEarPink,
      strokeColor: theme.ink,
      strokeWidth: 4.0,
    );
    final earPainterRight = WheelEarPainter(
      furColor: theme.mascotFur,
      innerEarColor: theme.mascotEarPink,
      strokeColor: theme.ink,
      strokeWidth: 4.0,
      mirrorHorizontal: true,
    );

    // Kuping kiri
    final leftX = center.dx - radius + 14.0 * s;
    canvas.save();
    canvas.translate(leftX + earSize.width / 2, topY + earSize.height / 2);
    canvas.rotate(-earTilt);
    canvas.translate(-earSize.width / 2, -earSize.height / 2);
    earPainterLeft.paint(canvas, earSize);
    canvas.restore();

    // Kuping kanan (cermin simetris)
    final rightX = center.dx + radius - 14.0 * s - earSize.width;
    canvas.save();
    canvas.translate(rightX + earSize.width / 2, topY + earSize.height / 2);
    canvas.rotate(earTilt);
    canvas.translate(-earSize.width / 2, -earSize.height / 2);
    earPainterRight.paint(canvas, earSize);
    canvas.restore();
  }

  void _drawPawPointer(Canvas canvas, Offset center, double radius, double s) {
    final pawSize = Size(42.0 * s, 42.0 * s);
    canvas.save();
    canvas.translate(
      center.dx - pawSize.width / 2,
      center.dy - radius - 14.0 * s,
    );
    PawPainter(
      fillColor: theme.primary,
      strokeColor: theme.ink,
      strokeWidth: 2.5,
      pointDown: true,
    ).paint(canvas, pawSize);
    canvas.restore();
  }

  void _drawPointer(Canvas canvas, Offset center, double radius) {
    final pointerPaint = Paint()
      ..color = theme.primary
      ..style = PaintingStyle.fill;

    final pointerBorderPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final tipY = center.dy - radius + 22.0;
    final topY = center.dy - radius - 14.0;
    const halfWidth = 16.0;

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
        oldDelegate.slots != slots ||
        oldDelegate.theme != theme ||
        oldDelegate.paintHubMascot != paintHubMascot ||
        oldDelegate.mochiExpression != mochiExpression;
  }

  /// Helper untuk membangun cache TextPainter label nominal sesuai tema aktif
  static Map<int, TextPainter> buildTextCache(
    List<int> amounts, {
    PutarTheme theme = PutarTheme.pasarMalam,
  }) {
    final Map<int, TextPainter> cache = {};
    for (final amount in amounts) {
      if (!cache.containsKey(amount)) {
        final tp = TextPainter(
          text: TextSpan(
            text: RupiahFormatter.formatCompact(amount),
            style: theme.wheelLabel.copyWith(
              color: theme.ink,
              fontWeight: theme.weightExtraBold,
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
