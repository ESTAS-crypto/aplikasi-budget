import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';

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
  final Paint _borderPaint;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  ConfettiPainter({
    required this.particles,
    required this.random,
    required Animation<double> animation,
    Color borderColor = PutarTheme.kPasarMalamInk,
  })  : _borderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        super(repaint: animation);

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
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate._borderPaint.color != _borderPaint.color;
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
  bool _initialized = false;
  late ConfettiPainter _painter;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = context.putarTheme;
    final palette = [
      t.accentCoral,
      t.accentYellow,
      t.accentBlue,
      t.accentPink,
    ];

    if (!_initialized) {
      _initialized = true;
      for (int i = 0; i < widget.particleCount; i++) {
        _particles.add(
          ConfettiParticle(
            x: _random.nextDouble(),
            y: _random.nextDouble() * 1.2 - 0.2,
            size: 10 + _random.nextDouble() * 10,
            speedY: 0.003 + _random.nextDouble() * 0.005,
            speedX: (_random.nextDouble() - 0.5) * 0.002,
            rotation: _random.nextDouble() * math.pi * 2,
            rotationSpeed: (_random.nextDouble() - 0.5) * 0.08,
            color: palette[i % palette.length],
            isCircle: _random.nextBool(),
          ),
        );
      }
    } else {
      for (int i = 0; i < _particles.length; i++) {
        _particles[i].color = palette[i % palette.length];
      }
    }

    _painter = ConfettiPainter(
      particles: _particles,
      random: _random,
      animation: _tickerController,
      borderColor: t.ink,
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


/// Partikel hati berborder ink untuk selebrasi tema Kucing Manis.
class HeartConfettiParticle {
  final double xRatio;
  final double startProgressOffset;
  final double speedFactor;
  final double size;
  final double swayAmp;
  final double swayFreq;
  final double initialRotation;
  final double rotationSpeed;
  final Color color;

  const HeartConfettiParticle({
    required this.xRatio,
    required this.startProgressOffset,
    required this.speedFactor,
    required this.size,
    required this.swayAmp,
    required this.swayFreq,
    required this.initialRotation,
    required this.rotationSpeed,
    required this.color,
  });
}

/// CustomPainter hujan hati pastel ber-outline ink (`Tema4.dc.html` & `KHgrup1.dc.html`).
class HeartConfettiPainter extends CustomPainter {
  final List<HeartConfettiParticle> particles;
  final double progress;
  final Color inkColor;

  HeartConfettiPainter({
    required this.particles,
    required this.progress,
    this.inkColor = const Color(0xFF3A2E4F),
  });

  /// Path SVG hati `viewBox 24x24` ternormalisasi di sekitar pusat `(0, 0)`.
  static final Path unitHeartPath = Path()
    ..moveTo(0, 7.5)
    ..cubicTo(-9, 0.5, -8.5, -6.5, -4, -7)
    ..cubicTo(-2, -7.2, -0.6, -6, 0, -4.8)
    ..cubicTo(0.6, -6, 2, -7.2, 4, -7)
    ..cubicTo(8.5, -6.5, 9, 0.5, 0, 7.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    for (final p in particles) {
      final t = (p.startProgressOffset + progress * p.speedFactor) % 1.0;
      final y = -28.0 + t * (size.height + 56.0);
      final sway = math.sin(t * math.pi * 2 * p.swayFreq) * p.swayAmp;
      final x = p.xRatio * size.width + sway;
      final alpha =
          (t < 0.78 ? 1.0 : (1.0 - (t - 0.78) / 0.22)).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final rot = p.initialRotation + (t * p.rotationSpeed);
      final scale = p.size / 24.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.scale(scale, scale);

      fillPaint.color = p.color.withValues(alpha: alpha);
      strokePaint.color = inkColor.withValues(alpha: alpha);

      canvas.drawPath(unitHeartPath, fillPaint);
      canvas.drawPath(unitHeartPath, strokePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant HeartConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.particles != particles;
}

/// Widget selebrasi hujan hati yang aman terhadap `disableAnimations` dan deterministik via [seed].
class HeartConfettiField extends StatefulWidget {
  final int particleCount;
  final List<Color>? colors;
  final Color? inkColor;
  final int seed;
  final bool animate;

  const HeartConfettiField({
    super.key,
    this.particleCount = 30,
    this.colors,
    this.inkColor,
    this.seed = 2026,
    this.animate = true,
  });

  @override
  State<HeartConfettiField> createState() => _HeartConfettiFieldState();
}

class _HeartConfettiFieldState extends State<HeartConfettiField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<HeartConfettiParticle> _particles = const [];
  bool _reduceMotion = false;
  PutarTheme? _lastTheme;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = context.putarTheme;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (_particles.isEmpty || _lastTheme != t) {
      _lastTheme = t;
      _buildParticles(t);
    }

    if (widget.animate && !_reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0.25;
    }
  }

  @override
  void didUpdateWidget(covariant HeartConfettiField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.particleCount != widget.particleCount ||
        oldWidget.seed != widget.seed ||
        oldWidget.colors != widget.colors) {
      _buildParticles(context.putarTheme);
    }
    if (oldWidget.animate != widget.animate) {
      if (widget.animate && !_reduceMotion) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  void _buildParticles(PutarTheme t) {
    final palette = widget.colors ??
        <Color>[
          t.primary,
          t.secondary,
          t.surface,
          t.accentPurple,
          t.accentMint,
        ];
    final rng = math.Random(widget.seed);
    _particles = List.generate(widget.particleCount, (i) {
      return HeartConfettiParticle(
        xRatio: 0.04 + rng.nextDouble() * 0.92,
        startProgressOffset: rng.nextDouble(),
        speedFactor: 0.8 + rng.nextDouble() * 0.45,
        size: 18.0 + rng.nextDouble() * 10.0,
        swayAmp: 6.0 + rng.nextDouble() * 14.0,
        swayFreq: 1.0 + rng.nextInt(2).toDouble(),
        initialRotation: (rng.nextDouble() - 0.5) * 0.6,
        rotationSpeed: (rng.nextBool() ? 1 : -1) * (1.2 + rng.nextDouble() * 2.2),
        color: palette[i % palette.length],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: HeartConfettiPainter(
            particles: _particles,
            progress: _controller.value,
            inkColor: widget.inkColor ?? t.ink,
          ),
        );
      },
    );
  }
}
