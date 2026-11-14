import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../painters/logo_painter.dart';
import '../painters/mochi_painter.dart';
import 'putar_theme.dart';
import 'theme_controller.dart';

/// Overlay global untuk menganimasikan perpindahan tema secara ultra-halus:
/// memancarkan gelombang radial pastel/neon dari titik ketuk sambil menampilkan
/// transisi ikon maskot/logo tema tujuan tanpa memblokir interaksi pengguna.
class ThemeTransitionOverlay extends StatelessWidget {
  const ThemeTransitionOverlay({
    super.key,
    required this.child,
    this.signalListenable,
  });

  final Widget child;
  final ValueListenable<ThemeTransitionSignal?>? signalListenable;

  @override
  Widget build(BuildContext context) {
    final explicit = signalListenable;
    if (explicit != null) {
      return _ThemeTransitionOverlayCore(
        signalListenable: explicit,
        child: child,
      );
    }
    return Consumer(
      builder: (context, ref, _) {
        final listenable = ref
            .watch(themeControllerProvider.notifier)
            .transitionSignalListenable;
        return _ThemeTransitionOverlayCore(
          signalListenable: listenable,
          child: child,
        );
      },
    );
  }
}

class _ThemeTransitionOverlayCore extends StatefulWidget {
  const _ThemeTransitionOverlayCore({
    required this.signalListenable,
    required this.child,
  });

  final ValueListenable<ThemeTransitionSignal?> signalListenable;
  final Widget child;

  @override
  State<_ThemeTransitionOverlayCore> createState() =>
      _ThemeTransitionOverlayCoreState();
}

class _ThemeTransitionOverlayCoreState
    extends State<_ThemeTransitionOverlayCore>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 660);

  late final AnimationController _controller;
  ValueListenable<ThemeTransitionSignal?>? _attachedListenable;
  ThemeTransitionSignal? _activeSignal;
  Offset? _localOrigin;
  int _lastHandledSeq = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    )..addStatusListener(_onAnimationStatus);
    _syncListener(widget.signalListenable);
  }

  @override
  void didUpdateWidget(covariant _ThemeTransitionOverlayCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncListener(widget.signalListenable);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if ((status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) &&
        mounted &&
        _activeSignal != null) {
      setState(() {
        _activeSignal = null;
        _localOrigin = null;
      });
    }
  }

  void _syncListener(ValueListenable<ThemeTransitionSignal?> target) {
    if (identical(_attachedListenable, target)) return;
    _attachedListenable?.removeListener(_handleSignal);
    _attachedListenable = target;
    _attachedListenable?.addListener(_handleSignal);
  }

  void _handleSignal() {
    final signal = _attachedListenable?.value;
    if (!mounted || signal == null || signal.seq == _lastHandledSeq) {
      return;
    }
    _lastHandledSeq = signal.seq;

    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller.stop();
      if (_activeSignal != null) {
        setState(() {
          _activeSignal = null;
          _localOrigin = null;
        });
      }
      return;
    }

    Offset? localPoint;
    final globalOrigin = signal.origin;
    if (globalOrigin != null) {
      final renderObj = context.findRenderObject();
      if (renderObj is RenderBox && renderObj.hasSize) {
        localPoint = renderObj.globalToLocal(globalOrigin);
      }
    }

    setState(() {
      _activeSignal = signal;
      _localOrigin = localPoint;
    });
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _attachedListenable?.removeListener(_handleSignal);
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSignal = _activeSignal;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (activeSignal != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value.clamp(0.0, 1.0);
                    return _TransitionVisualLayer(
                      signal: activeSignal,
                      localOrigin: _localOrigin,
                      progress: t,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TransitionVisualLayer extends StatelessWidget {
  const _TransitionVisualLayer({
    required this.signal,
    required this.localOrigin,
    required this.progress,
  });

  final ThemeTransitionSignal signal;
  final Offset? localOrigin;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = progress;
    final toTheme = signal.toTheme;

    // Opacity envelope lembut untuk emblem tengah: muncul cepat lalu pudar halus.
    double badgeAlpha;
    if (t < 0.16) {
      badgeAlpha = Curves.easeOut.transform((t / 0.16).clamp(0.0, 1.0));
    } else if (t < 0.62) {
      badgeAlpha = 1.0;
    } else {
      badgeAlpha =
          1.0 - Curves.easeInCubic.transform(((t - 0.62) / 0.38).clamp(0.0, 1.0));
    }

    // Skala membal lembut lalu menyusut tenang saat memudar.
    final double badgeScale;
    if (t < 0.44) {
      final p = (t / 0.44).clamp(0.0, 1.0);
      badgeScale = 0.68 + Curves.easeOutBack.transform(p) * 0.36;
    } else {
      final p = ((t - 0.44) / 0.56).clamp(0.0, 1.0);
      badgeScale = 1.04 - Curves.easeInOutCubic.transform(p) * 0.12;
    }

    final driftY = 14.0 * (1.0 - Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0))) -
        10.0 * Curves.easeInCubic.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));

    final isKucing = toTheme.logoStyle == PutarIconStyle.kucing;
    final bellSwing = math.sin(t * math.pi * 4) * (1.0 - t) * 0.22;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RadialAuraPainter(
              progress: t,
              toTheme: toTheme,
              origin: localOrigin,
            ),
          ),
        ),
        if (badgeAlpha > 0.01)
          Align(
            alignment: const Alignment(0, -0.1),
            child: Transform.translate(
              offset: Offset(0, driftY),
              child: Transform.scale(
                scale: badgeScale,
                child: Opacity(
                  opacity: badgeAlpha.clamp(0.0, 1.0),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: toTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: toTheme.ink,
                        width: toTheme.borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: toTheme.ink.withValues(alpha: 0.22),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isKucing
                          ? CustomPaint(
                              size: const Size(56, 56),
                              painter: MochiPainter.fromTheme(
                                toTheme,
                                expression: MochiExpression.happy,
                                bellSwingRadians: bellSwing,
                              ),
                            )
                          : CustomPaint(
                              size: const Size(50, 50),
                              painter: LogoPainter(
                                wheelColor: toTheme.primary,
                                sliceColor: toTheme.secondary,
                                inkColor: toTheme.ink,
                                hubColor: toTheme.surface,
                                coinColor: toTheme.ink,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RadialAuraPainter extends CustomPainter {
  _RadialAuraPainter({
    required this.progress,
    required this.toTheme,
    this.origin,
  });

  final double progress;
  final PutarTheme toTheme;
  final Offset? origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = origin ?? Offset(size.width * 0.5, size.height * 0.48);
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    double maxRadius = 0;
    for (final c in corners) {
      maxRadius = math.max(maxRadius, (c - center).distance);
    }

    final eased = Curves.easeOutCubic.transform(progress);
    final auraRadius = math.max(24.0, maxRadius * 1.18 * eased);

    // Intensitas veil memuncak di 34% durasi tepat saat tema ber-interpolasi di titik tengah.
    final double veilPeak = progress < 0.34
        ? Curves.easeOut.transform(progress / 0.34)
        : 1.0 - Curves.easeInOutCubic.transform((progress - 0.34) / 0.66);

    final auraAlpha = (0.30 * veilPeak).clamp(0.0, 0.30);
    if (auraAlpha > 0.005) {
      final auraPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            toTheme.primary.withValues(alpha: auraAlpha),
            toTheme.bg.withValues(alpha: auraAlpha * 0.72),
            toTheme.bg.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: auraRadius));
      canvas.drawCircle(center, auraRadius, auraPaint);
    }

    // Gelombang cincin aksen lembut di tepi depan ripple.
    if (progress < 0.86) {
      final ringFade = 1.0 - Curves.easeOut.transform(progress / 0.86);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 - (progress * 2.0)
        ..color = toTheme.secondary.withValues(alpha: 0.42 * ringFade);
      canvas.drawCircle(center, maxRadius * 1.05 * eased, ringPaint);
    }

    // Partikel kilau ringan mengorbit dari pusat badge tengah.
    final badgeCenter = Offset(size.width * 0.5, size.height * 0.45);
    final sparkleAlpha = (progress < 0.2
            ? progress / 0.2
            : 1.0 - ((progress - 0.2) / 0.8))
        .clamp(0.0, 1.0);
    if (sparkleAlpha > 0.02) {
      const moteCount = 6;
      final orbitBase = 52.0 + 38.0 * eased;
      for (int i = 0; i < moteCount; i++) {
        final angle = (i * (math.pi * 2 / moteCount)) + (eased * 0.45);
        final dist = orbitBase + (i.isEven ? 10.0 : -4.0);
        final pos = badgeCenter +
            Offset(math.cos(angle) * dist, math.sin(angle) * dist);
        final moteColor = i.isEven ? toTheme.primary : toTheme.secondary;
        final motePaint = Paint()
          ..color = moteColor.withValues(alpha: 0.72 * sparkleAlpha);
        canvas.drawCircle(pos, i.isEven ? 4.5 : 3.2, motePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialAuraPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.toTheme.id != toTheme.id ||
        oldDelegate.origin != origin;
  }
}
