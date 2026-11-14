import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/games/game_engine.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/theme/putar_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/pop_reveal.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_card.dart';
import '../../data/database_provider.dart';
import '../../data/game_pool_repository.dart';
import '../notifications/notification_service.dart';

/// Layar 15: Lempar Koin
/// Sesuai design/source/Koin.dc.html dan design/screens/15_lempar_koin.png
class CoinScreen extends ConsumerStatefulWidget {
  const CoinScreen({super.key});

  @override
  ConsumerState<CoinScreen> createState() => _CoinScreenState();
}

class _CoinScreenState extends ConsumerState<CoinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  int _baseAmount = 50000;
  int _currentAmount = 50000;
  int _currentFlipIndex = 0; // 0, 1, 2
  bool _isFlipping = false;
  bool _hasStarted = false;
  bool _isFinished = false;

  late GameOutcome _gameOutcome;
  late List<CoinFlipStep> _precalculatedSteps;

  bool _hasPlayedLandSound = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _flipController.addListener(() {
      if (_isFlipping) {
        final t = _flipController.value;
        // Koin mendarat dan mantul di t = 0.62
        if (t >= 0.62 && !_hasPlayedLandSound) {
          _hasPlayedLandSound = true;
          SoundService.instance.play(Sfx.coinLand);
        }
      }
    });

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final repo = ref.read(gamePoolRepositoryProvider);
    final base = await repo.getCoinBaseAmount();
    if (mounted) {
      setState(() {
        _baseAmount = base;
        _currentAmount = base;
      });
      _generateDeterministicGame();
    }
  }

  void _generateDeterministicGame() {
    final engine = CoinGameEngine(baseAmount: _baseAmount);
    _gameOutcome = engine.play();
    final rawSteps = _gameOutcome.animationParameters['steps'] as List;
    _precalculatedSteps = rawSteps
        .map((s) => s is CoinFlipStep ? s : CoinFlipStep.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCoin() {
    if (_isFlipping || _isFinished) return;

    _hasPlayedLandSound = false;

    // Suara koin dilempar melayang ke atas
    SoundService.instance.play(Sfx.coinFlip);

    setState(() {
      _isFlipping = true;
      _hasStarted = true;
    });

    final currentStep = _precalculatedSteps[_currentFlipIndex];

    _flipController.forward(from: 0.0).then((_) {
      if (mounted) {
        // Mainkan efek audio hasil lemparan (Gambar x2 atau Angka setengah)
        if (currentStep.side == CoinSide.gambar) {
          SoundService.instance.play(Sfx.coinDouble);
        } else {
          SoundService.instance.play(Sfx.coinHalve);
        }

        setState(() {
          _isFlipping = false;
          _currentAmount = currentStep.afterAmount;
          _currentFlipIndex++;

          // Jika sudah mencapai 3 lemparan, otomatis selesai
          if (_currentFlipIndex >= 3) {
            _isFinished = true;
            SoundService.instance.play(Sfx.winLolos, volume: 0.85);
          }
        });

        SemanticsService.sendAnnouncement(
          View.of(context),
          '${currentStep.side == CoinSide.gambar ? "Gambar" : "Angka"}! Budget sekarang ${RupiahFormatter.format(_currentAmount)}',
          TextDirection.ltr,
        );
      }
    });
  }

  void _takeBudget() {
    if (_isFlipping) return;
    SoundService.instance.play(Sfx.uiTap);
    setState(() {
      _isFinished = true;
    });
    SoundService.instance.play(Sfx.winLolos);
  }

  Future<void> _startActiveDate(int budget) async {
    final db = ref.read(databaseProvider);
    final currentActive = await db.getActiveDate();

    if (currentActive != null && mounted) {
      final t = context.putarTheme;
      SoundService.instance.play(Sfx.uiTap);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.cardRadius),
            side: BorderSide(color: t.ink, width: t.borderWidth),
          ),
          title: Text(
            'Date Masih Aktif!',
            style: TextStyle(
              fontWeight: t.weightExtraBold,
              color: t.ink,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Kamu masih memiliki date yang aktif dengan budget ${RupiahFormatter.format(currentActive.budget)}.\n\nSelesaikan date yang sedang aktif di menu Catatan terlebih dahulu sebelum memulai sesi baru.',
            style: TextStyle(
              color: t.ink,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Tutup',
                style: TextStyle(
                  color: t.textDisabled,
                  fontWeight: t.weightBold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.secondary,
                foregroundColor: t.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: t.ink, width: 2),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/catatan');
              },
              child: Text(
                'Buka Catatan',
                style: TextStyle(fontWeight: t.weightExtraBold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    await db.createDate(budget);

    try {
      await NotificationService.instance.showOngoingDateNotification(
        remainingBudget: budget,
        spentAmount: 0,
        totalBudget: budget,
      );
    } catch (_) {}

    if (mounted) {
      context.go('/catatan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.putarTheme;
    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final activeDate = activeDateAsync.value;

    final lastStepIndex = (_currentFlipIndex - 1).clamp(0, 2);
    final currentStep = _hasStarted ? _precalculatedSteps[lastStepIndex] : null;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header dengan tombol kembali & Judul
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.uiTap);
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.ink, width: theme.borderWidth),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor,
                            offset: theme.smallShadowOffset,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(
                          painter: CustomBackIconPainter(
                            color: theme.ink,
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Lempar Koin',
                      style: theme.displayMedium.copyWith(
                        fontSize: 24,
                        fontWeight: theme.weightExtraBold,
                        color: theme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Banner jika ada date aktif
              if (activeDate != null) ...[
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    context.go('/catatan');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.secondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.ink, width: theme.subtleBorderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor,
                          offset: const Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: theme.ink,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Date aktif: ${RupiahFormatter.format(activeDate.budget)} · Buka Catatan',
                            style: theme.bodySmall.copyWith(
                              fontWeight: theme.weightExtraBold,
                              color: theme.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Tag pill: Gambar x2 · Angka setengah
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.secondary,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: theme.ink, width: theme.borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor,
                        offset: theme.smallShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Gambar x2 · Angka setengah',
                    style: theme.bodySmall.copyWith(
                      fontWeight: theme.weightExtraBold,
                      color: theme.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Arena Koin (300px tinggi, perspective 700)
              Container(
                height: 280,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.accentWarmSoft,
                  borderRadius: BorderRadius.circular(theme.cardRadius),
                  border: Border.all(color: theme.ink, width: theme.borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor,
                      offset: theme.standardShadowOffset,
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bayangan elips di lantai yang mengecil saat koin melambung tinggi
                    Positioned(
                      bottom: 30,
                      child: AnimatedBuilder(
                        animation: _flipController,
                        builder: (context, _) {
                          final t = _flipController.value;
                          double scale = 1.0;
                          double opacity = 0.28;

                          if (_isFlipping) {
                            if (t < 0.40) {
                              final p = t / 0.40;
                              scale = 1.0 - (0.5 * math.sin(p * math.pi));
                              opacity = 0.28 - (0.16 * math.sin(p * math.pi));
                            } else if (t < 0.62) {
                              final p = (t - 0.40) / 0.22;
                              scale = 0.5 + (0.5 * p);
                              opacity = 0.12 + (0.16 * p);
                            }
                          }

                          return Transform.scale(
                            scaleX: scale,
                            scaleY: scale * 0.8,
                            child: Container(
                              width: 130,
                              height: 16,
                              decoration: BoxDecoration(
                                color: theme.ink.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Koin 3D dengan rotasi sumbu Y dan perspective 700
                    Positioned(
                      bottom: 45,
                      child: AnimatedBuilder(
                        animation: _flipController,
                        builder: (context, _) {
                          final t = _flipController.value;

                          double translateY = 0.0;
                          double rotY = 0.0;
                          double scale = 1.0;

                          if (_isFlipping) {
                            final targetSide = _precalculatedSteps[_currentFlipIndex].side;
                            final targetTurns = (targetSide == CoinSide.gambar) ? 5.0 : 5.5;

                            if (t < 0.40) {
                              // Melambung ke atas: translateY -130, scale 1.12, rotasi berputar
                              final p = t / 0.40;
                              final easeP = Curves.easeOutCubic.transform(p);
                              translateY = -130.0 * easeP;
                              scale = 1.0 + (0.12 * easeP);
                              rotY = (targetTurns * 2 * math.pi) * (p * 0.5);
                            } else if (t < 0.62) {
                              // Jatuh kembali ke lantai
                              final p = (t - 0.40) / 0.22;
                              final easeP = Curves.easeInQuad.transform(p);
                              translateY = -130.0 * (1.0 - easeP);
                              scale = 1.12 - (0.12 * easeP);
                              rotY = (targetTurns * 2 * math.pi) * (0.5 + 0.5 * p);
                            } else if (t < 0.66) {
                              // Pantulan kecil: translateY -22
                              final p = (t - 0.62) / 0.04;
                              translateY = -22.0 * math.sin(p * math.pi);
                              rotY = targetTurns * 2 * math.pi;
                            } else {
                              translateY = 0.0;
                              rotY = targetTurns * 2 * math.pi;
                            }
                          } else {
                            final showSide = currentStep?.side ?? CoinSide.gambar;
                            rotY = (showSide == CoinSide.gambar) ? 0.0 : math.pi;
                          }

                          final transform = Matrix4.identity()
                            ..setEntry(3, 2, 0.0015) // perspective 700
                            ..multiply(Matrix4.translationValues(0.0, translateY, 0.0))
                            ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0))
                            ..rotateY(rotY);

                          final isShowingFront = (math.cos(rotY) >= 0);

                          return Transform(
                            transform: transform,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: isShowingFront
                                  ? const _CoinFaceGambar()
                                  : const _CoinFaceAngka(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Indikator 3 bulatan lemparan
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lemparan ${_currentFlipIndex.clamp(1, 3)} dari 3',
                        style: theme.bodySmall.copyWith(
                          fontWeight: theme.weightExtraBold,
                          color: theme.ink,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ...List.generate(3, (index) {
                        final isUsed = index < _currentFlipIndex;
                        return Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isUsed ? theme.success : theme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.ink, width: theme.subtleBorderWidth),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor,
                                offset: const Offset(1.5, 1.5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Kartu Hasil Pop Reveal
              if (_hasStarted && !_isFlipping) ...[
                PopReveal(
                  child: Center(
                    child: StickerCard(
                      backgroundColor: theme.surface,
                      borderRadius: theme.cardRadius,
                      borderWidth: theme.borderWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentStep!.side == CoinSide.gambar
                                ? 'Gambar! ${RupiahFormatter.format(currentStep.beforeAmount)} jadi'
                                : 'Angka! ${RupiahFormatter.format(currentStep.beforeAmount)} jadi',
                            style: theme.bodySmall.copyWith(
                              fontWeight: theme.weightBold,
                              color: theme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            RupiahFormatter.format(_currentAmount),
                            style: theme.displayLarge.copyWith(
                              fontSize: 32,
                              fontWeight: theme.weightExtraBold,
                              color: theme.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 5. Tombol Aksi
              if (!_hasStarted) ...[
                StickerButton.large(
                  text: 'LEMPAR KOIN',
                  backgroundColor: theme.primary,
                  autoPulse: true,
                  onPressed: _flipCoin,
                ),
              ] else if (!_isFinished) ...[
                Row(
                  children: [
                    Expanded(
                      child: StickerButton(
                        height: 56,
                        borderRadius: 28,
                        backgroundColor: theme.primary,
                        text: 'LEMPAR LAGI',
                        textColor: theme.ink,
                        onPressed: _isFlipping ? null : _flipCoin,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StickerButton(
                        height: 56,
                        borderRadius: 28,
                        backgroundColor: theme.success,
                        text: 'AMBIL',
                        textColor: theme.ink,
                        onPressed: _isFlipping ? null : _takeBudget,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                StickerButton.large(
                  text: 'PAKAI BUDGET INI',
                  backgroundColor: theme.success,
                  onPressed: () => _startActiveDate(_currentAmount),
                ),
                const SizedBox(height: 10),
                StickerButton(
                  height: 48,
                  borderRadius: 24,
                  backgroundColor: theme.surface,
                  text: 'Main Ulang',
                  textColor: theme.ink,
                  onPressed: () {
                    SoundService.instance.play(Sfx.uiTap);
                    setState(() {
                      _hasStarted = false;
                      _isFinished = false;
                      _currentFlipIndex = 0;
                      _currentAmount = _baseAmount;
                    });
                    _generateDeterministicGame();
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sisi Gambar Koin (#FFD23F) dengan logo vektor Putar Jajan
class _CoinFaceGambar extends StatelessWidget {
  const _CoinFaceGambar();

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: t.ink, width: 4.5),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.smallShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: CustomPaint(
                painter: _CoinLogoPainter(theme: t),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'GAMBAR',
              style: t.chipLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: t.weightExtraBold,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sisi Angka Koin (#FF9F1C Jeruk) dengan simbol '½' besar
class _CoinFaceAngka extends StatelessWidget {
  const _CoinFaceAngka();

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.accentOrange,
        shape: BoxShape.circle,
        border: Border.all(color: t.ink, width: 4.5),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.smallShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '½',
              style: t.displayLarge.copyWith(
                fontSize: 58,
                fontWeight: t.weightExtraBold,
                color: t.ink,
                height: 1.0,
              ),
            ),
            Text(
              'ANGKA',
              style: t.chipLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: t.weightExtraBold,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter untuk Logo Roda Koin
class _CoinLogoPainter extends CustomPainter {
  final PutarTheme theme;

  const _CoinLogoPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    final borderPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final tomatPaint = Paint()
      ..color = theme.primary
      ..style = PaintingStyle.fill;

    final mintPaint = Paint()
      ..color = theme.success
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Irisan Tomat
    canvas.drawArc(rect, -math.pi / 2, math.pi, true, tomatPaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi, true, borderPaint);

    // Irisan Mint
    canvas.drawArc(rect, math.pi / 2, math.pi, true, mintPaint);
    canvas.drawArc(rect, math.pi / 2, math.pi, true, borderPaint);

    // Lingkaran pusat putih
    final centerPaint = Paint()
      ..color = theme.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.28, centerPaint);
    canvas.drawCircle(center, radius * 0.28, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CoinLogoPainter oldDelegate) => oldDelegate.theme != theme;
}
