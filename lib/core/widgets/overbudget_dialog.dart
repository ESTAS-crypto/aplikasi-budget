import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';
import '../painters/sticker_icons.dart';
import '../utils/rupiah_formatter.dart';
import '../utils/sound_service.dart';
import 'sticker_button.dart';

/// Menampilkan dialog peringatan saat jajan melebihi budget (Budget lewat!).
/// Kartu putih, ikon peringatan di lingkaran warna danger, tombol "Catat tetap" dan "Hapus item".
/// Animasi membesar dari skala 0.8 ke 1.04 lalu ke 1.0.
Future<bool?> showOverbudgetDialog(
  BuildContext context, {
  required int excessAmount,
}) {
  SoundService.instance.play(Sfx.overBudget);
  final theme = PutarTheme.of(context);

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Budget Lewat',
    barrierColor: theme.ink.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, anim1, anim2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final t = PutarTheme.of(ctx);
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
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(
                  color: t.borderColor,
                  width: t.borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: t.dialogShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ikon peringatan di lingkaran danger
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: t.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.borderColor,
                        width: t.borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: t.miniShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: CustomWarningIconPainter(
                        color: t.ink,
                        markColor: t.ink,
                        strokeWidth: 3.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.text(PutarCopyKeys.budgetOverShort),
                    style: t.displayMedium.copyWith(
                      fontSize: 26,
                      color: t.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jajan ini bikin kamu lewat budget sebesar ${RupiahFormatter.format(excessAmount)}. Mau tetap dicatat?',
                    style: t.bodyMedium.copyWith(
                      color: t.textSecondary,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Tombol "Catat tetap"
                  StickerButton(
                    width: double.infinity,
                    height: 50,
                    text: 'Catat tetap',
                    backgroundColor: t.danger,
                    textColor: t.ink,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                  const SizedBox(height: 12),
                  // Tombol "Hapus item"
                  StickerButton(
                    width: double.infinity,
                    height: 50,
                    text: 'Hapus item',
                    backgroundColor: t.bg,
                    textColor: t.ink,
                    onPressed: () => Navigator.of(ctx).pop(false),
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
