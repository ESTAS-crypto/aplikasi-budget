import 'package:flutter/material.dart';
import '../group/painters/group_icons_painter.dart';
import '../theme/putar_theme.dart';

/// Banner pesan error/validasi di dalam modal bottom sheet agar selalu terlihat
/// tepat di atas tombol simpan tanpa tertutup sheet atau keyboard.
class SheetInlineErrorBanner extends StatelessWidget {
  final String? message;

  const SheetInlineErrorBanner({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final text = message?.trim();
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    final t = context.putarTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        key: const ValueKey('sheet_inline_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.danger, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: t.danger,
                shape: BoxShape.circle,
                border: Border.all(color: t.borderColor, width: 1.5),
              ),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(10, 10),
                painter: CustomCrossPainter(
                  color: t.ink,
                  strokeWidth: 2.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: t.bodySmall.copyWith(
                  color: t.ink,
                  fontWeight: t.weightBold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
