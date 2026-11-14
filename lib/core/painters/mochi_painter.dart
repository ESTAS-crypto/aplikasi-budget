import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';
import '../utils/sound_service.dart';

/// Lima ekspresi wajah maskot Mochi untuk tema Kucing Manis.
enum MochiExpression {
  normal,
  happy,
  wow,
  sad,
  sleepy,
}

/// CustomPainter vektor maskot Mochi (`viewBox 100x100`) sesuai desain Tema Kucing.
/// Mendukung 5 ekspresi, animasi kedip (`blinkScaleY`), kedut kuping (`earTwitchAngle`),
/// ayunan lonceng (`bellSwingRadians`), dan kustomisasi warna lewat token [PutarTheme].
class MochiPainter extends CustomPainter {
  final MochiExpression expression;
  final Color furColor;
  final Color earPinkColor;
  final Color blushColor;
  final Color noseColor;
  final Color bellColor;
  final Color muzzleColor;
  final Color inkColor;
  final Color highlightColor;
  final Color tearColor;
  final double blinkScaleY;
  final double earTwitchAngle;
  final double bellSwingRadians;
  final bool showCollar;
  final double strokeWidth;

  const MochiPainter({
    this.expression = MochiExpression.normal,
    this.furColor = const Color(0xFFFFB066),
    this.earPinkColor = const Color(0xFFFF8FB1),
    this.blushColor = const Color(0xFFFF9FB8),
    this.noseColor = const Color(0xFFFF7A9C),
    this.bellColor = const Color(0xFFFFD23F),
    this.muzzleColor = const Color(0xFFFFF3E0),
    this.inkColor = const Color(0xFF3A2E4F),
    this.highlightColor = const Color(0xFFFFFFFF),
    this.tearColor = const Color(0xFFA8D8FF),
    this.blinkScaleY = 1.0,
    this.earTwitchAngle = 0.0,
    this.bellSwingRadians = 0.0,
    this.showCollar = true,
    this.strokeWidth = 3.5,
  });

  /// Membuat [MochiPainter] memakai palet maskot dari [PutarTheme].
  factory MochiPainter.fromTheme(
    PutarTheme theme, {
    MochiExpression expression = MochiExpression.normal,
    double blinkScaleY = 1.0,
    double earTwitchAngle = 0.0,
    double bellSwingRadians = 0.0,
    bool showCollar = true,
    double strokeWidth = 3.5,
  }) {
    return MochiPainter(
      expression: expression,
      furColor: theme.mascotFur,
      earPinkColor: theme.mascotEarPink,
      blushColor: theme.mascotBlush,
      noseColor: theme.mascotNose,
      bellColor: theme.mascotBell,
      muzzleColor: theme.mascotMuzzle,
      inkColor: theme.ink,
      highlightColor: theme.surface,
      tearColor: theme.accentBlue,
      blinkScaleY: blinkScaleY,
      earTwitchAngle: earTwitchAngle,
      bellSwingRadians: bellSwingRadians,
      showCollar: showCollar,
      strokeWidth: strokeWidth,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100.0;
    final sy = size.height / 100.0;

    canvas.save();
    canvas.scale(sx, sy);

    final furFill = Paint()
      ..color = furColor
      ..style = PaintingStyle.fill;

    final innerEarFill = Paint()
      ..color = earPinkColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 1. Kuping kiri: luar fur + stroke, dalam pink
    final leftOuterEar = Path()
      ..moveTo(16, 44)
      ..quadraticBezierTo(14, 16, 24, 11)
      ..quadraticBezierTo(38, 16, 44, 29)
      ..close();
    canvas.drawPath(leftOuterEar, furFill);
    canvas.drawPath(leftOuterEar, strokePaint);

    final leftInnerEar = Path()
      ..moveTo(22, 36)
      ..quadraticBezierTo(22, 22, 27, 19)
      ..quadraticBezierTo(34, 22, 37, 29)
      ..close();
    canvas.drawPath(leftInnerEar, innerEarFill);

    // 2. Kuping kanan (mendukung kedut ringan sekitar pangkal kuping)
    canvas.save();
    if (earTwitchAngle != 0.0) {
      canvas.translate(70, 32);
      canvas.rotate(earTwitchAngle);
      canvas.translate(-70, -32);
    }
    final rightOuterEar = Path()
      ..moveTo(84, 44)
      ..quadraticBezierTo(86, 16, 76, 11)
      ..quadraticBezierTo(62, 16, 56, 29)
      ..close();
    canvas.drawPath(rightOuterEar, furFill);
    canvas.drawPath(rightOuterEar, strokePaint);

    final rightInnerEar = Path()
      ..moveTo(78, 36)
      ..quadraticBezierTo(78, 22, 73, 19)
      ..quadraticBezierTo(66, 22, 63, 29)
      ..close();
    canvas.drawPath(rightInnerEar, innerEarFill);
    canvas.restore();

    // 3. Kepala oval (cx=50, cy=58, rx=40, ry=34)
    final headRect = Rect.fromCenter(
      center: const Offset(50, 58),
      width: 80,
      height: 68,
    );
    canvas.drawOval(headRect, furFill);
    canvas.drawOval(headRect, strokePaint);

    // 4. Garis dahi kucing belang (tabby)
    final tabbyStroke = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(50, 26), const Offset(50, 33), tabbyStroke);
    canvas.drawLine(const Offset(42, 27.5), const Offset(43.5, 33.5), tabbyStroke);
    canvas.drawLine(const Offset(58, 27.5), const Offset(56.5, 33.5), tabbyStroke);

    // 5. Moncong krim (cx=50, cy=69, rx=12, ry=8.5)
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(50, 69),
        width: 24,
        height: 17,
      ),
      Paint()
        ..color = muzzleColor
        ..style = PaintingStyle.fill,
    );

    // 6. Rona pipi kanan & kiri (alpha 0.75)
    final blushPaint = Paint()
      ..color = blushColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(23, 69), width: 14, height: 9),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(77, 69), width: 14, height: 9),
      blushPaint,
    );

    // 7. Kumis 2 kiri + 2 kanan
    final whiskerStroke = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(15, 62), const Offset(6, 59.5), whiskerStroke);
    canvas.drawLine(const Offset(15, 68), const Offset(6, 70), whiskerStroke);
    canvas.drawLine(const Offset(85, 62), const Offset(94, 59.5), whiskerStroke);
    canvas.drawLine(const Offset(85, 68), const Offset(94, 70), whiskerStroke);

    // 8. Ekspresi mata, mulut, air mata / 'z'
    _paintExpression(canvas, strokePaint);

    // 9. Hidung pink kecil (di atas garis mulut)
    final nosePath = Path()
      ..moveTo(47.5, 62.5)
      ..lineTo(52.5, 62.5)
      ..quadraticBezierTo(52.5, 65.5, 50, 66.7)
      ..quadraticBezierTo(47.5, 65.5, 47.5, 62.5)
      ..close();
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = noseColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );

    // 10. Kalung & lonceng
    if (showCollar) {
      _paintCollarAndBell(canvas);
    }

    canvas.restore();
  }

  void _paintExpression(Canvas canvas, Paint strokePaint) {
    final eyeFill = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill;
    final highlightFill = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;
    final mouthStroke = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (expression) {
      case MochiExpression.normal:
        final scaleY = blinkScaleY.clamp(0.08, 1.0);
        canvas.save();
        canvas.translate(0, 56);
        canvas.scale(1.0, scaleY);
        canvas.translate(0, -56);

        final leftEye =
            Rect.fromCenter(center: const Offset(34, 56), width: 12, height: 15);
        final rightEye =
            Rect.fromCenter(center: const Offset(66, 56), width: 12, height: 15);
        canvas.drawOval(leftEye, eyeFill);
        canvas.drawOval(leftEye, strokePaint);
        canvas.drawOval(rightEye, eyeFill);
        canvas.drawOval(rightEye, strokePaint);

        canvas.drawCircle(const Offset(36, 53), 2.6, highlightFill);
        canvas.drawCircle(const Offset(68, 53), 2.6, highlightFill);
        canvas.drawCircle(const Offset(32.5, 60), 1.3, highlightFill);
        canvas.drawCircle(const Offset(64.5, 60), 1.3, highlightFill);
        canvas.restore();

        _paintCatSmileMouth(canvas, mouthStroke);

      case MochiExpression.happy:
        final leftArc = Path()
          ..moveTo(27, 58)
          ..quadraticBezierTo(34, 48, 41, 58);
        final rightArc = Path()
          ..moveTo(59, 58)
          ..quadraticBezierTo(66, 48, 73, 58);
        canvas.drawPath(leftArc, strokePaint);
        canvas.drawPath(rightArc, strokePaint);

        final openMouth = Path()
          ..moveTo(45, 68.5)
          ..quadraticBezierTo(50, 76.5, 55, 68.5)
          ..close();
        canvas.drawPath(
          openMouth,
          Paint()
            ..color = noseColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          openMouth,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeJoin = StrokeJoin.round,
        );

      case MochiExpression.wow:
        final leftEye =
            Rect.fromCenter(center: const Offset(34, 56), width: 14, height: 17);
        final rightEye =
            Rect.fromCenter(center: const Offset(66, 56), width: 14, height: 17);
        canvas.drawOval(leftEye, eyeFill);
        canvas.drawOval(leftEye, strokePaint);
        canvas.drawOval(rightEye, eyeFill);
        canvas.drawOval(rightEye, strokePaint);

        canvas.drawCircle(const Offset(36.4, 52.6), 3.0, highlightFill);
        canvas.drawCircle(const Offset(68.4, 52.6), 3.0, highlightFill);

        canvas.drawCircle(
          const Offset(50, 71),
          3.2,
          Paint()
            ..color = noseColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          const Offset(50, 71),
          3.2,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

      case MochiExpression.sad:
        final leftDroop = Path()
          ..moveTo(27, 54)
          ..quadraticBezierTo(34, 62, 41, 54);
        final rightDroop = Path()
          ..moveTo(59, 54)
          ..quadraticBezierTo(66, 62, 73, 54);
        canvas.drawPath(leftDroop, strokePaint);
        canvas.drawPath(rightDroop, strokePaint);

        final tearPath = Path()
          ..moveTo(74, 62)
          ..quadraticBezierTo(69.5, 69, 74, 71.5)
          ..quadraticBezierTo(78.5, 69, 74, 62)
          ..close();
        canvas.drawPath(
          tearPath,
          Paint()
            ..color = tearColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          tearPath,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeJoin = StrokeJoin.round,
        );

        final frownPath = Path()
          ..moveTo(43, 73)
          ..quadraticBezierTo(50, 68, 57, 73);
        canvas.drawPath(frownPath, mouthStroke);

      case MochiExpression.sleepy:
        canvas.drawLine(const Offset(28, 58), const Offset(41, 58), strokePaint);
        canvas.drawLine(const Offset(59, 58), const Offset(72, 58), strokePaint);
        _paintCatSmileMouth(canvas, mouthStroke);

        // Huruf 'z' vektor mengambang dekat dahi kanan
        final zPath = Path()
          ..moveTo(77, 20)
          ..lineTo(86, 20)
          ..lineTo(77, 30)
          ..lineTo(86, 30);
        canvas.drawPath(
          zPath,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
    }
  }

  void _paintCatSmileMouth(Canvas canvas, Paint mouthStroke) {
    final mouthPath = Path()
      ..moveTo(50, 66.7)
      ..lineTo(50, 68.3)
      ..quadraticBezierTo(46.5, 72.1, 43, 68.9)
      ..moveTo(50, 68.3)
      ..quadraticBezierTo(53.5, 72.1, 57, 68.9);
    canvas.drawPath(mouthPath, mouthStroke);
  }

  void _paintCollarAndBell(Canvas canvas) {
    final collarPath = Path()
      ..moveTo(29, 85)
      ..quadraticBezierTo(50, 97, 71, 85);
    canvas.drawPath(
      collarPath,
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      collarPath,
      Paint()
        ..color = earPinkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.save();
    if (bellSwingRadians != 0.0) {
      canvas.translate(50, 90);
      canvas.rotate(bellSwingRadians);
      canvas.translate(-50, -90);
    }
    canvas.drawCircle(
      const Offset(50, 95),
      5.0,
      Paint()
        ..color = bellColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      const Offset(50, 95),
      5.0,
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      const Offset(47, 95.5),
      const Offset(53, 95.5),
      Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MochiPainter oldDelegate) =>
      oldDelegate.expression != expression ||
      oldDelegate.furColor != furColor ||
      oldDelegate.earPinkColor != earPinkColor ||
      oldDelegate.blushColor != blushColor ||
      oldDelegate.noseColor != noseColor ||
      oldDelegate.bellColor != bellColor ||
      oldDelegate.muzzleColor != muzzleColor ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.highlightColor != highlightColor ||
      oldDelegate.tearColor != tearColor ||
      oldDelegate.blinkScaleY != blinkScaleY ||
      oldDelegate.earTwitchAngle != earTwitchAngle ||
      oldDelegate.bellSwingRadians != bellSwingRadians ||
      oldDelegate.showCollar != showCollar ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Widget maskot Mochi interaktif dengan kedipan 4 detik, kedut kuping 8 detik,
/// pantulan ketuk 200ms (`1 -> 1.08 -> 1`), suara meong ber-throttle 600ms,
/// serta label aksesibilitas TalkBack `'Mochi'`.
class MochiWidget extends StatefulWidget {
  final double size;
  final MochiExpression expression;
  final bool animate;
  final bool enableTap;
  final bool decorative;
  final bool showCollar;
  final double? bellSwingRadians;
  final VoidCallback? onTap;

  const MochiWidget({
    super.key,
    this.size = 100.0,
    this.expression = MochiExpression.normal,
    this.animate = true,
    this.enableTap = true,
    this.decorative = false,
    this.showCollar = true,
    this.bellSwingRadians,
    this.onTap,
  });

  @override
  State<MochiWidget> createState() => _MochiWidgetState();
}

class _MochiWidgetState extends State<MochiWidget>
    with TickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _blinkScaleY;

  late final AnimationController _earController;
  late final Animation<double> _earTwitchAngle;

  late final AnimationController _tapController;
  late final Animation<double> _tapScale;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _blinkScaleY = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 92),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.1),
        weight: 3,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 1.0),
        weight: 5,
      ),
    ]).animate(_blinkController);

    _earController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );
    _earTwitchAngle = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 91),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.16)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 3,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.16, end: -0.07)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 3,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.07, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 3,
      ),
    ]).animate(_earController);

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_tapController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant MochiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        oldWidget.expression != widget.expression) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    final shouldAnimate = widget.animate && !_reduceMotion;
    if (shouldAnimate && widget.expression == MochiExpression.normal) {
      if (!_blinkController.isAnimating) {
        _blinkController.repeat();
      }
    } else {
      _blinkController.stop();
      _blinkController.value = 0.0;
    }

    if (shouldAnimate) {
      if (!_earController.isAnimating) {
        _earController.repeat();
      }
    } else {
      _earController.stop();
      _earController.value = 0.0;
    }
  }

  void _handleTap() {
    if (!widget.enableTap) return;
    if (!_reduceMotion) {
      _tapController.forward(from: 0.0);
    }
    SoundService.instance.playMeow();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (!widget.enableTap) return;
    if (!_reduceMotion) {
      _tapController.forward(from: 0.0);
    }
    SoundService.instance.playPurr();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _earController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final body = AnimatedBuilder(
      animation: Listenable.merge([
        _blinkController,
        _earController,
        _tapController,
      ]),
      builder: (context, _) {
        final effectiveBellSwing = widget.bellSwingRadians ??
            (_tapController.isAnimating
                ? math.sin(_tapController.value * math.pi * 2) * 0.25
                : 0.0);
        return Transform.scale(
          scale: _tapController.isAnimating ? _tapScale.value : 1.0,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: MochiPainter.fromTheme(
              t,
              expression: widget.expression,
              blinkScaleY: widget.expression == MochiExpression.normal
                  ? _blinkScaleY.value
                  : 1.0,
              earTwitchAngle: _earTwitchAngle.value,
              bellSwingRadians: effectiveBellSwing,
              showCollar: widget.showCollar,
            ),
          ),
        );
      },
    );

    final interactive = widget.enableTap
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            child: body,
          )
        : body;

    if (widget.decorative) {
      return ExcludeSemantics(child: interactive);
    }

    return Semantics(
      label: 'Mochi',
      button: widget.enableTap,
      child: interactive,
    );
  }
}
