import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';

/// Ikon Navigasi: Roda / Main (viewBox 24x24)
class WheelNavPainter extends CustomPainter {
  final Color color;
  final Color hubColor;
  final PutarIconStyle style;

  const WheelNavPainter({
    this.color = PutarTheme.kPasarMalamInk,
    this.hubColor = PutarTheme.kPasarMalamSurface,
    this.style = PutarIconStyle.pasarMalam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final hubPaint = Paint()
      ..color = hubColor
      ..style = PaintingStyle.fill;

    if (style == PutarIconStyle.kucing) {
      // Kuping & roda tema Kucing Manis:
      // path d="M4.5 9L5.5 2.5L10 5.5ZM19.5 9L18.5 2.5L14 5.5Z"
      final earsPath = Path()
        ..moveTo(4.5, 9)
        ..lineTo(5.5, 2.5)
        ..lineTo(10, 5.5)
        ..close()
        ..moveTo(19.5, 9)
        ..lineTo(18.5, 2.5)
        ..lineTo(14, 5.5)
        ..close();
      canvas.drawPath(earsPath, fillPaint);
      canvas.drawCircle(const Offset(12, 14), 8.5, fillPaint);
      canvas.drawCircle(const Offset(12, 14), 2.3, hubPaint);
      canvas.restore();
      return;
    }

    // 1. Badan Roda: M12 12 L19.8 7.5 A9 9 0 1 1 12 3 Z
    final wheelPath = Path();
    wheelPath.moveTo(12, 12);
    wheelPath.lineTo(19.8, 7.5);
    wheelPath.arcTo(
      Rect.fromCircle(center: const Offset(12, 12), radius: 9),
      -30 * math.pi / 180,
      300 * math.pi / 180,
      false,
    );
    wheelPath.close();
    canvas.drawPath(wheelPath, fillPaint);

    // 2. Irisan terlepas: M12.75 10.7 V1.7 A9 9 0 0 1 20.55 6.2 Z
    final slicePath = Path();
    slicePath.moveTo(12.75, 10.7);
    slicePath.lineTo(12.75, 1.7);
    slicePath.arcTo(
      Rect.fromCircle(center: const Offset(12.75, 10.7), radius: 9),
      -90 * math.pi / 180,
      60 * math.pi / 180,
      false,
    );
    slicePath.close();
    canvas.drawPath(slicePath, fillPaint);

    // 3. Hub putih r2.2 di (12, 12)
    canvas.drawCircle(const Offset(12, 12), 2.2, hubPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WheelNavPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.hubColor != hubColor ||
      oldDelegate.style != style;
}

/// Ikon Navigasi: Catatan (viewBox 24x24)
class ReceiptNavPainter extends CustomPainter {
  final Color color;
  final Color cutoutColor;
  final PutarIconStyle style;

  const ReceiptNavPainter({
    this.color = PutarTheme.kPasarMalamInk,
    this.cutoutColor = PutarTheme.kPasarMalamSurface,
    this.style = PutarIconStyle.pasarMalam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cutoutPaint = Paint()
      ..color = cutoutColor
      ..style = PaintingStyle.fill;

    if (style == PutarIconStyle.kucing) {
      // Struk berkuping tema Kucing Manis:
      // M5 4.5L6 .5L9.5 3ZM19 4.5L18 .5L14.5 3Z
      final earsPath = Path()
        ..moveTo(5, 4.5)
        ..lineTo(6, 0.5)
        ..lineTo(9.5, 3)
        ..close()
        ..moveTo(19, 4.5)
        ..lineTo(18, 0.5)
        ..lineTo(14.5, 3)
        ..close();
      canvas.drawPath(earsPath, fillPaint);

      // M5 4h14v17l-2.3-1.6-2.3 1.6-2.4-1.6-2.4 1.6-2.3-1.6L5 21Z
      final bodyPath = Path()
        ..moveTo(5, 4)
        ..lineTo(19, 4)
        ..lineTo(19, 21)
        ..lineTo(19 - 2.3, 21 - 1.6)
        ..lineTo(19 - 4.6, 21)
        ..lineTo(19 - 7.0, 21 - 1.6)
        ..lineTo(19 - 9.4, 21)
        ..lineTo(19 - 11.7, 21 - 1.6)
        ..lineTo(5, 21)
        ..close();
      canvas.drawPath(bodyPath, fillPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 8, 2),
          const Radius.circular(1),
        ),
        cutoutPaint,
      );
      canvas.drawCircle(const Offset(12, 14.5), 2.4, cutoutPaint);
      canvas.restore();
      return;
    }

    // 1. Badan Struk bergerigi bawah:
    // M5 2.5 h14 v18.5 l-2.3-1.6 -2.3 1.6 -2.4-1.6 -2.4 1.6 -2.3-1.6 L5 21 Z
    final receiptPath = Path();
    receiptPath.moveTo(5, 2.5);
    receiptPath.lineTo(19, 2.5);
    receiptPath.lineTo(19, 21.0);
    receiptPath.lineTo(19 - 2.3, 21.0 - 1.6);
    receiptPath.lineTo(19 - 2.3 - 2.3, 21.0);
    receiptPath.lineTo(19 - 4.6 - 2.4, 21.0 - 1.6);
    receiptPath.lineTo(19 - 7.0 - 2.4, 21.0);
    receiptPath.lineTo(19 - 9.4 - 2.3, 21.0 - 1.6);
    receiptPath.lineTo(5, 21.0);
    receiptPath.close();
    canvas.drawPath(receiptPath, fillPaint);

    // 2. Garis struk: rect x=8, y=6.5, w=8, h=2, rx=1
    final lineRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 6.5, 8, 2),
      const Radius.circular(1),
    );
    canvas.drawRRect(lineRRect, cutoutPaint);

    // 3. Koin berlubang: circle cx=12, cy=13.5, r=2.6
    canvas.drawCircle(const Offset(12, 13.5), 2.6, cutoutPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ReceiptNavPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cutoutColor != cutoutColor ||
      oldDelegate.style != style;
}

/// Ikon Navigasi: Riwayat (viewBox 24x24)
/// Sesuai Brand.dc.html & Tema2.dc.html:
/// `rect x="3.5" y="13" width="4.5" height="8" rx="2.2"`
/// `rect x="9.8" y="8.5" width="4.5" height="12.5" rx="2.2"`
/// `rect x="16" y="3" width="4.5" height="18" rx="2.2"`
class HistoryNavPainter extends CustomPainter {
  final Color color;
  final PutarIconStyle style;

  const HistoryNavPainter({
    this.color = PutarTheme.kPasarMalamInk,
    this.style = PutarIconStyle.pasarMalam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Batang 1: x=3.5, y=13, w=4.5, h=8, rx=2.2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.5, 13, 4.5, 8),
        const Radius.circular(2.2),
      ),
      fillPaint,
    );

    // Batang 2: x=9.8, y=8.5, w=4.5, h=12.5, rx=2.2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9.8, 8.5, 4.5, 12.5),
        const Radius.circular(2.2),
      ),
      fillPaint,
    );

    // Batang 3: x=16, y=3, w=4.5, h=18, rx=2.2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 3, 4.5, 18),
        const Radius.circular(2.2),
      ),
      fillPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HistoryNavPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.style != style;
}
