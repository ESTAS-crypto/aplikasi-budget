import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
import '../painters/group_icons_painter.dart';

/// Badge Sinkronisasi Inline untuk Item Catatan Pengeluaran Grup
class SyncBadge extends StatelessWidget {
  final bool hasPendingWrites;
  final bool compact;
  final bool pill;

  const SyncBadge({
    super.key,
    required this.hasPendingWrites,
    this.compact = false,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final isPending = hasPendingWrites;
    final bgColor = isPending ? t.secondary : t.success;
    final label = isPending ? 'Menunggu' : 'Terkirim';
    final semanticsLabel = isPending
        ? 'Catatan menunggu koneksi untuk terkirim ke server'
        : 'Catatan sudah tersimpan di server';

    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: pill
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 1)
            : EdgeInsets.symmetric(
                horizontal: compact ? 4 : 8,
                vertical: 3,
              ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(pill ? 99 : 6),
          border: Border.all(
            color: t.ink,
            width: pill ? 2.0 : 1.5,
          ),
          boxShadow: pill
              ? null
              : [
                  BoxShadow(
                    color: t.ink,
                    offset: const Offset(1, 1),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomPaint(
              size: pill ? const Size(13, 13) : const Size(11, 11),
              painter: isPending
                  ? CustomClockPainter(
                      color: t.ink,
                      strokeWidth: pill ? 2.6 : 2.0,
                    )
                  : CustomCheckPainter(
                      color: t.ink,
                      strokeWidth: pill ? 3.2 : 2.0,
                    ),
            ),
            if (!compact) ...[
              SizedBox(width: pill ? 4 : 5),
              Text(
                label,
                style: t.bodySmall.copyWith(
                  fontSize: pill ? 11 : 10,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                  letterSpacing: pill ? 0 : 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

