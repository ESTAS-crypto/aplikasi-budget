import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Arti status sinkron',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        _buildStatusRow(
          badgeBg: AppColors.mint, // #3DDBB0
          badgePainter: const CustomCheckPainter(color: AppColors.ink, strokeWidth: 2.8),
          label: 'Tersinkron',
          description: 'Semua anggota sudah menerimanya',
        ),
        _buildStatusRow(
          badgeBg: AppColors.cream, // #FFF3D6
          badgePainter: const CustomClockPainter(color: AppColors.ink, strokeWidth: 2.8),
          label: 'Menunggu',
          description: 'Tersimpan di HP, belum terkirim',
        ),
        _buildStatusRow(
          badgeBg: AppColors.matahari, // #FFD23F
          badgePainter: const CustomSyncArrowsPainter(color: AppColors.ink, strokeWidth: 2.8),
          label: 'Menyinkronkan',
          description: 'Sedang dikirim',
        ),
        _buildStatusRow(
          badgeBg: AppColors.ink, // #22163A
          badgePainter: const CustomCloudOfflinePainter(color: Colors.white, strokeWidth: 2.8),
          label: 'Offline',
          description: 'Perubahan baru disimpan di HP',
        ),
        _buildStatusRow(
          badgeBg: AppColors.tomat, // #FF6B5A
          badgePainter: const CustomWarningTrianglePainter(color: AppColors.ink, strokeWidth: 2.8),
          label: 'Gagal',
          description: 'Ketuk untuk coba lagi',
        ),
      ],
    );

    if (!isCard) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink, width: 3.0),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildStatusRow({
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
              border: Border.all(color: AppColors.ink, width: 2.5),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.ink, width: 2.0),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.buttonSmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Deskripsi
          Expanded(
            child: Text(
              description,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
