import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Menampilkan snackbar neo-brutalist (latar Ink, teks Krim, aksi Urungkan Kuning, durasi 3 detik).
void showStickerSnackbar(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
  String undoLabel = 'Urungkan',
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      padding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.ink,
            width: 2.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyLargeBold.copyWith(
                  color: AppColors.cream,
                ),
              ),
            ),
            if (onUndo != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onUndo();
                },
                child: Text(
                  undoLabel,
                  style: AppTypography.bodyLargeBold.copyWith(
                    color: AppColors.matahari,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
