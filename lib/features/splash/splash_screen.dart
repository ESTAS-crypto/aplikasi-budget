import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/sound_service.dart';
import '../../core/group/services/group_auth_service.dart';
import '../../data/database_provider.dart';

/// Splash Screen resmi sesuai design/source/Splash.dc.html
/// - Timeline referensi 6000ms dijalankan dalam 3600ms (faktor 0.6)
/// - Background sinar 40 detik linear infinite
/// - 8 irisan roda masuk dari luar lalu berputar tepat ke irisan Mint di jam 12
/// - Suara splash_jingle.wav diputar di frame awal
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Controller sinar latar berputar kontinu 40s (tidak diskalakan 0.6)
  late AnimationController _raysController;

  // Single AnimationController untuk timeline utama 3600ms
  late AnimationController _mainController;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _raysController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    // 1. Mulai putar jingle splash
    try {
      SoundService.instance.play(Sfx.splashJingle, volume: 1.0, haptic: false);
    } catch (_) {}

    // 2. Timer cadangan keras: PASTI pindah layar setelah 3.8 detik bahkan jika ada kendala
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) _checkAndNavigate();
    });

    // 3. Jalankan background initialization secara paralel
    _initializeApp();

    // 4. Jalankan animasi timeline 3600ms lalu navigasi setelah selesai
    _mainController.forward().then((_) {
      if (mounted) _checkAndNavigate();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Inisialisasi audio sound service (pre-decode)
      await SoundService.instance.initialize();

      // Inisialisasi database Drift & default pools
      final db = ref.read(databaseProvider);
      await db.customSelect('SELECT 1').get();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    try {
      SharedPreferences? prefs;
      try {
        prefs = ref.read(sharedPreferencesProvider);
      } catch (_) {
        prefs = await SharedPreferences.getInstance();
      }
      final hasCompletedOnboarding = (prefs?.getBool('has_seen_onboarding') ?? false) ||
          (prefs?.getBool('has_completed_onboarding') ?? false);

      if (!mounted) return;
      try {
        if (!hasCompletedOnboarding) {
          context.go('/onboarding');
        } else {
          context.go('/');
        }
      } catch (_) {
        // Fallback jika dijalankan di context tanpa GoRouter (misal widget test)
      }
    } catch (_) {
      if (mounted) {
        try {
          context.go('/');
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _raysController.dispose();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations && _mainController.value < 1.0) {
      _mainController.value = 1.0;
      Future.delayed(const Duration(milliseconds: 600), _checkAndNavigate);
    }

    return Scaffold(
      backgroundColor: AppColors.matahari, // #FFD23F
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Sinar latar berputar kontinu 40s (1200x1200)
          Center(
            child: AnimatedBuilder(
              animation: _raysController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _raysController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(1200, 1200),
                  painter: const _RaysPainter(),
                ),
              ),
            ),
          ),

          // 2. Timeline visual utama (Roda, lampu, irisan, pointer, partikel, teks, bar)
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              final t = _mainController.value; // progress 0.0 sampai 1.0

              return Stack(
                children: [
                  // 10 Lingkaran Meletup (54% - 76%)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BurstingCirclesPainter(progress: t),
                    ),
                  ),

                  // Area Roda Tengah (300x300)
                  Align(
                    alignment: const Alignment(0, -0.32),
                    child: _buildWheelSection(t),
                  ),

                  // Wordmark "putar jajan" & Pill Tagline "Putar. Terima. Jajan."
                  Align(
                    alignment: const Alignment(0, 0.38),
                    child: _buildWordmarkAndTagline(t),
                  ),

                  // Loading Bar di bagian bawah
                  Align(
                    alignment: const Alignment(0, 0.82),
                    child: _buildLoadingBar(t),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWheelSection(double t) {
    // Animasi scale & fade roda wrapper: 0 - 16% (cubic-bezier(.2, 1.2, .3, 1))
    double wheelScale = 1.0;
    double wheelOpacity = 1.0;
    if (t < 0.16) {
      final prog = const Cubic(0.2, 1.2, 0.3, 1.0).transform(t / 0.16);
      wheelScale = 0.4 + (0.6 * prog);
      wheelOpacity = prog.clamp(0.0, 1.0);
    }

    return Transform.scale(
      scale: wheelScale,
      child: Opacity(
        opacity: wheelOpacity,
        child: SizedBox(
          width: 300,
          height: 300,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SplashWheelPainter(progress: t),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordmarkAndTagline(double t) {
    // Animasi naik 26px & fade (56% - 70%)
    double textProg = 0.0;
    if (t >= 0.56) {
      textProg = const Cubic(0.2, 1.2, 0.3, 1.0)
          .transform(((t - 0.56) / 0.14).clamp(0.0, 1.0));
    }

    // Tagline tertunda 120ms (di 6000ms = 0.02)
    double tagProg = 0.0;
    if (t >= 0.58) {
      tagProg = const Cubic(0.2, 1.2, 0.3, 1.0)
          .transform(((t - 0.58) / 0.14).clamp(0.0, 1.0));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wordmark
        Transform.translate(
          offset: Offset(0, 26 * (1.0 - textProg)),
          child: Opacity(
            opacity: textProg.clamp(0.0, 1.0),
            child: Text(
              'putar jajan',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 54,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                shadows: const [
                  Shadow(
                    offset: Offset(3, 3),
                    color: AppColors.cream,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Pill Tagline
        Transform.translate(
          offset: Offset(0, 26 * (1.0 - tagProg)),
          child: Opacity(
            opacity: tagProg.clamp(0.0, 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                'Putar. Terima. Jajan.',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingBar(double t) {
    // Progress loading bar terisi 0% sampai 85%+ pada 0 sampai 85% timeline
    final barFill = (t / 0.85).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Menyiapkan roda...',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.ink, width: 3),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: barFill,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.mint,
                border: Border(
                  right: BorderSide(color: AppColors.ink, width: 3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter untuk Sinar Bergantian #FFD23F dan #FFDE66 tiap 7.5 derajat
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const rayAngle = 7.5 * math.pi / 180;

    final paint1 = Paint()
      ..color = const Color(0xFFFFD23F)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = const Color(0xFFFFDE66)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 48; i++) {
      final startAngle = i * rayAngle;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          rayAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, i.isEven ? paint1 : paint2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter untuk 10 Lingkaran Meletup (viewBox burst keluar 190 unit)
class _BurstingCirclesPainter extends CustomPainter {
  final double progress;

  _BurstingCirclesPainter({required this.progress});

  // Koordinat offset (bx, by) dan warna dari Splash.dc.html
  static const List<Offset> _offsets = [
    Offset(187, 33),
    Offset(132, 137),
    Offset(26, 188),
    Offset(-89, 168),
    Offset(-171, 83),
    Offset(-187, -33),
    Offset(-132, -137),
    Offset(-26, -188),
    Offset(89, -168),
    Offset(171, -83),
  ];

  static const List<Color> _colors = [
    Color(0xFFFF6B5A), // Tomat
    Color(0xFFFF9F1C), // Jeruk
    Color(0xFFFFD23F), // Matahari
    Color(0xFF3DDBB0), // Mint
    Color(0xFF6FB1FF), // Langit
    Color(0xFFB8A4FF), // Lavender
    Color(0xFFFF8FC0), // Permen
    Color(0xFFB8E986), // Lemon
    Color(0xFFFF6B5A), // Tomat
    Color(0xFFFF9F1C), // Jeruk
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.54) return;

    // Meletup dari 54% sampai 76% (cubic-bezier(.1,.8,.3,1))
    final burstT = ((progress - 0.54) / 0.22).clamp(0.0, 1.0);
    final curveVal = const Cubic(0.1, 0.8, 0.3, 1.0).transform(burstT);

    double opacity = 1.0;
    if (progress >= 0.58) {
      opacity = (1.0 - ((progress - 0.58) / 0.18)).clamp(0.0, 1.0);
    }

    final center = Offset(size.width / 2, size.height * 0.34);
    final strokePaint = Paint()
      ..color = AppColors.ink.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < 10; i++) {
      final target = _offsets[i];
      final currentPos = Offset(
        center.dx + (target.dx * curveVal),
        center.dy + (target.dy * curveVal),
      );

      final fillPaint = Paint()
        ..color = _colors[i].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      const r = 12.0; // diameter 24
      canvas.drawCircle(currentPos, r, fillPaint);
      canvas.drawCircle(currentPos, r, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstingCirclesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Painter utama roda splash: bingkai, 16 lampu berkedip, 8 irisan, mint pop-out, hub, pointer
class _SplashWheelPainter extends CustomPainter {
  final double progress;

  _SplashWheelPainter({required this.progress});

  static const double wheelCenter = 150.0;
  static const double rimRadius = 130.0;
  static const double sliceRadius = 98.0;

  // 8 Warna irisan
  static const List<Color> sliceColors = [
    Color(0xFFFF6B5A), // 0: Tomat
    Color(0xFFFF9F1C), // 1: Jeruk
    Color(0xFFFFD23F), // 2: Matahari
    Color(0xFF3DDBB0), // 3: Mint
    Color(0xFF6FB1FF), // 4: Langit
    Color(0xFFB8A4FF), // 5: Lavender
    Color(0xFFFF8FC0), // 6: Permen
    Color(0xFFB8E986), // 7: Lemon
  ];

  // Offset masuk tiap irisan (dx, dy) dari Splash.dc.html
  static const List<Offset> sliceEntryOffsets = [
    Offset(65, -157),
    Offset(157, -65),
    Offset(157, 65),
    Offset(65, 157),
    Offset(-65, 157),
    Offset(-157, 65),
    Offset(-157, -65),
    Offset(-65, -157),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.fill;

    final rimPaint = Paint()
      ..color = AppColors.cream
      ..style = PaintingStyle.fill;

    // 1. Bingkai Roda: hard shadow (7,7) lalu krim lingkaran r130
    canvas.drawCircle(const Offset(157, 157), rimRadius, shadowPaint);
    canvas.drawCircle(const Offset(150, 150), rimRadius, rimPaint);
    canvas.drawCircle(const Offset(150, 150), rimRadius, strokePaint);

    // 2. 16 Lampu di radius 114: fade in 18% - 28%, blink periode 600ms (360ms di 3600ms)
    _paintBulbs(canvas, progress);

    // 3. Putaran Roda (0 ke 922.5° pada 10% - 54%)
    double wheelAngle = 0.0;
    if (progress >= 0.10) {
      final spinT = ((progress - 0.10) / 0.44).clamp(0.0, 1.0);
      final spinCurve = const Cubic(0.15, 0.7, 0.1, 1.0).transform(spinT);
      wheelAngle = spinCurve * (922.5 * math.pi / 180);
    }

    canvas.save();
    canvas.translate(wheelCenter, wheelCenter);
    canvas.rotate(wheelAngle);
    canvas.translate(-wheelCenter, -wheelCenter);

    // 4. Gambar 8 Irisan Roda
    _paintSlices(canvas, progress, strokePaint);

    // Lingkaran luar irisan r98
    canvas.drawCircle(const Offset(wheelCenter, wheelCenter), sliceRadius, strokePaint);

    canvas.restore(); // pulihkan rotasi wheel

    // 5. Hub tengah: lingkaran r19 putih border 4 ink, lingkaran koin tengah r5 ink
    final hubFill = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    final hubInnerFill = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(150, 150), 19, hubFill);
    canvas.drawCircle(const Offset(150, 150), 19, strokePaint);
    canvas.drawCircle(const Offset(150, 150), 5, hubInnerFill);

    // 6. Pointer Tomat di atas (jam 12): jatuh mantul pada 38% - 53%
    _paintPointer(canvas, progress, strokePaint);
  }

  void _paintBulbs(Canvas canvas, double progress) {
    if (progress < 0.18) return;

    double bulbOpacity = 1.0;
    if (progress < 0.28) {
      bulbOpacity = (progress - 0.18) / 0.10;
    }

    // Blink period = 360ms pada 3600ms timeline (setara 600ms pada 6000ms)
    final elapsedMs = progress * 3600;
    final blinkPhase = (elapsedMs % 360) / 360;

    final bulbPaintTomat = Paint()
      ..color = AppColors.tomat.withValues(alpha: bulbOpacity)
      ..style = PaintingStyle.fill;

    final bulbPaintCream = Paint()
      ..color = AppColors.cream.withValues(alpha: bulbOpacity)
      ..style = PaintingStyle.fill;

    const bulbRadius = 114.0;
    const bulbR = 5.5;

    for (int i = 0; i < 16; i++) {
      final angle = i * (2 * math.pi / 16);
      final cx = wheelCenter + bulbRadius * math.cos(angle);
      final cy = wheelCenter + bulbRadius * math.sin(angle);

      // Genap dan ganjil bergeser setengah periode (180ms)
      final isEven = i.isEven;
      final isTomatPhase = isEven ? (blinkPhase < 0.5) : (blinkPhase >= 0.5);

      canvas.drawCircle(
        Offset(cx, cy),
        bulbR,
        isTomatPhase ? bulbPaintTomat : bulbPaintCream,
      );
    }
  }

  void _paintSlices(Canvas canvas, double progress, Paint strokePaint) {
    const sweepAngle = 45.0 * math.pi / 180;

    for (int i = 0; i < 8; i++) {
      // Jeda 70ms per irisan (di 6000ms = 70/6000 = 0.011667)
      final startDelay = i * (70.0 / 6000.0);
      final sliceT = ((progress - startDelay) / 0.20).clamp(0.0, 1.0);
      final entryCurve = const Cubic(0.2, 1.0, 0.3, 1.0).transform(sliceT);

      // Offset masuk, rotasi 120° ke 0°, scale 0.2 ke 1.0
      final entryOffset = sliceEntryOffsets[i];
      final currentDx = entryOffset.dx * (1.0 - entryCurve);
      final currentDy = entryOffset.dy * (1.0 - entryCurve);
      final currentRot = (120.0 * math.pi / 180) * (1.0 - entryCurve);
      final currentScale = 0.2 + (0.8 * entryCurve);
      final currentOpacity = entryCurve.clamp(0.0, 1.0);

      final startAngle = (-90.0 + (i * 45.0)) * math.pi / 180;

      canvas.save();
      canvas.translate(wheelCenter + currentDx, wheelCenter + currentDy);
      canvas.rotate(currentRot);
      canvas.scale(currentScale, currentScale);
      canvas.translate(-wheelCenter, -wheelCenter);

      // Pergeseran khusus untuk irisan Mint (indeks 3) saat pop-out (56% - 92%)
      if (i == 3) {
        double popFactor = 0.0;
        if (progress >= 0.56 && progress < 0.63) {
          final tPop = (progress - 0.56) / 0.07;
          popFactor = 1.5 * const Cubic(0.2, 1.4, 0.3, 1.0).transform(tPop);
        } else if (progress >= 0.63 && progress < 0.70) {
          final tPop = (progress - 0.63) / 0.07;
          popFactor = 1.5 - (0.5 * tPop); // mendarat ke 1.0x
        } else if (progress >= 0.70 && progress <= 0.92) {
          popFactor = 1.0;
        }

        // 14 unit outward pada sudut irisan Mint (5.4, 12.9)
        canvas.translate(5.4 * popFactor, 12.9 * popFactor);
      }

      final sliceFill = Paint()
        ..color = sliceColors[i].withValues(alpha: currentOpacity)
        ..style = PaintingStyle.fill;

      final slicePath = Path()
        ..moveTo(wheelCenter, wheelCenter)
        ..arcTo(
          const Rect.fromLTWH(150 - 98, 150 - 98, 196, 196),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(slicePath, sliceFill);
      canvas.drawPath(slicePath, strokePaint);

      // Koin ink r7 pada irisan Mint
      if (i == 3) {
        final coinFill = Paint()
          ..color = AppColors.ink.withValues(alpha: currentOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(173.7, 207.3), 7.0, coinFill);
      }

      canvas.restore();
    }
  }

  void _paintPointer(Canvas canvas, double progress, Paint strokePaint) {
    if (progress < 0.38) return;

    // Pointer jatuh dan mantul pada 38% - 53%
    double pointerY = 0.0;
    double pointerOpacity = 1.0;

    if (progress < 0.47) {
      final tDown = (progress - 0.38) / 0.09;
      final curveDown = const Cubic(0.3, 1.4, 0.4, 1.0).transform(tDown);
      pointerY = -90.0 + (97.0 * curveDown); // -90px ke +7px
      pointerOpacity = tDown.clamp(0.0, 1.0);
    } else if (progress < 0.53) {
      final tBounce = (progress - 0.47) / 0.06;
      pointerY = 7.0 - (7.0 * tBounce); // 7px kembali ke 0
    }

    canvas.save();
    canvas.translate(0, pointerY);

    final pointerFill = Paint()
      ..color = AppColors.tomat.withValues(alpha: pointerOpacity)
      ..style = PaintingStyle.fill;

    final pointerStroke = Paint()
      ..color = AppColors.ink.withValues(alpha: pointerOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Path pointer: M150 44 L134 14 Q150 0 166 14 Z
    final pointerPath = Path()
      ..moveTo(150, 44)
      ..lineTo(134, 14)
      ..quadraticBezierTo(150, 0, 166, 14)
      ..close();

    canvas.drawPath(pointerPath, pointerFill);
    canvas.drawPath(pointerPath, pointerStroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashWheelPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
