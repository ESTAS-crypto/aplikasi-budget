import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/rupiah_formatter.dart';
import '../models/group_event_model.dart';
import '../painters/group_icons_painter.dart';

/// Neo-Brutalist ActivityTile (Layar 20: Grup5.dc.html)
/// Mendukung 2 mode tampilan:
/// 1. BARU (isUnread == true): Kartu tebal radius 22, border 3px ink, shadow 4px,
///    badge "Baru" di pojok kanan atas, avatar 42x42 dengan badge lencana 20x20 di pojok kanan bawah,
///    judul aksi, subjudul deskripsi jajan/budget, dan baris chips (nominal, sisa, waktu + ikon jam).
/// 2. SEBELUMNYA (isUnread == false): Kartu ringkas radius 18, border 3px ink, shadow 2px,
///    avatar 34x34, teks tebal/medium, dan chip waktu di sisi kanan.
class ActivityTile extends StatelessWidget {
  final GroupEventModel event;
  final bool isUnread;
  final int colorIndex;
  final bool isMe;
  final VoidCallback? onTap;

  const ActivityTile({
    super.key,
    required this.event,
    required this.isUnread,
    this.colorIndex = 0,
    this.isMe = false,
    this.onTap,
  });

  static const List<Color> _avatarColors = [
    Color(0xFF6FB1FF), // Langit
    Color(0xFFB8E986), // Lime
    Color(0xFFFF8FC0), // Merah Muda
    Color(0xFFFFD23F), // Matahari
    Color(0xFFB8A4FF), // Lavender
    Color(0xFFFF6B5A), // Tomat
  ];

  Color _getAvatarBg(int idx) {
    return _avatarColors[idx % _avatarColors.length];
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mnt lalu';
    } else if (difference.inHours < 24 && now.day == dt.day) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 2) {
      return 'Kemarin';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = isMe ? 'Kamu' : event.actorName;
    final initialLetter = (isMe ? 'K' : (event.actorName.isNotEmpty ? event.actorName[0] : 'A')).toUpperCase();
    final avatarBg = _getAvatarBg(colorIndex);

    final rawSummary = (event.summary != null && event.summary!.isNotEmpty)
        ? event.summary!
        : event.formattedSummary;

    final displaySummary = (isMe && rawSummary.startsWith(event.actorName))
        ? 'Kamu${rawSummary.substring(event.actorName.length)}'
        : rawSummary;

    final card = isUnread
        ? _buildBaruCard(actor, initialLetter, avatarBg, displaySummary)
        : _buildSebelumnyaCard(actor, initialLetter, avatarBg, displaySummary);

    return Semantics(
      container: true,
      button: onTap != null,
      label: 'Aktivitas ${isUnread ? "baru: " : ""}$displaySummary',
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: card,
            )
          : card,
    );
  }

  /// 1. Tampilan Kartu BARU (Layar 20: Grup5.dc.html)
  Widget _buildBaruCard(String actor, String initial, Color avatarBg, String displaySummary) {
    final String subtitle;
    int? nominal;
    int? remaining;
    Color nominalBg = AppColors.matahari;
    CustomPainter lencanaPainter = const CustomReceiptPainter(color: AppColors.ink, strokeWidth: 2.2);

    switch (event.type) {
      case GroupEventType.expense:
      case GroupEventType.expenseDeleted:
        final isDeleted = event.type == GroupEventType.expenseDeleted ||
            event.payload['deleted'] == true;
        if (isDeleted) {
          subtitle = event.payload['title'] ?? 'pengeluaran';
          lencanaPainter = const CustomTrashPainter(color: AppColors.ink, strokeWidth: 2.2);
        } else {
          subtitle = event.payload['title'] ?? 'pengeluaran';
          lencanaPainter = const CustomReceiptPainter(color: AppColors.ink, strokeWidth: 2.2);
        }
        nominal = (event.payload['amount'] as num?)?.toInt();
        remaining = (event.payload['remaining'] as num?)?.toInt();
        nominalBg = AppColors.matahari;
        break;

      case GroupEventType.spin:
        subtitle = 'Budget baru untuk sesi ini';
        nominal = (event.payload['budget'] as num?)?.toInt();
        nominalBg = AppColors.lavender;
        lencanaPainter = const CustomWheelPainter(color: AppColors.ink, strokeWidth: 2.2);
        break;

      case GroupEventType.memberJoin:
        subtitle = 'Siap jajan bareng';
        lencanaPainter = const CustomUserPlusPainter(color: AppColors.ink, strokeWidth: 2.2);
        break;

      case GroupEventType.memberLeave:
        subtitle = 'Sampai jumpa di lain kesempatan';
        lencanaPainter = const CustomUserMinusPainter(color: AppColors.ink, strokeWidth: 2.2);
        break;

      case GroupEventType.sessionStart:
        subtitle = 'Putar roda dan catat jajan!';
        lencanaPainter = const CustomFlagPainter(color: AppColors.ink, strokeWidth: 2.2);
        break;

      case GroupEventType.sessionEnd:
        subtitle = 'Sesi date grup telah selesai';
        lencanaPainter = const CustomFlagPainter(color: AppColors.ink, strokeWidth: 2.2);
        break;

      case GroupEventType.custom:
        subtitle = 'Pengaturan roda diperbarui';
        lencanaPainter = const CustomGearPainter(color: AppColors.ink);
        break;

      case GroupEventType.budgetChanged:
        subtitle = 'Pengaturan budget diperbarui';
        lencanaPainter = const CustomGearPainter(color: AppColors.ink);
        break;

      case GroupEventType.codeChanged:
        subtitle = 'Kode undangan diperbarui';
        lencanaPainter = const CustomGearPainter(color: AppColors.ink);
        break;

      case GroupEventType.gameResult:
        final game = event.payload['game'] ?? 'permainan';
        final gameLabel = GroupEventModel.formatGameName(game.toString());
        subtitle = 'Hasil $gameLabel untuk budget date';
        nominal = (event.payload['amount'] as num?)?.toInt();
        nominalBg = AppColors.lavender;
        lencanaPainter = const CustomWheelPainter(color: AppColors.ink, strokeWidth: 2.2);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Container Kartu Utama
          Container(
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Bulat 42x42 dengan Lencana 20x20 di kanan bawah
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: avatarBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: AppTypography.displayMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.ink, width: 2.5),
                          ),
                          alignment: Alignment.center,
                          child: CustomPaint(
                            size: const Size(11, 11),
                            painter: lencanaPainter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Kolom Konten
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul Aksi (Nama Bold)
                      Text(
                        displaySummary,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Subjudul Deskripsi
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B4B7A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),

                      // Baris Chips Neo-Brutalist
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (nominal != null && nominal > 0)
                            _buildChip(
                              text: RupiahFormatter.format(nominal),
                              backgroundColor: nominalBg,
                            ),
                          if (remaining != null)
                            _buildChip(
                              text: 'Sisa ${RupiahFormatter.format(remaining)}',
                              backgroundColor: AppColors.mint,
                            ),
                          _buildChip(
                            text: _formatRelativeTime(event.createdAt),
                            backgroundColor: Colors.white,
                            leading: const Padding(
                              padding: EdgeInsets.only(right: 3),
                              child: CustomPaint(
                                size: Size(11, 11),
                                painter: CustomClockPainter(
                                  color: AppColors.ink,
                                  strokeWidth: 2.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lencana "Baru" di pojok kanan atas
          Positioned(
            right: 12,
            top: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.tomat,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: Text(
                'Baru',
                style: AppTypography.buttonSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Tampilan Kartu SEBELUMNYA (Layar 20: Grup5.dc.html)
  Widget _buildSebelumnyaCard(String actor, String initial, Color avatarBg, String displaySummary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink, width: 3.0),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar Ringkas 34x34
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 3.0),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Teks Ringkasan Aktivitas
            Expanded(
              child: Text(
                displaySummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Chip Waktu di Kanan
            _buildChip(
              text: _formatRelativeTime(event.createdAt),
              backgroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String text,
    required Color backgroundColor,
    Widget? leading,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.ink, width: 2.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?leading,
          Text(
            text,
            style: AppTypography.buttonSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
