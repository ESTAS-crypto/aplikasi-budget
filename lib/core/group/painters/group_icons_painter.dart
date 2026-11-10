import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ikon Vektor Custom untuk Fitur Grup & Sinkronisasi
/// Gaya Neo-Brutalist: strokeWidth 2.8, StrokeCap.round, StrokeJoin.round

/// Ikon Jam (Status Menunggu)
class CustomClockPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomClockPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Lingkaran jam
    canvas.drawCircle(center, radius, paint);

    // Jarum jam: tengah ke atas dan ke kanan
    final path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.55)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.45, center.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Centang (Status Terkirim / Tersinkron)
class CustomCheckPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCheckPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.82, size.height * 0.24);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Awan Dicoret (Status Offline)
class CustomCloudOfflinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCloudOfflinePainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Garis awan sederhana
    final cloudPath = Path()
      ..moveTo(w * 0.25, h * 0.70)
      ..cubicTo(w * 0.10, h * 0.70, w * 0.10, h * 0.50, w * 0.25, h * 0.48)
      ..cubicTo(w * 0.25, h * 0.28, w * 0.55, h * 0.26, w * 0.65, h * 0.40)
      ..cubicTo(w * 0.80, h * 0.38, w * 0.90, h * 0.52, w * 0.80, h * 0.70)
      ..lineTo(w * 0.25, h * 0.70);

    canvas.drawPath(cloudPath, paint);

    // Garis diagonal coret
    canvas.drawLine(
      Offset(w * 0.12, h * 0.85),
      Offset(w * 0.88, h * 0.15),
      paint..strokeWidth = strokeWidth + 0.4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Panah Berputar (Status Menyinkronkan)
class CustomSyncArrowsPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomSyncArrowsPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth * 1.5;

    // Busur atas
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi * 0.85, math.pi * 0.7, false, paint);
    // Panah busur atas
    final arrowTop = Path()
      ..moveTo(center.dx + radius * 0.6, center.dy - radius * 0.7)
      ..lineTo(center.dx + radius * 0.9, center.dy - radius * 0.4)
      ..lineTo(center.dx + radius * 0.4, center.dy - radius * 0.3);
    canvas.drawPath(arrowTop, paint);

    // Busur bawah
    canvas.drawArc(rect, math.pi * 0.15, math.pi * 0.7, false, paint);
    // Panah busur bawah
    final arrowBottom = Path()
      ..moveTo(center.dx - radius * 0.6, center.dy + radius * 0.7)
      ..lineTo(center.dx - radius * 0.9, center.dy + radius * 0.4)
      ..lineTo(center.dx - radius * 0.4, center.dy + radius * 0.3);
    canvas.drawPath(arrowBottom, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Segitiga Peringatan / Gagal
class CustomWarningTrianglePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomWarningTrianglePainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, h * 0.14)
      ..lineTo(w * 0.88, h * 0.84)
      ..lineTo(w * 0.12, h * 0.84)
      ..close();

    canvas.drawPath(path, paint);

    // Garis seru
    canvas.drawLine(
      Offset(w * 0.5, h * 0.40),
      Offset(w * 0.5, h * 0.62),
      paint,
    );

    // Titik seru
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.74),
      strokeWidth * 0.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Salin (Dua lembar kertas bertumpuk)
class CustomCopyPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCopyPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Kertas belakang (sudut kiri atas)
    final backPaper = Path()
      ..moveTo(w * 0.65, h * 0.20)
      ..lineTo(w * 0.22, h * 0.20)
      ..lineTo(w * 0.22, h * 0.65);
    canvas.drawPath(backPaper, paint);

    // Kertas depan (persegi panjang dengan radius kecil)
    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.35, h * 0.32, w * 0.50, h * 0.55),
      const Radius.circular(3),
    );
    canvas.drawRRect(frontRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Bagikan (Share 3 lingkaran terhubung)
class CustomSharePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomSharePainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final p1 = Offset(w * 0.75, h * 0.25); // Atas kanan
    final p2 = Offset(w * 0.25, h * 0.50); // Kiri tengah
    final p3 = Offset(w * 0.75, h * 0.75); // Bawah kanan

    // Garis penghubung
    canvas.drawLine(p2, p1, strokePaint);
    canvas.drawLine(p2, p3, strokePaint);

    // 3 Lingkaran simpul
    const r = 3.5;
    canvas.drawCircle(p1, r, fillPaint);
    canvas.drawCircle(p2, r, fillPaint);
    canvas.drawCircle(p3, r, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Mahkota (Pemilik Grup)
class CustomCrownPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCrownPainter({
    required this.color,
    this.strokeWidth = 2.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final crown = Path()
      ..moveTo(w * 0.15, h * 0.75)
      ..lineTo(w * 0.10, h * 0.35)
      ..lineTo(w * 0.35, h * 0.55)
      ..lineTo(w * 0.50, h * 0.25)
      ..lineTo(w * 0.65, h * 0.55)
      ..lineTo(w * 0.90, h * 0.35)
      ..lineTo(w * 0.85, h * 0.75)
      ..close();

    canvas.drawPath(crown, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Lonceng (Notifikasi Aktivitas)
class CustomBellPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomBellPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Bentuk kubah lonceng
    final bell = Path()
      ..moveTo(w * 0.20, h * 0.70)
      ..lineTo(w * 0.80, h * 0.70)
      ..quadraticBezierTo(w * 0.75, h * 0.45, w * 0.65, h * 0.35)
      ..quadraticBezierTo(w * 0.55, h * 0.20, w * 0.50, h * 0.20)
      ..quadraticBezierTo(w * 0.45, h * 0.20, w * 0.35, h * 0.35)
      ..quadraticBezierTo(w * 0.25, h * 0.45, w * 0.20, h * 0.70)
      ..close();
    canvas.drawPath(bell, paint);

    // Tangkai atas
    canvas.drawLine(Offset(w * 0.5, h * 0.14), Offset(w * 0.5, h * 0.20), paint);

    // Bandul bawah
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.74), width: w * 0.22, height: h * 0.15),
      0,
      math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Keluar / Logout
class CustomExitPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomExitPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Bingkai pintu
    final door = Path()
      ..moveTo(w * 0.55, h * 0.15)
      ..lineTo(w * 0.20, h * 0.15)
      ..lineTo(w * 0.20, h * 0.85)
      ..lineTo(w * 0.55, h * 0.85);
    canvas.drawPath(door, paint);

    // Panah keluar
    canvas.drawLine(Offset(w * 0.40, h * 0.50), Offset(w * 0.85, h * 0.50), paint);
    final arrow = Path()
      ..moveTo(w * 0.68, h * 0.33)
      ..lineTo(w * 0.85, h * 0.50)
      ..lineTo(w * 0.68, h * 0.67);
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Panah Kembali (Neo-Brutalist Back Arrow)
class CustomBackArrowPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomBackArrowPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Garis horizontal
    canvas.drawLine(Offset(w * 0.85, h * 0.50), Offset(w * 0.20, h * 0.50), paint);

    // Kepala panah ke kiri
    final head = Path()
      ..moveTo(w * 0.48, h * 0.22)
      ..lineTo(w * 0.20, h * 0.50)
      ..lineTo(w * 0.48, h * 0.78);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Info Lingkaran
class CustomInfoCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomInfoCirclePainter({
    required this.color,
    this.strokeWidth = 2.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    canvas.drawCircle(center, radius, paint);

    // Titik atas
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.45),
      strokeWidth * 0.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Batang huruf i
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.15),
      Offset(center.dx, center.dy + radius * 0.50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Struk / Kertas Nota
class CustomReceiptPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomReceiptPainter({
    required this.color,
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.20, h * 0.15)
      ..lineTo(w * 0.80, h * 0.15)
      ..lineTo(w * 0.80, h * 0.85)
      // Gigi bergerigi bawah
      ..lineTo(w * 0.68, h * 0.78)
      ..lineTo(w * 0.56, h * 0.85)
      ..lineTo(w * 0.44, h * 0.78)
      ..lineTo(w * 0.32, h * 0.85)
      ..lineTo(w * 0.20, h * 0.78)
      ..close();

    canvas.drawPath(path, paint);

    // Baris-baris teks struk
    canvas.drawLine(Offset(w * 0.32, h * 0.35), Offset(w * 0.68, h * 0.35), paint..strokeWidth = strokeWidth * 0.8);
    canvas.drawLine(Offset(w * 0.32, h * 0.48), Offset(w * 0.60, h * 0.48), paint..strokeWidth = strokeWidth * 0.8);
    canvas.drawLine(Offset(w * 0.32, h * 0.61), Offset(w * 0.68, h * 0.61), paint..strokeWidth = strokeWidth * 0.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



/// Ikon Silang (Cross / Batal / Tutup)
class CustomCrossPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomCrossPainter({
    required this.color,
    this.strokeWidth = 2.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w * 0.25, h * 0.25), Offset(w * 0.75, h * 0.75), paint);
    canvas.drawLine(Offset(w * 0.75, h * 0.25), Offset(w * 0.25, h * 0.75), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ikon Tempel (Clipboard / Paste)
class CustomPastePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomPastePainter({
    required this.color,
    this.strokeWidth = 2.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Garis outline clipboard (papan)
    final boardPath = Path()
      ..moveTo(w * 0.32, h * 0.22)
      ..lineTo(w * 0.16, h * 0.22)
      ..lineTo(w * 0.16, h * 0.90)
      ..lineTo(w * 0.84, h * 0.90)
      ..lineTo(w * 0.84, h * 0.22)
      ..lineTo(w * 0.68, h * 0.22);
    canvas.drawPath(boardPath, paint);

    // Klip penjepit di atas tengah
    final clipPath = Path()
      ..moveTo(w * 0.32, h * 0.22)
      ..lineTo(w * 0.32, h * 0.12)
      ..lineTo(w * 0.68, h * 0.12)
      ..lineTo(w * 0.68, h * 0.22)
      ..close();
    canvas.drawPath(clipPath, paint);

    // Garis-garis dokumen di tengah
    canvas.drawLine(
      Offset(w * 0.30, h * 0.44),
      Offset(w * 0.70, h * 0.44),
      paint..strokeWidth = strokeWidth * 0.8,
    );
    canvas.drawLine(
      Offset(w * 0.30, h * 0.60),
      Offset(w * 0.70, h * 0.60),
      paint..strokeWidth = strokeWidth * 0.8,
    );
    canvas.drawLine(
      Offset(w * 0.30, h * 0.76),
      Offset(w * 0.54, h * 0.76),
      paint..strokeWidth = strokeWidth * 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Ikon Pengaturan Roda Gigi (Gear / Settings) Layar 20 & 44
class CustomGearPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomGearPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Lingkaran luar (r=6.5) & lingkaran dalam (r=2)
    canvas.drawCircle(const Offset(12, 12), 6.5, paint);
    canvas.drawCircle(const Offset(12, 12), 2.0, paint);

    // 8 gerigi radial
    // Vertikal
    canvas.drawLine(const Offset(12, 2), const Offset(12, 5), paint);
    canvas.drawLine(const Offset(12, 19), const Offset(12, 22), paint);
    // Horisontal
    canvas.drawLine(const Offset(2, 12), const Offset(5, 12), paint);
    canvas.drawLine(const Offset(19, 12), const Offset(22, 12), paint);
    // Diagonal 1
    canvas.drawLine(const Offset(5, 5), const Offset(7, 7), paint);
    canvas.drawLine(const Offset(17, 17), const Offset(19, 19), paint);
    // Diagonal 2
    canvas.drawLine(const Offset(19, 5), const Offset(17, 7), paint);
    canvas.drawLine(const Offset(7, 17), const Offset(5, 19), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





/// Ikon Roda Putar (Wheel) Layar 46 & Notif1
class CustomWheelPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomWheelPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Lingkaran luar r=9
    canvas.drawCircle(const Offset(12, 12), 9, paint);
    // Jarum 3 arah
    canvas.drawLine(const Offset(12, 12), const Offset(12, 3), paint);
    canvas.drawLine(const Offset(12, 12), const Offset(19.8, 16.5), paint);
    canvas.drawLine(const Offset(12, 12), const Offset(4.2, 16.5), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





/// Ikon Tambah Anggota (User Plus) Layar 46 & Notif1
class CustomUserPlusPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomUserPlusPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Kepala user
    canvas.drawCircle(const Offset(10, 8), 3.5, paint);
    // Badan user
    final body = Path()
      ..moveTo(3.5, 20)
      ..lineTo(3.5, 18.5)
      ..arcToPoint(const Offset(8.5, 13.5), radius: const Radius.circular(5))
      ..lineTo(11.5, 13.5)
      ..arcToPoint(const Offset(16.5, 18.5), radius: const Radius.circular(5))
      ..lineTo(16.5, 20);
    canvas.drawPath(body, paint);

    // Plus (+)
    canvas.drawLine(const Offset(19, 8), const Offset(19, 14), paint);
    canvas.drawLine(const Offset(16, 11), const Offset(22, 11), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





/// Ikon Kurang Anggota (User Minus) Layar 46 & Notif1
class CustomUserMinusPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomUserMinusPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    canvas.drawCircle(const Offset(10, 8), 3.5, paint);
    final body = Path()
      ..moveTo(3.5, 20)
      ..lineTo(3.5, 18.5)
      ..arcToPoint(const Offset(8.5, 13.5), radius: const Radius.circular(5))
      ..lineTo(11.5, 13.5)
      ..arcToPoint(const Offset(16.5, 18.5), radius: const Radius.circular(5))
      ..lineTo(16.5, 20);
    canvas.drawPath(body, paint);

    // Minus (-)
    canvas.drawLine(const Offset(16, 11), const Offset(22, 11), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





/// Ikon Kunci Kode Undangan (Key) Layar 46 & Notif1
class CustomKeyPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomKeyPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Kunci
    final path = Path()
      ..moveTo(8, 15.5)
      ..arcToPoint(const Offset(11, 16.7), radius: const Radius.circular(4.5))
      ..lineTo(5, 21)
      ..lineTo(5, 18)
      ..lineTo(3, 18)
      ..lineTo(3, 16)
      ..lineTo(5, 16)
      ..close();
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





/// Ikon Bendera Selesai (Flag) Layar 46 & Notif1
class CustomFlagPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomFlagPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Tiang bendera
    canvas.drawLine(const Offset(5, 21), const Offset(5, 4), paint);
    // Bendera
    final flag = Path()
      ..moveTo(5, 4)
      ..lineTo(16, 4)
      ..lineTo(14, 8)
      ..lineTo(16, 12)
      ..lineTo(5, 12);
    canvas.drawPath(flag, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





/// Ikon Tempat Sampah (Trash) Layar 46 & Notif1
class CustomTrashPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomTrashPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Garis atas & pegangan
    canvas.drawLine(const Offset(5, 7), const Offset(19, 7), paint);
    final lid = Path()
      ..moveTo(10, 7)
      ..lineTo(10, 4)
      ..lineTo(14, 4)
      ..lineTo(14, 7);
    canvas.drawPath(lid, paint);

    // Wadah sampah
    final body = Path()
      ..moveTo(7, 7)
      ..lineTo(8, 20)
      ..lineTo(16, 20)
      ..lineTo(17, 7);
    canvas.drawPath(body, paint);

    // Garis isi sampah
    canvas.drawLine(const Offset(10.5, 11), const Offset(10.5, 17), paint);
    canvas.drawLine(const Offset(13.5, 11), const Offset(13.5, 17), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ikon Chevron Kanan (Neo-Brutalist Chevron Right)
class CustomChevronRightPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const CustomChevronRightPainter({
    this.color = const Color(0xFF22163A),
    this.strokeWidth = 2.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.35, size.height * 0.20)
      ..lineTo(size.width * 0.70, size.height * 0.50)
      ..lineTo(size.width * 0.35, size.height * 0.80);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}




