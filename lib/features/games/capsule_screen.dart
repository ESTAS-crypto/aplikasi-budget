import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/games/game_engine.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/pop_reveal.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_card.dart';
import '../../data/database_provider.dart';
import '../../data/game_pool_repository.dart';
import '../notifications/notification_service.dart';

class _CapsulePos {
  final double left;
  final double top;
  final Color color;
  final double delay;

  const _CapsulePos({
    required this.left,
    required this.top,
    required this.color,
    required this.delay,
  });
}

/// 9 Posisi & Warna Kapsul Statis di dalam Kubah sesuai Kapsul.dc.html
const List<_CapsulePos> _kDefaultDomeCapsules = [
  _CapsulePos(left: 28, top: 130, color: AppColors.tomat, delay: 0.0),
  _CapsulePos(left: 70, top: 140, color: AppColors.jeruk, delay: 0.1),
  _CapsulePos(left: 114, top: 126, color: AppColors.matahari, delay: 0.2),
  _CapsulePos(left: 150, top: 138, color: AppColors.mint, delay: 0.3),
  _CapsulePos(left: 46, top: 92, color: AppColors.langit, delay: 0.4),
  _CapsulePos(left: 92, top: 98, color: AppColors.lavender, delay: 0.0),
  _CapsulePos(left: 136, top: 88, color: AppColors.permen, delay: 0.1),
  _CapsulePos(left: 64, top: 52, color: AppColors.lemon, delay: 0.2),
  _CapsulePos(left: 110, top: 56, color: AppColors.tomat, delay: 0.3),
];

/// Layar 13: Gacha Kapsul
/// Sesuai design/source/Kapsul.dc.html
class CapsuleScreen extends ConsumerStatefulWidget {
  const CapsuleScreen({super.key});

  @override
  ConsumerState<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends ConsumerState<CapsuleScreen>
    with TickerProviderStateMixin {
  late AnimationController _crankController;
  late Animation<double> _crankCurve;
  late AnimationController _dropController;
  late AnimationController _jiggleController;

  bool _isCranking = false;
  bool _hasPlayedDropSound = false;
  bool _hasPlayedOpenSound = false;
  int? _wonAmount;
  Color _wonColor = AppColors.lavender;
  List<int> _currentPool = GamePoolRepository.defaultCapsulePool;

  @override
  void initState() {
    super.initState();
    // Animasi putaran knob 540 derajat dengan cubic-bezier(.4, 0, .2, 1)
    _crankController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _crankCurve = CurvedAnimation(
      parent: _crankController,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
    );

    // Animasi jatuh kapsul: dari -70 ke slot, mantul, lalu membesar 1.8x
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Sinkronisasi audio kapsul presisi milidetik dengan visual timeline
    _dropController.addListener(() {
      if (_isCranking) {
        final t = _dropController.value;
        // Kapsul membentur piringan dispenser tepat di t = 0.54 (titik kontak 10px)
        if (t >= 0.54 && !_hasPlayedDropSound) {
          _hasPlayedDropSound = true;
          SoundService.instance.play(Sfx.capsuleDrop);
          HapticFeedback.mediumImpact();
        }
        // Kapsul meletup terbuka membesar di t = 0.76 (scale 1.8x)
        if (t >= 0.76 && !_hasPlayedOpenSound) {
          _hasPlayedOpenSound = true;
          SoundService.instance.play(Sfx.capsuleOpen);
          HapticFeedback.heavyImpact();
        }
      }
    });

    // Animasi jiggle mengambang pelan kapsul di kubah (0.8s infinite)
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _loadPool();
  }

  /// Menghitung offset jiggle berdasarkan @keyframes jg dari Kapsul.dc.html
  /// 0%,100% -> (0,0); 25% -> (5,-8); 50% -> (-5,4); 75% -> (4,6)
  Offset _calcJiggle(double t, double delay) {
    final progress = (t + delay) % 1.0;
    if (progress < 0.25) {
      final u = (1 - math.cos(progress / 0.25 * math.pi)) / 2;
      return Offset(5.0 * u, -8.0 * u);
    } else if (progress < 0.50) {
      final u = (1 - math.cos((progress - 0.25) / 0.25 * math.pi)) / 2;
      return Offset(5.0 + (-5.0 - 5.0) * u, -8.0 + (4.0 - (-8.0)) * u);
    } else if (progress < 0.75) {
      final u = (1 - math.cos((progress - 0.50) / 0.25 * math.pi)) / 2;
      return Offset(-5.0 + (4.0 - (-5.0)) * u, 4.0 + (6.0 - 4.0) * u);
    } else {
      final u = (1 - math.cos((progress - 0.75) / 0.25 * math.pi)) / 2;
      return Offset(4.0 * (1 - u), 6.0 * (1 - u));
    }
  }

  Future<void> _loadPool() async {
    final repo = ref.read(gamePoolRepositoryProvider);
    final db = ref.read(databaseProvider);
    final pool = await repo.getPool(GameType.capsule, db);
    if (mounted) {
      setState(() {
        _currentPool = pool;
      });
    }
  }

  @override
  void dispose() {
    _crankController.dispose();
    _dropController.dispose();
    _jiggleController.dispose();
    super.dispose();
  }

  void _triggerGacha() {
    if (_isCranking || _currentPool.isEmpty) return;

    // Reset flag sinkronisasi audio untuk setiap putaran
    _hasPlayedDropSound = false;
    _hasPlayedOpenSound = false;

    // Suara putaran tuas gerigi mekanik (tanpa uiTap agar suara tunggal dan jernih)
    SoundService.instance.play(Sfx.capsuleCrank);

    final engine = CapsuleGameEngine(pool: _currentPool);
    final outcome = engine.play();
    final colorHex = (outcome.animationParameters['capsuleColor'] as String?) ?? '#3DDBB0';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    setState(() {
      _isCranking = true;
      _wonAmount = null;
      _wonColor = color;
    });

    _crankController.forward(from: 0.0).then((_) {
      if (!mounted) return;

      _dropController.forward(from: 0.0).then((_) {
        if (!mounted) return;

        setState(() {
          _isCranking = false;
          _wonAmount = outcome.wonAmount;
        });

        // Suara kemenangan saat kartu nominal muncul
        SoundService.instance.play(Sfx.winLolos, volume: 0.85);

        // Bacakan untuk TalkBack / Aksesibilitas
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Budget kamu ${RupiahFormatter.format(outcome.wonAmount)}',
          TextDirection.ltr,
        );
      });
    });
  }

  Future<void> _startActiveDate(int budget) async {
    final db = ref.read(databaseProvider);
    final currentActive = await db.getActiveDate();

    if (currentActive != null && mounted) {
      SoundService.instance.play(Sfx.uiTap);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.ink, width: 3),
          ),
          title: const Text(
            'Date Masih Aktif!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Kamu masih memiliki date yang aktif dengan budget ${RupiahFormatter.format(currentActive.budget)}.\n\nSelesaikan date yang sedang aktif di menu Catatan terlebih dahulu sebelum memulai sesi baru.',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: AppColors.disabled,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.matahari,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/catatan');
              },
              child: const Text(
                'Buka Catatan',
                style: TextStyle(fontWeight: FontWeight.w800),
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
    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final activeDate = activeDateAsync.value;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
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
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(
                          painter: CustomBackIconPainter(
                            color: AppColors.ink,
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Gacha Kapsul',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  // Tombol Atur Isi Pool
                  GestureDetector(
                    onTap: () async {
                      SoundService.instance.play(Sfx.uiTap);
                      await context.push('/custom-wheel?game=capsule');
                      _loadPool();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.matahari,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CustomPaint(
                              painter: CustomSettingsIconPainter(
                                color: AppColors.ink,
                                strokeWidth: 2.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Atur Isi',
                            style: AppTypography.chipLabel.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
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
                      color: AppColors.matahari,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: AppColors.ink,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Date aktif: ${RupiahFormatter.format(activeDate.budget)} · Buka Catatan',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Tag Pill
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.matahari,
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
                    'Isi kapsul rahasia, nominal acak',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Mesin Gacha (Kubah 230x230 + Basis Tuas 250x128)
              Center(
                child: Column(
                  children: [
                    // Kubah Transparan Bulat 230x230
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(5, 5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 9 Kapsul persis koordinat & delay Kapsul.dc.html
                          for (int i = 0; i < _kDefaultDomeCapsules.length; i++) ...[
                            AnimatedBuilder(
                              animation: Listenable.merge([_jiggleController, _crankController]),
                              builder: (context, _) {
                                final pos = _kDefaultDomeCapsules[i];
                                final jiggle = _calcJiggle(_jiggleController.value, pos.delay);
                                double crankShakeX = 0;
                                double crankShakeY = 0;
                                if (_isCranking) {
                                  final ct = _crankController.value;
                                  crankShakeX = math.sin(ct * math.pi * 18 + i) * 7.0;
                                  crankShakeY = math.cos(ct * math.pi * 18 + i) * 6.0;
                                }
                                return Positioned(
                                  left: pos.left + jiggle.dx + crankShakeX,
                                  top: pos.top + jiggle.dy + crankShakeY,
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: pos.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.ink, width: 3),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Basis Dispenser Tuas 250x128
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Container(
                        width: 250,
                        height: 128,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.tomat,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.ink, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(5, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Knob Tuas Putar (74x74)
                            GestureDetector(
                              onTap: _triggerGacha,
                              child: AnimatedBuilder(
                                animation: _crankCurve,
                                builder: (context, _) {
                                  final rotation = _crankCurve.value * 540.0 * math.pi / 180;
                                  return Transform.rotate(
                                    angle: rotation,
                                    child: Container(
                                      width: 74,
                                      height: 74,
                                      decoration: BoxDecoration(
                                        color: AppColors.matahari,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.ink, width: 4),
                                      ),
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 46,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: AppColors.ink,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Lubang Keluar Kapsul (84x48)
                            Container(
                              width: 84,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.ink,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(4)),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedBuilder(
                                animation: _dropController,
                                builder: (context, _) {
                                  final t = _dropController.value;
                                  if (!_isCranking && _wonAmount == null) {
                                    return const SizedBox.shrink();
                                  }

                                  double translateY = 0;
                                  double scale = 1.0;
                                  double opacity = 1.0;

                                  // @keyframes dr dari Kapsul.dc.html:
                                  // 0%,36% -> translateY(-70px), opacity: 0
                                  // 40% -> opacity: 1
                                  // 54% -> translateY(10px) (overshoot / tabrak bawah)
                                  // 58% -> translateY(-8px) (pantul ke atas)
                                  // 62%,76% -> translateY(0), opacity: 1 (diam di tempat)
                                  // 84%,100% -> scale(1.8), opacity: 0 (terbuka & meletup)
                                  if (t <= 0.36) {
                                    translateY = -70.0;
                                    opacity = 0.0;
                                  } else if (t <= 0.54) {
                                    final u = (t - 0.36) / 0.18;
                                    opacity = ((t - 0.36) / 0.04).clamp(0.0, 1.0);
                                    translateY = -70.0 + 80.0 * (u * u);
                                  } else if (t <= 0.58) {
                                    final u = (t - 0.54) / 0.04;
                                    final sinVal = math.sin(u * math.pi);
                                    translateY = 10.0 - 18.0 * sinVal;
                                  } else if (t <= 0.62) {
                                    final u = (t - 0.58) / 0.04;
                                    translateY = -8.0 * (1.0 - u);
                                  } else if (t <= 0.76) {
                                    translateY = 0.0;
                                    scale = 1.0;
                                    opacity = 1.0;
                                  } else {
                                    final u = (t - 0.76) / 0.24;
                                    scale = 1.0 + 0.8 * Curves.easeOutBack.transform(u);
                                    opacity = (1.0 - u * 1.2).clamp(0.0, 1.0);
                                  }

                                  return Transform.translate(
                                    offset: Offset(0, translateY),
                                    child: Transform.scale(
                                      scale: scale,
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: _wonColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppColors.surface, width: 3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Kartu Hasil Gacha
              if (_wonAmount != null && !_isCranking) ...[
                PopReveal(
                  child: StickerCard(
                    backgroundColor: AppColors.surface,
                    borderRadius: 22,
                    borderWidth: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'Isi kapsul kamu',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RupiahFormatter.format(_wonAmount!),
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Tombol Aksi Bawah
              if (_wonAmount != null && !_isCranking) ...[
                StickerButton.large(
                  text: 'Ambil Budget ${RupiahFormatter.format(_wonAmount!)}',
                  backgroundColor: AppColors.matahari,
                  textColor: AppColors.ink,
                  onPressed: () => _startActiveDate(_wonAmount!),
                ),
                const SizedBox(height: 12),
              ],

              StickerButton.large(
                text: _isCranking ? 'MEMUTAR...' : 'PUTAR TUAS',
                backgroundColor: AppColors.permen,
                textColor: AppColors.ink,
                onPressed: _isCranking ? () {} : _triggerGacha,
              ),
              const SizedBox(height: 14),

              // Tombol Atur Isi Kapsul yang Jelas
              StickerButton(
                height: 50,
                borderRadius: 25,
                backgroundColor: AppColors.surface,
                textColor: AppColors.ink,
                onPressed: () async {
                  SoundService.instance.play(Sfx.uiTap);
                  await context.push('/custom-wheel?game=capsule');
                  _loadPool();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(
                        painter: CustomSettingsIconPainter(
                          color: AppColors.ink,
                          strokeWidth: 2.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Atur Isi Kapsul (${_currentPool.length} Nominal)',
                          style: AppTypography.buttonSmall.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

