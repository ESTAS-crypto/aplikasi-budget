import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
import '../painters/group_icons_painter.dart';

/// Komponen Neo-Brutalist Arti Status Sinkron (Layar 20: Grup5.dc.html)
class SyncLegend extends StatelessWidget {
  final bool isCard;

  const SyncLegend({
    super.key,
    this.isCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Arti status sinkron',
          style: t.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: t.weightExtraBold,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 8),
        _buildStatusRow(
          t: t,
          badgeBg: t.success,
          badgePainter: CustomCheckPainter(color: t.ink, strokeWidth: 2.8),
          label: 'Tersinkron',
          description: 'Semua anggota sudah menerimanya',
        ),
        _buildStatusRow(
          t: t,
          badgeBg: t.bg,
          badgePainter: CustomClockPainter(color: t.ink, strokeWidth: 2.8),
          label: 'Menunggu',
          description: 'Tersimpan di HP, belum terkirim',
        ),
        _buildStatusRow(
          t: t,
          badgeBg: t.secondary,
          badgePainter: CustomSyncArrowsPainter(color: t.ink, strokeWidth: 2.8),
          label: 'Menyinkronkan',
          description: 'Sedang dikirim',
        ),
        _buildStatusRow(
          t: t,
          badgeBg: t.ink,
          badgePainter: CustomCloudOfflinePainter(color: t.surface, strokeWidth: 2.8),
          label: 'Offline',
          description: 'Perubahan baru disimpan di HP',
        ),
        _buildStatusRow(
          t: t,
          badgeBg: t.danger,
          badgePainter: CustomWarningTrianglePainter(color: t.ink, strokeWidth: 2.8),
          label: t.text(PutarCopyKeys.syncFailed),
          description: 'Ketuk untuk coba lagi',
        ),
      ],
    );

    if (!isCard) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.ink, width: t.borderWidth),
        boxShadow: [
          BoxShadow(
            color: t.ink,
            offset: t.standardShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildStatusRow({
    required PutarTheme t,
    required Color badgeBg,
    required CustomPainter badgePainter,
    required String label,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          // Lingkaran Status 28x28
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
              border: Border.all(color: t.ink, width: 2.5),
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(15, 15),
              painter: badgePainter,
            ),
          ),
          const SizedBox(width: 8),

          // Label Pill 104px
          Container(
            width: 104,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: t.ink, width: 2.0),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: t.buttonSmall.copyWith(
                fontSize: 12,
                fontWeight: t.weightExtraBold,
                color: t.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Deskripsi
          Expanded(
            child: Text(
              description,
              style: t.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: t.weightMedium,
                color: t.ink,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
