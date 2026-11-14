import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
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

  Color _getAvatarBg(PutarTheme t, int idx) {
    final colors = t.memberAvatarColors;
    return colors[idx % colors.length];
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
    final t = context.putarTheme;
    final initialLetter = (isMe ? 'K' : (event.actorName.isNotEmpty ? event.actorName[0] : 'A')).toUpperCase();
    final avatarBg = _getAvatarBg(t, colorIndex);

    final rawSummary = (event.summary != null && event.summary!.isNotEmpty)
        ? event.summary!
        : event.formattedSummary;

    final displaySummary = (isMe && rawSummary.startsWith(event.actorName))
        ? 'Kamu${rawSummary.substring(event.actorName.length)}'
        : rawSummary;

    final visuals = _resolveVisuals(t);

    final card = isUnread
        ? _buildBaruCard(t, visuals, initialLetter, avatarBg, displaySummary)
        : _buildSebelumnyaCard(t, visuals, initialLetter, avatarBg, displaySummary);

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

  _EventVisualData _resolveVisuals(PutarTheme t) {
    switch (event.type) {
      case GroupEventType.expense:
      case GroupEventType.expenseDeleted:
        final isDeleted = event.type == GroupEventType.expenseDeleted ||
            event.payload['deleted'] == true;
        final isEdited = !isDeleted && event.payload['edited'] == true;
        final noteTitle = event.payload['title']?.toString() ?? 'pengeluaran';
        return _EventVisualData(
          subtitle: isDeleted
              ? 'Dihapus: $noteTitle'
              : (isEdited ? 'Diubah: $noteTitle' : noteTitle),
          categoryLabel: isDeleted ? 'Dihapus' : (isEdited ? 'Diubah' : 'Catatan'),
          categoryBg: isDeleted
              ? t.danger.withValues(alpha: 0.25)
              : t.secondary,
          nominal: (event.payload['amount'] as num?)?.toInt(),
          nominalBg: t.secondary,
          remaining: (event.payload['remaining'] as num?)?.toInt(),
          lencanaPainter: isDeleted
              ? CustomTrashPainter(color: t.ink, strokeWidth: 2.2)
              : CustomReceiptPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.spin:
        return _EventVisualData(
          subtitle: 'Budget baru untuk date ini',
          categoryLabel: 'Roda Putar',
          categoryBg: t.accentPurple,
          nominal: (event.payload['budget'] as num?)?.toInt(),
          nominalBg: t.accentPurple,
          lencanaPainter: CustomWheelPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.gameResult:
        final game = event.payload['game']?.toString() ?? 'permainan';
        final gameLabel = GroupEventModel.formatGameName(game);
        final isValid = event.payload['valid'] != false;
        return _EventVisualData(
          subtitle: isValid
              ? 'Hasil $gameLabel · budget date'
              : '$gameLabel · tidak dipakai untuk budget',
          categoryLabel: gameLabel,
          categoryBg: isValid
              ? t.accentPurple
              : t.textDisabled.withValues(alpha: 0.25),
          nominal: (event.payload['amount'] as num?)?.toInt(),
          nominalBg: isValid
              ? t.accentPurple
              : t.textDisabled.withValues(alpha: 0.25),
          statusLabel: isValid ? null : 'Tidak berlaku',
          statusBg: t.danger.withValues(alpha: 0.25),
          lencanaPainter: CustomWheelPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.memberJoin:
        return _EventVisualData(
          subtitle: 'Siap jajan bareng',
          categoryLabel: 'Gabung',
          categoryBg: t.success,
          lencanaPainter: CustomUserPlusPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.memberLeave:
        return _EventVisualData(
          subtitle: 'Sampai jumpa di lain kesempatan',
          categoryLabel: 'Keluar',
          categoryBg: t.surface,
          lencanaPainter: CustomUserMinusPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.sessionStart:
        final mode = event.payload['mode']?.toString();
        return _EventVisualData(
          subtitle: mode == 'fixed'
              ? 'Date dimulai dengan budget tetap'
              : 'Putar roda dan catat jajan!',
          categoryLabel: 'Mulai Date',
          categoryBg: t.success,
          nominal: (event.payload['budget'] as num?)?.toInt(),
          nominalBg: t.success,
          lencanaPainter: CustomFlagPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.sessionEnd:
        final status = event.payload['status']?.toString().toLowerCase() ?? 'lolos';
        final isLewat = status == 'lewat';
        final totalSpent = (event.payload['totalSpent'] as num?)?.toInt();
        final budget = (event.payload['budget'] as num?)?.toInt();
        return _EventVisualData(
          subtitle: (budget != null && budget > 0)
              ? '${isLewat ? "Overbudget" : "Hemat"} · Budget ${RupiahFormatter.format(budget)}'
              : 'Sesi date grup telah selesai',
          categoryLabel: 'Date Selesai',
          categoryBg: isLewat
              ? t.danger.withValues(alpha: 0.25)
              : t.success,
          nominal: totalSpent,
          nominalText: totalSpent != null
              ? 'Terpakai ${RupiahFormatter.format(totalSpent)}'
              : null,
          nominalBg: t.secondary,
          statusLabel: isLewat ? 'Lewat' : 'Lolos',
          statusBg: isLewat
              ? t.danger.withValues(alpha: 0.25)
              : t.success,
          lencanaPainter: CustomFlagPainter(color: t.ink, strokeWidth: 2.2),
        );

      case GroupEventType.budgetChanged:
        final mode = event.payload['mode']?.toString();
        final fixedBudget = (event.payload['fixedBudget'] as num?)?.toInt();
        return _EventVisualData(
          subtitle: mode == 'fixed'
              ? 'Mode budget tetap diaktifkan'
              : (mode == 'game'
                  ? 'Mode budget permainan diaktifkan'
                  : 'Pengaturan budget diperbarui'),
          categoryLabel: 'Budget',
          categoryBg: t.accentPurple,
          nominal: (mode == 'fixed' && fixedBudget != null && fixedBudget > 0)
              ? fixedBudget
              : null,
          nominalBg: t.accentPurple,
          lencanaPainter: CustomGearPainter(color: t.ink),
        );

      case GroupEventType.codeChanged:
        final newCode = event.payload['code']?.toString();
        return _EventVisualData(
          subtitle: (newCode != null && newCode.isNotEmpty)
              ? 'Kode undangan baru: $newCode'
              : 'Kode undangan diperbarui',
          categoryLabel: 'Undangan',
          categoryBg: t.surface,
          lencanaPainter: CustomGearPainter(color: t.ink),
        );

      case GroupEventType.custom:
        if (event.payload['action'] == 'session_result_updated') {
          final status = event.payload['status']?.toString().toLowerCase() ?? 'lolos';
          final isLewat = status == 'lewat';
          final totalSpent = (event.payload['totalSpent'] as num?)?.toInt();
          return _EventVisualData(
            subtitle: event.summary ??
                'Hasil date diperbarui setelah sinkronisasi catatan offline',
            categoryLabel: 'Hasil Diperbarui',
            categoryBg: isLewat
                ? t.danger.withValues(alpha: 0.25)
                : t.success,
            nominal: totalSpent,
            nominalText: totalSpent != null
                ? 'Terpakai ${RupiahFormatter.format(totalSpent)}'
                : null,
            nominalBg: t.secondary,
            statusLabel: isLewat ? 'Lewat' : 'Lolos',
            statusBg: isLewat
                ? t.danger.withValues(alpha: 0.25)
                : t.success,
            lencanaPainter:
                CustomFlagPainter(color: t.ink, strokeWidth: 2.2),
          );
        }
        final isWheelSlots = event.payload['action'] == 'update_slots' ||
            event.payload['wheelSlots'] != null;
        return _EventVisualData(
          subtitle: isWheelSlots
              ? 'Daftar nominal roda diperbarui'
              : (event.payload['subtitle']?.toString() ?? 'Pengaturan grup diperbarui'),
          categoryLabel: isWheelSlots ? 'Slot Roda' : 'Grup',
          categoryBg: t.accentPurple,
          lencanaPainter: CustomGearPainter(color: t.ink),
        );
    }
  }

  List<Widget> _buildDetailChips(
    PutarTheme t,
    _EventVisualData visuals, {
    required bool includeCategory,
  }) {
    final chips = <Widget>[];
    if (includeCategory) {
      chips.add(_buildChip(
        t,
        text: visuals.categoryLabel,
        backgroundColor: visuals.categoryBg,
      ));
    }
    if (visuals.nominalText != null) {
      chips.add(_buildChip(
        t,
        text: visuals.nominalText!,
        backgroundColor: visuals.nominalBg ?? t.secondary,
      ));
    } else if (visuals.nominal != null &&
        (visuals.nominal! > 0 || event.type == GroupEventType.gameResult)) {
      chips.add(_buildChip(
        t,
        text: RupiahFormatter.format(visuals.nominal!),
        backgroundColor: visuals.nominalBg ?? t.secondary,
      ));
    }
    if (visuals.remaining != null) {
      chips.add(_buildChip(
        t,
        text: 'Sisa ${RupiahFormatter.format(visuals.remaining!)}',
        backgroundColor: visuals.remaining! < 0
            ? t.danger.withValues(alpha: 0.25)
            : t.success,
      ));
    }
    if (visuals.statusLabel != null) {
      chips.add(_buildChip(
        t,
        text: visuals.statusLabel!,
        backgroundColor: visuals.statusBg ?? t.success,
      ));
    }
    return chips;
  }

  /// 1. Tampilan Kartu BARU (Layar 20: Grup5.dc.html)
  Widget _buildBaruCard(
    PutarTheme t,
    _EventVisualData visuals,
    String initial,
    Color avatarBg,
    String displaySummary,
  ) {
    final detailChips = _buildDetailChips(t, visuals, includeCategory: false);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Container Kartu Utama
          Container(
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
                          border: Border.all(color: t.ink, width: t.borderWidth),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: t.displayMedium.copyWith(
                            fontSize: 16,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
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
                            color: t.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.ink, width: 2.5),
                          ),
                          alignment: Alignment.center,
                          child: CustomPaint(
                            size: const Size(11, 11),
                            painter: visuals.lencanaPainter,
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
                        style: t.bodyMedium.copyWith(
                          fontSize: 14,
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Subjudul Deskripsi
                      Text(
                        visuals.subtitle,
                        style: t.bodySmall.copyWith(
                          fontSize: 13,
                          fontWeight: t.weightSemiBold,
                          color: t.textSecondary,
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
                          ...detailChips,
                          _buildChip(
                            t,
                            text: _formatRelativeTime(event.createdAt),
                            backgroundColor: t.surface,
                            leading: Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: CustomPaint(
                                size: const Size(11, 11),
                                painter: CustomClockPainter(
                                  color: t.ink,
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
                color: t.danger,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: t.ink, width: 2.5),
              ),
              child: Text(
                'Baru',
                style: t.buttonSmall.copyWith(
                  fontSize: 11,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Tampilan Kartu SEBELUMNYA (Layar 20: Grup5.dc.html)
  Widget _buildSebelumnyaCard(
    PutarTheme t,
    _EventVisualData visuals,
    String initial,
    Color avatarBg,
    String displaySummary,
  ) {
    final detailChips = _buildDetailChips(t, visuals, includeCategory: true);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.smallCardRadius),
          border: Border.all(color: t.ink, width: t.borderWidth),
          boxShadow: [
            BoxShadow(
              color: t.ink,
              offset: t.miniShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Ringkas 34x34
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
                border: Border.all(color: t.ink, width: t.borderWidth),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: t.displayMedium.copyWith(
                  fontSize: 14,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Teks Ringkasan Aktivitas + Chips Detail
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          displaySummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: t.weightBold,
                            color: t.ink,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        t,
                        text: _formatRelativeTime(event.createdAt),
                        backgroundColor: t.surface,
                      ),
                    ],
                  ),
                  if (detailChips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: detailChips,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    PutarTheme t, {
    required String text,
    required Color backgroundColor,
    Widget? leading,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.ink, width: 2.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?leading,
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.buttonSmall.copyWith(
                fontSize: 12,
                fontWeight: t.weightBold,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventVisualData {
  final String subtitle;
  final String categoryLabel;
  final Color categoryBg;
  final int? nominal;
  final String? nominalText;
  final Color? nominalBg;
  final int? remaining;
  final String? statusLabel;
  final Color? statusBg;
  final CustomPainter lencanaPainter;

  const _EventVisualData({
    required this.subtitle,
    required this.categoryLabel,
    required this.categoryBg,
    this.nominal,
    this.nominalText,
    this.nominalBg,
    this.remaining,
    this.statusLabel,
    this.statusBg,
    required this.lencanaPainter,
  });
}
