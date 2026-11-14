import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/putar_theme.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/painters/confetti_painter.dart';
import '../../core/painters/mochi_painter.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../data/database.dart';
import '../../data/database_provider.dart';

class DateResultScreen extends ConsumerStatefulWidget {
  final int dateId;

  const DateResultScreen({super.key, required this.dateId});

  @override
  ConsumerState<DateResultScreen> createState() => _DateResultScreenState();
}

class _DateResultScreenState extends ConsumerState<DateResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _stampController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  DateRecord? _dateRecord;
  List<DateItemRecord> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Stempel masuk dari skala 2.4 ke 1.0 (mantul sedikit)
    _scaleAnimation = Tween<double>(begin: 2.4, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.easeOutBack),
    );

    // Rotasi dari -25 derajat lalu mendarat di -6 derajat
    _rotationAnimation = Tween<double>(
      begin: -25.0 * math.pi / 180,
      end: -6.0 * math.pi / 180,
    ).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.easeOutCubic),
    );

    _loadDateData();
  }

  Future<void> _loadDateData() async {
    final db = ref.read(databaseProvider);
    final date = await db.getDateById(widget.dateId);
    final items = await db.getItemsForDate(widget.dateId);

    if (mounted) {
      final totalSpent = items.fold(0, (sum, i) => sum + i.price);
      final isPassed = date != null && totalSpent <= date.budget;

      setState(() {
        _dateRecord = date;
        _items = items;
        _loading = false;
      });
      _stampController.forward();

      if (isPassed) {
        SoundService.instance.play(Sfx.winLolos);
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  @override
  void dispose() {
    _stampController.dispose();
    super.dispose();
  }

  void _shareResult(bool isPassed, int savedOrExceeded) {
    SoundService.instance.play(Sfx.uiTap);
    final statusText = isPassed
        ? 'Lolos budget! Hemat ${RupiahFormatter.format(savedOrExceeded)}'
        : 'Budget lewat ${RupiahFormatter.format(savedOrExceeded)}';
    SharePlus.instance.share(
      ShareParams(
        text: 'Ngedate malam ini pakai Putar Jajan: $statusText!\nYuk tentukan budget jajan ngedate kamu dengan putar permainan!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    if (_loading || _dateRecord == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(child: CircularProgressIndicator(color: t.ink)),
      );
    }

    final totalSpent = _items.fold(0, (sum, i) => sum + i.price);
    final isPassed = totalSpent <= _dateRecord!.budget;
    final diff = (_dateRecord!.budget - totalSpent).abs();

    final bgColor = t.mascot != null
        ? (isPassed ? t.accentPink : t.softDangerBg)
        : (isPassed ? t.success : t.danger);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Konfeti jatuh jika Lolos
          if (isPassed)
          Positioned.fill(
            child: IgnorePointer(
              child: t.celebration == PutarCelebrationStyle.hearts
                  ? const HeartConfettiField(particleCount: 28)
                  : const ConfettiField(particleCount: 50),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Stempel Matahari / Maskot Mochi Lolos atau Lewat
                  if (t.mascot == PutarMascotKind.mochi)
                    AnimatedBuilder(
                      animation: _stampController,
                      builder: (context, child) {
                        final reduceMotion =
                            MediaQuery.maybeDisableAnimationsOf(context) ??
                                false;
                        final jumpDy = isPassed && !reduceMotion
                            ? -14.0 *
                                math
                                    .sin(_stampController.value * math.pi)
                                    .clamp(0.0, 1.0)
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(0, jumpDy),
                          child: Transform.scale(
                            scale: reduceMotion ? 1.0 : _scaleAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: MochiWidget(
                        size: 170,
                        expression: isPassed
                            ? MochiExpression.happy
                            : MochiExpression.sad,
                        animate: !(MediaQuery.maybeDisableAnimationsOf(context) ??
                            false),
                      ),
                    )
                  else
                    AnimatedBuilder(
                      animation: _stampController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: t.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.ink, width: 4.5),
                          boxShadow: [
                            BoxShadow(
                              color: t.ink,
                              offset: const Offset(5, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: CustomPaint(
                            painter: isPassed
                                ? CustomCheckIconPainter(
                                    color: t.ink,
                                    strokeWidth: 5.5,
                                  )
                                : CustomCloseIconPainter(
                                    color: t.ink,
                                    strokeWidth: 5.5,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),

                  // Teks "Lolos budget!" / "Budget lewat!"
                  Text(
                    isPassed ? 'Lolos budget!' : t.text(PutarCopyKeys.budgetOverShort),
                    style: t.displayLarge.copyWith(
                      fontSize: 38,
                      color: t.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // "Kamu hemat" / "Budget lewat"
                  Text(
                    isPassed ? 'Kamu hemat' : 'Melebihi budget',
                    style: t.bodyLargeBold.copyWith(
                      color: t.ink.withValues(alpha: 0.85),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Angka besar RpX
                  Text(
                    RupiahFormatter.format(diff),
                    style: t.displayLarge.copyWith(
                      fontSize: 44,
                      color: t.ink,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Kartu Ringkasan 3 Kolom (Budget, Terpakai, Jajan)
                  StickerCard(
                    backgroundColor: t.surface.withValues(alpha: 0.92),
                    borderRadius: t.cardRadius,
                    borderWidth: t.heroBorderWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Kolom 1: Budget
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Budget',
                                style: t.bodySmall.copyWith(
                                  color: t.textSecondary,
                                  fontWeight: t.weightBold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RupiahFormatter.format(_dateRecord!.budget),
                                style: t.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  color: t.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 2.5, height: 38, color: t.ink),
                        // Kolom 2: Terpakai
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Terpakai',
                                style: t.bodySmall.copyWith(
                                  color: t.textSecondary,
                                  fontWeight: t.weightBold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RupiahFormatter.format(totalSpent),
                                style: t.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  color: t.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 2.5, height: 38, color: t.ink),
                        // Kolom 3: Jajan
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Jajan',
                                style: t.bodySmall.copyWith(
                                  color: t.textSecondary,
                                  fontWeight: t.weightBold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_items.length} item',
                                style: t.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  color: t.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Tombol "Bagikan hasil"
                  StickerButton.large(
                    text: 'Bagikan hasil',
                    backgroundColor: t.secondary,
                    textColor: t.ink,
                    onPressed: () => _shareResult(isPassed, diff),
                  ),
                  const SizedBox(height: 16),

                  // Tombol teks "Putar lagi minggu depan"
                  GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.uiTap);
                      context.go('/');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Putar lagi minggu depan',
                        style: t.bodyLargeBold.copyWith(
                          color: t.ink,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                          decorationColor: t.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
