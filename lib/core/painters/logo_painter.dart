import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';
import 'mochi_painter.dart';

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
    this.wheelColor = PutarTheme.kPasarMalamTomat,
    this.sliceColor = PutarTheme.kPasarMalamMatahari,
    this.inkColor = PutarTheme.kPasarMalamInk,
    this.hubColor = PutarTheme.kPasarMalamSurface,
    this.coinColor = PutarTheme.kPasarMalamInk,
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
    final wheelPath = Path();
    wheelPath.moveTo(50, 50);
    wheelPath.lineTo(81.177, 32.0);
    wheelPath.arcTo(
      Rect.fromCircle(center: const Offset(50, 50), radius: 36),
      -30 * math.pi / 180,
      300 * math.pi / 180,
      false,
    );
    wheelPath.close();

    canvas.drawPath(wheelPath, wheelFill);
    canvas.drawPath(wheelPath, strokePaint);

    // 2. Irisan Terlepas: M53 44.8 L53 8.8 A36 36 0 0 1 84.2 26.8 Z
    final slicePath = Path();
    slicePath.moveTo(53, 44.8);
    slicePath.lineTo(53, 8.8);
    slicePath.arcTo(
      Rect.fromCircle(center: const Offset(53, 44.8), radius: 36),
      -90 * math.pi / 180,
      60 * math.pi / 180,
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
        oldDelegate.coinColor != coinColor ||
        oldDelegate.strokeWidthRatio != strokeWidthRatio;
  }
}

/// Widget Logo Putar Jajan yang membaca token tema aktif bila warna tidak di-override,
/// serta melakukan morphing halus ketika tema berganti.
class LogoWidget extends StatelessWidget {
  final double size;
  final Color? wheelColor;
  final Color? sliceColor;
  final Color? inkColor;
  final Color? hubColor;
  final Color? coinColor;
  final double strokeWidthRatio;
  final Color? furColor;
  final Color? earPinkColor;
  final bool animate;

  const LogoWidget({
    super.key,
    this.size = 36.0,
    this.wheelColor,
    this.sliceColor,
    this.inkColor,
    this.hubColor,
    this.coinColor,
    this.strokeWidthRatio = 3.5,
    this.furColor,
    this.earPinkColor,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final morphDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 480);

    final Widget content;
    if (t.logoStyle == PutarIconStyle.kucing) {
      final hasCustomColors = furColor != null || earPinkColor != null;
      final Widget kucingChild = (hasCustomColors || !animate)
          ? Semantics(
              label: 'Mochi',
              child: CustomPaint(
                size: Size(size, size),
                painter: MochiPainter(
                  expression: MochiExpression.normal,
                  furColor: furColor ?? t.mascotFur,
                  earPinkColor: earPinkColor ?? t.mascotEarPink,
                  blushColor: t.mascotBlush,
                  noseColor: t.mascotNose,
                  bellColor: t.mascotBell,
                  muzzleColor: t.mascotMuzzle,
                  inkColor: inkColor ?? t.ink,
                  highlightColor: t.surface,
                  tearColor: t.accentBlue,
                ),
              ),
            )
          : MochiWidget(size: size, animate: animate);
      content = KeyedSubtree(
        key: ValueKey(
          'logo_kucing_${furColor?.toARGB32()}_${earPinkColor?.toARGB32()}_$animate',
        ),
        child: kucingChild,
      );
    } else {
      content = Semantics(
        key: const ValueKey('logo_pasar_malam'),
        label: 'Logo Putar Jajan',
        child: CustomPaint(
          size: Size(size, size),
          painter: LogoPainter(
            wheelColor: wheelColor ?? t.primary,
            sliceColor: sliceColor ?? t.secondary,
            inkColor: inkColor ?? t.ink,
            hubColor: hubColor ?? t.surface,
            coinColor: coinColor ?? t.ink,
            strokeWidthRatio: strokeWidthRatio,
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: morphDuration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        final scale = Tween<double>(begin: 0.72, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack))
            .animate(animation);
        final turns = Tween<double>(begin: -0.05, end: 0.0).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: RotationTransition(
            turns: turns,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: content,
    );
  }
}
