import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../painters/sticker_icons.dart';
import '../utils/rupiah_formatter.dart';
import '../utils/sound_service.dart';
import 'sticker_button.dart';

/// Menampilkan dialog peringatan saat jajan melebihi budget (Budget lewat!).
/// Kartu putih, ikon peringatan di lingkaran Tomat, tombol "Catat tetap" dan "Hapus item".
/// Animasi membesar dari skala 0.8 ke 1.04 lalu ke 1.0.
Future<bool?> showOverbudgetDialog(
  BuildContext context, {
  required int excessAmount,
}) {
  SoundService.instance.play(Sfx.overBudget);

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Budget Lewat',
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, anim1, anim2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, anim1, anim2, child) {
      // Keyframe sequence: 0.8 -> 1.04 -> 1.0
      final scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.8, end: 1.04)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 65,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.04, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 35,
        ),
      ]).animate(anim1);

      return Center(
        child: ScaleTransition(
          scale: scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.ink,
                  width: 3.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ikon peringatan di lingkaran Tomat
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.tomat,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: 3.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const CustomPaint(
                      painter: CustomWarningIconPainter(
                        color: AppColors.ink,
                        markColor: AppColors.ink,
                        strokeWidth: 3.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Budget lewat!',
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 26,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jajan ini bikin kamu lewat budget sebesar ${RupiahFormatter.format(excessAmount)}. Mau tetap dicatat?',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Tombol "Catat tetap" (Tomat)
                  StickerButton(
                    width: double.infinity,
                    height: 50,
                    text: 'Catat tetap',
                    backgroundColor: AppColors.tomat,
                    textColor: AppColors.ink,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 12),
                  // Tombol "Hapus item" (Krim/Matahari atau Surface)
                  StickerButton(
                    width: double.infinity,
                    height: 50,
                    text: 'Hapus item',
                    backgroundColor: AppColors.cream,
                    textColor: AppColors.ink,
                    onPressed: () => Navigator.of(context).pop(false),
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
