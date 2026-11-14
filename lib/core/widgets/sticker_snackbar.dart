import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';

/// Menampilkan snackbar bertema (latar Ink, teks bg, aksi Urungkan kuning/secondary, durasi 3 detik).
void showStickerSnackbar(
  BuildContext context, {
  required String message,
  VoidCallback? onUndo,
  String undoLabel = 'Urungkan',
  Duration duration = const Duration(seconds: 3),
}) {
  final t = PutarTheme.of(context);
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
          color: t.ink,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(
            color: t.borderColor,
            width: t.subtleBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: t.shadowColor,
              offset: t.smallShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: t.bodyLargeBold.copyWith(
                  color: t.bg,
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
                  style: t.bodyLargeBold.copyWith(
                    color: t.secondary,
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
