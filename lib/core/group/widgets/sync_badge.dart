import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../painters/group_icons_painter.dart';

/// Badge Sinkronisasi Inline untuk Item Catatan Pengeluaran Grup
class SyncBadge extends StatelessWidget {
  final bool hasPendingWrites;
  final bool compact;

  const SyncBadge({
    super.key,
    required this.hasPendingWrites,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = hasPendingWrites;
    final bgColor = isPending ? AppColors.matahari : AppColors.mint;
    final label = isPending ? 'Menunggu' : 'Terkirim';
    final semanticsLabel = isPending
        ? 'Catatan menunggu koneksi untuk terkirim ke server'
        : 'Catatan sudah tersimpan di server';

    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.ink,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(1, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(11, 11),
              painter: isPending
                  ? const CustomClockPainter(color: AppColors.ink, strokeWidth: 2.0)
                  : const CustomCheckPainter(color: AppColors.ink, strokeWidth: 2.0),
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

