import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ConfettiParticle {
  double x;
  double y;
  double size;
  double speedY;
  double speedX;
  double rotation;
  double rotationSpeed;
  Color color;
  bool isCircle;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
    required this.speedX,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.isCircle,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final math.Random random;
  final Paint _borderPaint = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  ConfettiPainter({
    required this.particles,
    required this.random,
    required Animation<double> animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    for (final p in particles) {
      // Perbarui posisi partikel
      p.y += p.speedY;
      p.x += p.speedX + math.sin(p.y * 10) * 0.0008;
      p.rotation += p.rotationSpeed;

      if (p.y > 1.1) {
        p.y = -0.1;
        p.x = random.nextDouble();
      }

      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rotation);

      _fillPaint.color = p.color;

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, _fillPaint);
        canvas.drawCircle(Offset.zero, p.size / 2, _borderPaint);
      } else {
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          _fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          _borderPaint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => false;
}

/// Widget Confetti aktif dengan Ticker 60fps yang diisolasi di RepaintBoundary
class ConfettiField extends StatefulWidget {
  final int particleCount;

  const ConfettiField({super.key, this.particleCount = 45});

  @override
  State<ConfettiField> createState() => _ConfettiFieldState();
}

class _ConfettiFieldState extends State<ConfettiField>
    with SingleTickerProviderStateMixin {
  late AnimationController _tickerController;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();
  late final ConfettiPainter _painter;

  final List<Color> _colors = const [
    AppColors.tomat,
    AppColors.matahari,
    AppColors.langit,
    AppColors.permen,
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble() * 1.2 - 0.2, // Mulai dari atas layar
          size: 10 + _random.nextDouble() * 10,
          speedY: 0.003 + _random.nextDouble() * 0.005,
          speedX: (_random.nextDouble() - 0.5) * 0.002,
          rotation: _random.nextDouble() * math.pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.08,
          color: _colors[i % _colors.length],
          isCircle: _random.nextBool(),
        ),
      );
    }

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _painter = ConfettiPainter(
      particles: _particles,
      random: _random,
      animation: _tickerController,
    );
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _painter,
      ),
    );
  }
}
