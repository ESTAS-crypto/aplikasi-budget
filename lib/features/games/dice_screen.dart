import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/games/game_engine.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/theme/putar_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/in_app_toast.dart';
import '../../core/widgets/pop_reveal.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_card.dart';
import '../../data/database_provider.dart';
import '../../data/game_pool_repository.dart';
import '../notifications/notification_service.dart';

/// Layar 12: Kocok Dadu
/// Sesuai design/source/Dadu.dc.html
class DiceScreen extends ConsumerStatefulWidget {
  const DiceScreen({super.key});

  @override
  ConsumerState<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends ConsumerState<DiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rollController;
  int _diceCount = 2;
  int _multiplier = 10000;

  List<int> _currentValues = [3, 5];
  bool _isRolling = false;
  int? _wonAmount;

  final List<int> _presetMultipliers = [5000, 10000, 20000];
  bool _hasPlayedLandSound = false;
  bool _hasPlayedBounceSound = false;

  @override
  void initState() {
    super.initState();
    _rollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Sinkronisasi audio dan getaran presisi saat dadu menghantam lantai
    _rollController.addListener(() {
      if (_isRolling) {
        final t = _rollController.value;
        // Benturan dadu pertama jatuh ke lantai tepat di t = 0.30 (285ms)
        if (t >= 0.30 && !_hasPlayedLandSound) {
          _hasPlayedLandSound = true;
          SoundService.instance.play(Sfx.diceLand);
        }
        // Benturan dadu kedua mendarat tepat setelah delay 120ms (t = 0.43 / ~408ms)
        if (t >= 0.43 && !_hasPlayedBounceSound) {
          _hasPlayedBounceSound = true;
          SoundService.instance.play(Sfx.diceLand, volume: 0.75, pitch: 1.1);
        }
      }
    });

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final repo = ref.read(gamePoolRepositoryProvider);
    final count = await repo.getDiceCount();
    final mult = await repo.getDiceMultiplier();
    if (mounted) {
      setState(() {
        _diceCount = count.clamp(1, 3);
        _multiplier = mult;
        _currentValues = List.filled(_diceCount, 4);
      });
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  void _rollDice() {
    if (_isRolling) return;

    // Reset flag audio benturan dadu setiap kocokan baru
    _hasPlayedLandSound = false;
    _hasPlayedBounceSound = false;

    // Suara menggelinding dadu (tanpa uiTap agar tidak double)
    SoundService.instance.play(Sfx.diceRoll);

    final engine = DiceGameEngine(
      diceCount: _diceCount,
      multiplier: _multiplier,
    );
    final outcome = engine.play();

    final rawRolls = outcome.animationParameters['rolls'] ?? outcome.animationParameters['diceValues'];
    final rolls = rawRolls != null
        ? List<int>.from(rawRolls as List)
        : List.filled(_diceCount, 4);

    setState(() {
      _isRolling = true;
      _wonAmount = null;
    });

    _rollController.forward(from: 0.0).then((_) {
      if (mounted) {
        // Suara kemenangan saat dadu berhenti sempurna dan nominal muncul
        SoundService.instance.play(Sfx.winLolos, volume: 0.85);
        HapticFeedback.heavyImpact();

        setState(() {
          _isRolling = false;
          _currentValues = rolls;
          _wonAmount = outcome.wonAmount;
        });

        // Bacakan untuk TalkBack / Aksesibilitas
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Budget kamu ${RupiahFormatter.format(outcome.wonAmount)}',
          TextDirection.ltr,
        );
      }
    });
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

  void _showCustomMultiplierDialog() {
    final t = context.putarTheme;
    final controller = TextEditingController(text: RupiahFormatter.format(_multiplier).replaceAll('Rp', ''));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius),
          side: BorderSide(color: t.ink, width: t.borderWidth),
        ),
        title: Text(
          'Kelipatan Kustom',
          style: TextStyle(fontWeight: t.weightExtraBold, color: t.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.ink, width: t.subtleBorderWidth),
              ),
              child: Row(
                children: [
                  Text(
                    'Rp ',
                    style: t.titleMedium.copyWith(
                      color: t.danger,
                      fontWeight: t.weightExtraBold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [ThousandsSeparatorInputFormatter()],
                      style: t.titleMedium.copyWith(color: t.ink),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: t.textDisabled)),
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
              final parsed = RupiahFormatter.parse(controller.text);
              if (parsed >= 1000 && parsed <= 500000) {
                setState(() => _multiplier = parsed);
                ref.read(gamePoolRepositoryProvider).setDiceMultiplier(parsed);
                Navigator.pop(ctx);
              } else {
                InAppToast.show(context, message: 'Kelipatan antara Rp1.000 - Rp500.000');
              }
            },
            child: Text('Terapkan', style: TextStyle(fontWeight: t.weightExtraBold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final activeDate = activeDateAsync.value;

    return Scaffold(
      backgroundColor: t.bg,
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
                        color: t.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.ink, width: t.borderWidth),
                        boxShadow: [
                          BoxShadow(
                            color: t.shadowColor,
                            offset: t.smallShadowOffset,
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
                            color: t.ink,
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Kocok Dadu',
                      style: t.displayMedium.copyWith(
                        fontSize: 24,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                  ),
                  // Pilihan jumlah dadu 1-3
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [1, 2, 3].map((count) {
                      final isSelected = _diceCount == count;
                      return GestureDetector(
                        onTap: () {
                          if (_isRolling) return;
                          SoundService.instance.play(Sfx.uiTap);
                          setState(() {
                            _diceCount = count;
                            _currentValues = List.filled(count, 4);
                            _wonAmount = null;
                          });
                          ref.read(gamePoolRepositoryProvider).setDiceCount(count);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? t.danger : t.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.ink, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: t.shadowColor,
                                offset: t.miniShadowOffset,
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$count',
                            style: t.bodySmall.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Banner notifikasi jika date sedang aktif
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
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.ink, width: t.subtleBorderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
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
                              color: t.ink,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Date aktif: ${RupiahFormatter.format(activeDate.budget)} · Buka Catatan',
                            style: t.bodySmall.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Tag pill
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.secondary,
                    borderRadius: BorderRadius.circular(t.chipRadius),
                    border: Border.all(color: t.ink, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: t.shadowColor,
                        offset: t.smallShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    '$_diceCount dadu × nominal pilihanmu',
                    style: t.bodySmall.copyWith(
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Arena Dadu
              Container(
                height: 230,
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: t.accentWarmSoft,
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  border: Border.all(color: t.ink, width: t.borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: t.shadowColor,
                      offset: t.standardShadowOffset,
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bayangan di bawah dadu
                    Positioned(
                      bottom: 24,
                      child: AnimatedBuilder(
                        animation: _rollController,
                        builder: (context, _) {
                          final v = _rollController.value;
                          final scale = _isRolling
                              ? (0.4 + 0.6 * math.sin(v * math.pi).abs())
                              : 1.0;
                          return Transform.scale(
                            scaleX: scale,
                            scaleY: 0.8,
                            child: Container(
                              width: 180,
                              height: 14,
                              decoration: BoxDecoration(
                                color: t.ink.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Deretan Dadu dengan skala dinamis bebas overflow
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_diceCount, (index) {
                            final dieBg = index == 0
                                ? t.surface
                                : index == 1
                                    ? t.accentBlue
                                    : t.success;
                            final dieSize = _diceCount == 1
                                ? 104.0
                                : _diceCount == 2
                                    ? 88.0
                                    : 74.0;
                            final hPadding = _diceCount == 3 ? 5.0 : 8.0;
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: hPadding),
                              child: _AnimatedDie(
                                value: _currentValues[index.clamp(0, _currentValues.length - 1)],
                                isRolling: _isRolling,
                                controller: _rollController,
                                delayFraction: index * (120.0 / 950.0),
                                backgroundColor: dieBg,
                                size: dieSize,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 3. Kartu Hasil Kocokan dengan Animasi Pop Reveal
              if (_wonAmount != null && !_isRolling) ...[
                PopReveal(
                  child: StickerCard(
                    backgroundColor: t.surface,
                    borderRadius: t.cardRadius,
                    borderWidth: t.borderWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'Total ${_currentValues.fold(0, (a, b) => a + b)} × ${RupiahFormatter.format(_multiplier)} = budget kamu',
                          style: t.bodySmall.copyWith(
                            fontWeight: t.weightBold,
                            color: t.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RupiahFormatter.format(_wonAmount!),
                          style: t.displayLarge.copyWith(
                            fontSize: 34,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Bagian Kelipatan (Multiplier)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kelipatan',
                    style: t.titleMedium.copyWith(
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Dadu × ${RupiahFormatter.format(_multiplier)}',
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall.copyWith(
                        fontWeight: t.weightBold,
                        color: t.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Nilai dadu dijumlahkan lalu dikalikan kelipatan untuk menentukan budget.',
                style: t.bodySmall.copyWith(
                  color: t.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    ..._presetMultipliers.map((m) {
                    final isSelected = _multiplier == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () {
                          if (_isRolling) return;
                          SoundService.instance.play(Sfx.uiTap);
                          setState(() {
                            _multiplier = m;
                            _wonAmount = null;
                          });
                          ref.read(gamePoolRepositoryProvider).setDiceMultiplier(m);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? t.secondary : t.surface,
                            borderRadius: BorderRadius.circular(t.chipRadius),
                            border: Border.all(color: t.ink, width: t.borderWidth),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: t.shadowColor,
                                      offset: t.smallShadowOffset,
                                      blurRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            RupiahFormatter.format(m),
                            style: t.bodySmall.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Opsi Kustom
                  GestureDetector(
                    onTap: () {
                      if (_isRolling) return;
                      SoundService.instance.play(Sfx.uiTap);
                      _showCustomMultiplierDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: !_presetMultipliers.contains(_multiplier)
                            ? t.secondary
                            : t.surface,
                        borderRadius: BorderRadius.circular(t.chipRadius),
                        border: Border.all(color: t.ink, width: t.borderWidth),
                        boxShadow: !_presetMultipliers.contains(_multiplier)
                            ? [
                                BoxShadow(
                                  color: t.shadowColor,
                                  offset: t.smallShadowOffset,
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        !_presetMultipliers.contains(_multiplier)
                            ? RupiahFormatter.format(_multiplier)
                            : '+ Nominal Kustom',
                        style: t.bodySmall.copyWith(
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

              // 5. Tombol Aksi Bawah
              if (_wonAmount != null && !_isRolling) ...[
                StickerButton.large(
                  text: 'Ambil Budget ${RupiahFormatter.format(_wonAmount!)}',
                  backgroundColor: t.secondary,
                  textColor: t.ink,
                  onPressed: () => _startActiveDate(_wonAmount!),
                ),
                const SizedBox(height: 12),
              ],

              StickerButton.large(
                text: _isRolling ? 'MENGOBRAK...' : 'KOCOK DADU',
                backgroundColor: t.danger,
                textColor: t.ink,
                onPressed: _isRolling ? () {} : _rollDice,
              ),
              const SizedBox(height: 14),

              // Tombol Atur Nominal Kelipatan Dadu
              StickerButton(
                height: 50,
                borderRadius: 25,
                backgroundColor: t.surface,
                textColor: t.ink,
                onPressed: () {
                  if (_isRolling) return;
                  SoundService.instance.play(Sfx.uiTap);
                  _showCustomMultiplierDialog();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(
                        painter: CustomSettingsIconPainter(
                          color: t.ink,
                          strokeWidth: 2.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Ubah Kelipatan (${RupiahFormatter.format(_multiplier)})',
                          style: t.buttonSmall.copyWith(
                            color: t.ink,
                            fontWeight: t.weightExtraBold,
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

/// Widget Satu Dadu dengan Animasi Fisika Lengkap (translateY(-170), rotate(-420deg), bounce)
class _AnimatedDie extends StatelessWidget {
  final int value;
  final bool isRolling;
  final AnimationController controller;
  final double delayFraction;
  final Color backgroundColor;
  final double size;

  const _AnimatedDie({
    required this.value,
    required this.isRolling,
    required this.controller,
    required this.delayFraction,
    required this.backgroundColor,
    this.size = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    if (!isRolling) {
      return _buildDieBody(value, t);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Timeline 0.0 - 1.0 dengan delayFraction per dadu
        final rawT = (controller.value - delayFraction) / (1.0 - delayFraction);
        final tVal = rawT.clamp(0.0, 1.0);

        double translateY = 0.0;
        double rotation = 0.0;
        double opacity = 1.0;

        if (tVal < 0.30) {
          final p = tVal / 0.30;
          final easeP = Curves.easeInQuad.transform(p);
          translateY = -170.0 * (1.0 - easeP);
          rotation = -420.0 * (1.0 - p);
          opacity = (p * 5.0).clamp(0.0, 1.0);
        } else if (tVal < 0.38) {
          // Bounce 1: naik melengkung ke -46
          final p = (tVal - 0.30) / 0.08;
          translateY = -46.0 * math.sin(p * math.pi);
          rotation = 0.0 + 110.0 * p;
        } else if (tVal < 0.46) {
          // Turun dari bounce 1 ke tanah
          final p = (tVal - 0.38) / 0.08;
          translateY = -46.0 * (1.0 - p);
          rotation = 110.0 + 90.0 * p;
        } else if (tVal < 0.52) {
          // Bounce 2: naik kecil ke -14
          final p = (tVal - 0.46) / 0.06;
          translateY = -14.0 * math.sin(p * math.pi);
          rotation = 200.0 + 130.0 * p;
        } else if (tVal < 0.60) {
          // Settle ke tanah
          final p = (tVal - 0.52) / 0.08;
          translateY = 0.0;
          rotation = 330.0 + 30.0 * p;
        } else {
          // Mendarat stabil
          translateY = 0.0;
          rotation = 360.0;
        }

        // Tampilkan angka berputar cepat saat melayang, lalu lock tepat ke target
        final displayVal = tVal < 0.58
            ? (((tVal * 26).toInt() + (delayFraction * 10).toInt()) % 6) + 1
            : value;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.rotate(
              angle: rotation * math.pi / 180,
              child: _buildDieBody(displayVal, t),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDieBody(int val, PutarTheme t) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: t.ink, width: t.heroBorderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.standardShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: CustomPaint(
        painter: _DieDotsPainter(val, t.ink),
      ),
    );
  }
}

/// CustomPainter untuk menggambar titik-titik dadu (1 sampai 6)
class _DieDotsPainter extends CustomPainter {
  final int value;
  final Color dotColor;

  const _DieDotsPainter(this.value, this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.11;

    final left = size.width * 0.22;
    final center = size.width * 0.5;
    final right = size.width * 0.78;

    final top = size.height * 0.22;
    final middle = size.height * 0.5;
    final bottom = size.height * 0.78;

    void draw(double x, double y) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }

    switch (value) {
      case 1:
        draw(center, middle);
        break;
      case 2:
        draw(left, top);
        draw(right, bottom);
        break;
      case 3:
        draw(left, top);
        draw(center, middle);
        draw(right, bottom);
        break;
      case 4:
        draw(left, top);
        draw(right, top);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 5:
        draw(left, top);
        draw(right, top);
        draw(center, middle);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 6:
        draw(left, top);
        draw(right, top);
        draw(left, middle);
        draw(right, middle);
        draw(left, bottom);
        draw(right, bottom);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DieDotsPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.dotColor != dotColor;
}

