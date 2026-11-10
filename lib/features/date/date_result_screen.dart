import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/painters/confetti_painter.dart';
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
    if (_loading || _dateRecord == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.ink)),
      );
    }

    final totalSpent = _items.fold(0, (sum, i) => sum + i.price);
    final isPassed = totalSpent <= _dateRecord!.budget;
    final diff = (_dateRecord!.budget - totalSpent).abs();

    final bgColor = isPassed ? AppColors.mint : AppColors.tomat;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Konfeti jatuh jika Lolos
          if (isPassed) const Positioned.fill(child: ConfettiField(particleCount: 50)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Stempel Matahari Centang (Lolos) atau Silang (Lewat)
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
                        color: AppColors.matahari,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 4.5),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(5, 5),
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
                              ? const CustomCheckIconPainter(
                                  color: AppColors.ink,
                                  strokeWidth: 5.5,
                                )
                              : const CustomCloseIconPainter(
                                  color: AppColors.ink,
                                  strokeWidth: 5.5,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Teks "Lolos budget!" / "Budget lewat!"
                  Text(
                    isPassed ? 'Lolos budget!' : 'Budget lewat!',
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 38,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // "Kamu hemat" / "Budget lewat"
                  Text(
                    isPassed ? 'Kamu hemat' : 'Melebihi budget',
                    style: AppTypography.bodyLargeBold.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.85),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Angka besar RpX
                  Text(
                    RupiahFormatter.format(diff),
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 44,
                      color: AppColors.ink,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Kartu Ringkasan 3 Kolom (Budget, Terpakai, Jajan)
                  StickerCard(
                    backgroundColor: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: 22,
                    borderWidth: 3.5,
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
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RupiahFormatter.format(_dateRecord!.budget),
                                style: AppTypography.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 2.5, height: 38, color: AppColors.ink),
                        // Kolom 2: Terpakai
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Terpakai',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                RupiahFormatter.format(totalSpent),
                                style: AppTypography.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 2.5, height: 38, color: AppColors.ink),
                        // Kolom 3: Jajan
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Jajan',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_items.length} item',
                                style: AppTypography.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  color: AppColors.ink,
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
                    backgroundColor: AppColors.matahari,
                    textColor: AppColors.ink,
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
                        style: AppTypography.bodyLargeBold.copyWith(
                          color: AppColors.ink,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.ink,
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
