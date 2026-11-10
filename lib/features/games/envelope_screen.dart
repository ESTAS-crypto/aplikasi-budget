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

/// Layar 14: Pilih Amplop
/// Sesuai design/source/Amplop.dc.html
class EnvelopeScreen extends ConsumerStatefulWidget {
  const EnvelopeScreen({super.key});

  @override
  ConsumerState<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends ConsumerState<EnvelopeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _openController;

  int? _selectedIndex;
  int? _wonAmount;
  bool _isOpening = false;
  bool _hasPlayedOpenSound = false;
  List<int> _currentPool = GamePoolRepository.defaultEnvelopePool;
  List<int> _roundAmounts = [30000, 40000, 50000];

  final List<Color> _envelopeColors = const [
    AppColors.mint,
    AppColors.permen,
    AppColors.langit,
  ];

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Sinkronisasi audio: suara robekan flap terbuka tepat saat penutup amplop terlipat di t = 0.38
    _openController.addListener(() {
      if (_isOpening) {
        final t = _openController.value;
        if (t >= 0.38 && !_hasPlayedOpenSound) {
          _hasPlayedOpenSound = true;
          SoundService.instance.play(Sfx.envelopeOpen);
          HapticFeedback.mediumImpact();
        }
      }
    });

    _loadPool();
  }

  Future<void> _loadPool() async {
    final repo = ref.read(gamePoolRepositoryProvider);
    final db = ref.read(databaseProvider);
    final pool = await repo.getPool(GameType.envelope, db);
    if (mounted) {
      setState(() {
        _currentPool = pool;
        _shuffleRound();
      });
    }
  }

  void _shuffleRound() {
    SoundService.instance.play(Sfx.envelopeShuffle);
    final engine = EnvelopeGameEngine(pool: _currentPool);
    final outcome = engine.play();
    final rawCandidate = outcome.animationParameters['candidatePool'] ?? outcome.animationParameters['envelopeAmounts'];
    final candidatePool = rawCandidate != null
        ? List<int>.from(rawCandidate as List)
        : List<int>.from(_currentPool.take(3));

    setState(() {
      _roundAmounts = candidatePool;
      _selectedIndex = null;
      _wonAmount = null;
    });
  }

  @override
  void dispose() {
    _openController.dispose();
    super.dispose();
  }

  void _selectEnvelope(int index) {
    if (_isOpening || _selectedIndex != null) return;

    // Reset flag sinkronisasi audio untuk setiap putaran
    _hasPlayedOpenSound = false;

    // Suara pemilihan amplop instan dan jernih
    SoundService.instance.play(Sfx.uiTap);

    setState(() {
      _selectedIndex = index;
      _isOpening = true;
    });

    _openController.forward(from: 0.0).then((_) {
      if (!mounted) return;

      setState(() {
        _isOpening = false;
        _wonAmount = _roundAmounts[index.clamp(0, _roundAmounts.length - 1)];
      });

      // Suara kemenangan saat nominal amplop muncul
      SoundService.instance.play(Sfx.winLolos, volume: 0.85);

      // Bacakan untuk TalkBack / Aksesibilitas
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Budget kamu ${RupiahFormatter.format(_wonAmount!)}',
        TextDirection.ltr,
      );
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
                      'Pilih Amplop',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  // Tombol Atur Pool
                  GestureDetector(
                    onTap: () async {
                      SoundService.instance.play(Sfx.uiTap);
                      await context.push('/custom-wheel?game=envelope');
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
                    'Satu amplop, isinya rahasia',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // 2. Barisan 3 Amplop
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (index) {
                  final isChosen = _selectedIndex == index;
                  final isOther = _selectedIndex != null && !isChosen;
                  final color = _envelopeColors[index % _envelopeColors.length];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => _selectEnvelope(index),
                        child: _AnimatedEnvelope(
                          isChosen: isChosen,
                          isOther: isOther,
                          color: color,
                          controller: _openController,
                          amountText: RupiahFormatter.formatCompact(_roundAmounts[index % _roundAmounts.length]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Keterangan pilihan amplop
              Center(
                child: Text(
                  _selectedIndex == null
                      ? 'Pilih salah satu amplop di atas'
                      : 'Amplop ${_selectedIndex == 0 ? "kiri" : _selectedIndex == 1 ? "tengah" : "kanan"} yang kamu pilih',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Kartu Hasil Amplop (dengan PopReveal sesuai @keyframes pop)
              if (_wonAmount != null && !_isOpening) ...[
                PopReveal(
                  child: StickerCard(
                    backgroundColor: AppColors.surface,
                    borderRadius: 22,
                    borderWidth: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'Isi amplop kamu',
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
              if (_wonAmount != null && !_isOpening) ...[
                StickerButton.large(
                  text: 'Ambil Budget ${RupiahFormatter.format(_wonAmount!)}',
                  backgroundColor: AppColors.matahari,
                  textColor: AppColors.ink,
                  onPressed: () => _startActiveDate(_wonAmount!),
                ),
                const SizedBox(height: 12),
              ],

              StickerButton.large(
                text: _selectedIndex == null
                    ? 'BUKA AMPLOP'
                    : _isOpening
                        ? 'MEMBUKA...'
                        : 'Kocok Lagi Ronde Ini',
                backgroundColor: AppColors.mint,
                textColor: AppColors.ink,
                onPressed: _isOpening
                    ? () {}
                    : _selectedIndex == null
                        ? () => _selectEnvelope(1)
                        : _shuffleRound,
              ),
              const SizedBox(height: 14),

              // Tombol Atur Isi Amplop yang Jelas
              StickerButton(
                height: 50,
                borderRadius: 25,
                backgroundColor: AppColors.surface,
                textColor: AppColors.ink,
                onPressed: () async {
                  SoundService.instance.play(Sfx.uiTap);
                  await context.push('/custom-wheel?game=envelope');
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
                          'Atur Isi Amplop (${_currentPool.length} Nominal)',
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

/// Widget Amplop Tunggal dengan Flap yang Membuka dan Kertas yang Muncul Naik
class _AnimatedEnvelope extends StatelessWidget {
  final bool isChosen;
  final bool isOther;
  final Color color;
  final AnimationController controller;
  final String amountText;

  const _AnimatedEnvelope({
    required this.isChosen,
    required this.isOther,
    required this.color,
    required this.controller,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;

        double opacity = 1.0;
        double scale = 1.0;
        double jiggleAngle = 0.0;
        double flapScaleY = 1.0;
        double slidePaperY = 0.0;

        if (isOther) {
          // @keyframes dm: 0%,32% -> opacity: 1, scale: 1; 42%,92% -> opacity: .4, scale: .92
          if (t < 0.32) {
            opacity = 1.0;
            scale = 1.0;
          } else if (t < 0.42) {
            final p = (t - 0.32) / 0.10;
            opacity = 1.0 - 0.6 * p;
            scale = 1.0 - 0.08 * p;
          } else {
            opacity = 0.4;
            scale = 0.92;
          }
        } else if (isChosen) {
          // @keyframes jw: 0%,30% -> rotate(0); 6% -> -4deg; 12% -> 4deg; 18% -> -3deg; 24% -> 0
          if (t <= 0.06) {
            jiggleAngle = -4.0 * (t / 0.06);
          } else if (t <= 0.12) {
            final u = (t - 0.06) / 0.06;
            jiggleAngle = -4.0 + 8.0 * u;
          } else if (t <= 0.18) {
            final u = (t - 0.12) / 0.06;
            jiggleAngle = 4.0 - 7.0 * u;
          } else if (t <= 0.24) {
            final u = (t - 0.18) / 0.06;
            jiggleAngle = -3.0 * (1.0 - u);
          } else {
            jiggleAngle = 0.0;
          }

          // @keyframes op: 0%,38% -> scaleY(1); 52%,92% -> scaleY(-1)
          if (t <= 0.38) {
            flapScaleY = 1.0;
          } else if (t <= 0.52) {
            final u = (t - 0.38) / 0.14;
            flapScaleY = math.cos(u * math.pi); // Putar 3D 1.0 -> 0.0 -> -1.0 mulus
          } else {
            flapScaleY = -1.0;
          }

          // @keyframes sl: 0%,48% -> translateY(0); 62%,92% -> translateY(-66px)
          if (t <= 0.48) {
            slidePaperY = 0.0;
          } else if (t <= 0.62) {
            final u = (t - 0.48) / 0.14;
            slidePaperY = -66.0 * Curves.easeOutCubic.transform(u);
          } else {
            slidePaperY = -66.0;
          }
        }

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: jiggleAngle * math.pi / 180,
              child: SizedBox(
                width: 104,
                height: 140,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Kertas hasil di dalam amplop
                    Positioned(
                      top: 40 + slidePaperY,
                      child: Container(
                        width: 80,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.ink, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isChosen && t > 0.7 ? amountText : '?',
                          style: AppTypography.bodyLargeBold.copyWith(
                            color: AppColors.ink,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    // Badan Amplop
                    Positioned(
                      top: 36,
                      child: Container(
                        width: 100,
                        height: 92,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink, width: 3.5),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '?',
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),

                    // Tutup Segitiga Amplop (Flap)
                    Positioned(
                      top: 36,
                      child: Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.diagonal3Values(1.0, flapScaleY, 1.0),
                        child: SizedBox(
                          width: 100,
                          height: 50,
                          child: CustomPaint(
                            painter: _EnvelopeFlapPainter(color: color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EnvelopeFlapPainter extends CustomPainter {
  final Color color;

  const _EnvelopeFlapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(size.width - 2, 2)
      ..lineTo(size.width / 2, size.height - 4)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EnvelopeFlapPainter oldDelegate) => oldDelegate.color != color;
}

