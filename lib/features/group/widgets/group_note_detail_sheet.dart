import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/indonesian_date_formatter.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/sticker_snackbar.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_note_model.dart';
import '../../../core/group/models/group_history_models.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/widgets/sync_badge.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../screens/group_date_detail_screen.dart';

/// Menampilkan Layar 66 (`Rgrup5.dc.html`): Bottom Sheet Detail Satu Catatan
/// di atas Layar 64 (Tab Catatan) dengan scrim `#22163A` 50%,
/// animasi masuk `cubic-bezier(.2, 1.1, .3, 1)` 450ms dan keluar 250ms
/// (atau fade 100ms tanpa mantul bila `MediaQuery.disableAnimations` aktif).
Future<bool?> showGroupNoteDetailSheet({
  required BuildContext context,
  required String gid,
  required GroupNoteWithRemaining initialItem,
  required GroupSessionModel session,
  required GroupModel? group,
  required String authorDisplayName,
  required Color authorAvatarColor,
}) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);

  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Tutup latar',
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
      transitionDuration: Duration(milliseconds: disableAnimations ? 100 : 450),
      reverseTransitionDuration: Duration(
        milliseconds: disableAnimations ? 100 : 250,
      ),
      pageBuilder: (routeContext, animation, secondaryAnimation) {
        return GroupNoteDetailSheet(
          gid: gid,
          initialItem: initialItem,
          session: session,
          group: group,
          authorDisplayName: authorDisplayName,
          authorAvatarColor: authorAvatarColor,
        );
      },
      transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
        if (disableAnimations) {
          return FadeTransition(opacity: animation, child: child);
        }
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.2, 1.1, 0.3, 1.0),
            reverseCurve: Curves.easeInCubic,
          ),
        );
        return SlideTransition(position: slideAnimation, child: child);
      },
    ),
  );
}

/// Layar 66 (`Rgrup5.dc.html`): Detail satu catatan (bottom sheet di atas layar 64)
class GroupNoteDetailSheet extends ConsumerStatefulWidget {
  final String gid;
  final GroupNoteWithRemaining initialItem;
  final GroupSessionModel session;
  final GroupModel? group;
  final String authorDisplayName;
  final Color authorAvatarColor;

  const GroupNoteDetailSheet({
    super.key,
    required this.gid,
    required this.initialItem,
    required this.session,
    required this.group,
    required this.authorDisplayName,
    required this.authorAvatarColor,
  });

  @override
  ConsumerState<GroupNoteDetailSheet> createState() =>
      _GroupNoteDetailSheetState();
}

class _GroupNoteDetailSheetState extends ConsumerState<GroupNoteDetailSheet> {
  Future<void> _handleEdit({
    required GroupNoteModel note,
    required GroupSessionModel session,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditGroupNoteBottomSheet(
        gid: widget.gid,
        note: note,
        sessionBudget: session.budget,
      ),
    );
  }

  Future<void> _handleDelete({
    required GroupNoteModel note,
    required GroupSessionModel session,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final confirmed = await GroupImportantDialog.showConfirmDeleteNote(
      context,
      title: note.title,
      formattedAmount: RupiahFormatter.format(note.amount),
    );

    if (confirmed != true || !mounted) return;

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.deleteNote(
        gid: widget.gid,
        noteId: note.noteId,
        title: note.title,
        amount: note.amount,
        sessionBudget: session.budget,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showStickerSnackbar(
          context,
          message: 'Gagal menghapus catatan',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupService = ref.watch(groupServiceProvider);
    final authService = ref.watch(groupAuthServiceProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final effectiveGroup = activeGroupAsync.valueOrNull ??
        widget.group ??
        groupService.getLocalGroup(widget.gid);

    final sessionsAsync = ref.watch(activeGroupSessionsStreamProvider);
    final streamedSessions = sessionsAsync.valueOrNull ?? [];
    final localSessions = groupService.getLocalSessions(widget.gid);
    final allSessions = <String, GroupSessionModel>{
      for (final s in localSessions) s.sessionId: s,
      for (final s in streamedSessions) s.sessionId: s,
    };
    final effectiveSession =
        allSessions[widget.session.sessionId] ?? widget.session;

    final notesAsync = ref.watch(
      groupSessionNotesStreamProvider(effectiveSession.sessionId),
    );
    final localNotes = groupService
        .getLocalNotes(widget.gid)
        .where((n) => n.sessionId == effectiveSession.sessionId)
        .toList();
    final streamedNotes = notesAsync.valueOrNull ?? [];
    final notesMap = <String, GroupNoteModel>{
      for (final n in localNotes) n.noteId: n,
      for (final n in streamedNotes) n.noteId: n,
    };
    final liveItems = GroupHistoryCalculator.computeNotesWithRemaining(
      budget: effectiveSession.budget,
      notes: notesMap.values.toList(),
    );

    GroupNoteWithRemaining currentItem = widget.initialItem;
    if (liveItems.isNotEmpty) {
      final matchIdx = liveItems.indexWhere(
        (e) => e.note.noteId == widget.initialItem.note.noteId,
      );
      if (matchIdx != -1) {
        currentItem = liveItems[matchIdx];
      }
    }

    final note = currentItem.note;
    final myUid = authService.currentUid ?? '';
    final canModify = groupService.canModifyNote(
      group: effectiveGroup,
      note: note,
      userUid: myUid,
    );

    // Nama pembuat pada keterangan izin sesuai Rgrup5.dc.html ("Hanya Dina dan pemilik grup...")
    final rawAuthorName = note.authorName.trim();
    final captionAuthorName =
        rawAuthorName.isNotEmpty ? rawAuthorName : widget.authorDisplayName;

    final shortMonth = IndonesianDateFormatter.months[
        (effectiveSession.startedAt.month - 1).clamp(0, 11)];
    final dateShort = '${effectiveSession.startedAt.day} $shortMonth';
    final sequenceSubtitle =
        'Catatan ${currentItem.sequenceNumber} dari ${currentItem.totalNotes} · Date $dateShort';
    final timeFormatted =
        '${IndonesianDateFormatter.fullDayAndDate(note.createdAt)} · ${GroupDateDetailScreen.formatDotTime(note.createdAt)}';
    final statusSubtext = note.hasPendingWrites
        ? 'menunggu'
        : 'semua anggota menerima';

    final remainingFraction = currentItem.remainingFraction(
      effectiveSession.budget,
    );
    final remainingBarColor = currentItem.remainingAfter >= 0
        ? AppColors.mint
        : AppColors.tomat;

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Semantics(
            container: true,
            label:
                'Detail catatan ${note.title}, jumlah ${RupiahFormatter.format(note.amount)}, dicatat oleh ${widget.authorDisplayName}, waktu $timeFormatted, status ${note.hasPendingWrites ? "Menunggu" : "Terkirim"} $statusSubtext, sisa budget setelahnya ${RupiahFormatter.format(currentItem.remainingAfter)}',
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                18 + (bottomPadding > 0 ? bottomPadding : 0),
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: AppColors.ink, width: 3),
                  left: BorderSide(color: AppColors.ink, width: 3),
                  right: BorderSide(color: AppColors.ink, width: 3),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Grabber (46x5, radius 3, #22163A opacity 0.3)
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // 2. Baris Header: Ikon struk bulat + Judul & "Catatan n dari N · Date ..." + Tombol Tutup
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: widget.authorAvatarColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.ink, width: 3),
                          ),
                          alignment: Alignment.center,
                          child: const CustomPaint(
                            size: Size(16, 16),
                            painter: CustomReceiptPainter(
                              color: AppColors.ink,
                              strokeWidth: 2.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                note.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sequenceSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF5B4B7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          label: 'Tutup',
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              SoundService.instance.play(Sfx.uiTap);
                              Navigator.of(context).pop(false);
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: 3,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const CustomPaint(
                                size: Size(18, 18),
                                painter: CustomCrossPainter(
                                  color: AppColors.ink,
                                  strokeWidth: 3.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 3. Jumlah Besar (Rp30.000, 38px w800)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          RupiahFormatter.format(note.amount),
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),

                    // 4. Baris Metadata 1: Dicatat oleh
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.ink.withValues(alpha: 0.133),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dicatat oleh',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5B4B7A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GroupCircleAvatar(
                                  name: widget.authorDisplayName,
                                  color: widget.authorAvatarColor,
                                  size: 26,
                                  fontSize: 12,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.authorDisplayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5. Baris Metadata 2: Waktu
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.ink.withValues(alpha: 0.133),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Waktu',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5B4B7A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              timeFormatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 6. Baris Metadata 3: Status (SyncBadge + "semua anggota menerima" / "menunggu")
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.ink.withValues(alpha: 0.133),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5B4B7A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SyncBadge(
                                    hasPendingWrites: note.hasPendingWrites,
                                    pill: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    statusSubtext,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF5B4B7A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 7. Bar "Sisa budget setelahnya"
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Sisa budget setelahnya',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF5B4B7A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                RupiahFormatter.format(
                                  currentItem.remainingAfter,
                                ),
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: AppColors.ink,
                                width: 2.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0.0,
                                end: remainingFraction,
                              ),
                              duration: Duration(
                                milliseconds: disableAnimations ? 100 : 500,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, _) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: val.clamp(0.0, 1.0),
                                  child: Container(
                                    color: remainingBarColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 8. Tombol Ubah & Hapus HANYA untuk pembuat catatan dan pemilik grup
                    if (canModify) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: 'Ubah catatan',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _handleEdit(
                                  note: note,
                                  session: effectiveSession,
                                ),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(23),
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.ink,
                                        offset: Offset(3, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Ubah',
                                    style: AppTypography.buttonSmall.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Semantics(
                              label: 'Hapus catatan',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _handleDelete(
                                  note: note,
                                  session: effectiveSession,
                                ),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.tomat,
                                    borderRadius: BorderRadius.circular(23),
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.ink,
                                        offset: Offset(3, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Hapus',
                                    style: AppTypography.buttonSmall.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 9. Keterangan izin
                    const SizedBox(height: 8),
                    Text(
                      'Hanya $captionAuthorName dan pemilik grup yang bisa mengubah atau menghapus.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5B4B7A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// BottomSheet Formulir Ubah Catatan Pengeluaran Grup (menggunakan gaya formulir catatan grup yang sudah ada)
class EditGroupNoteBottomSheet extends ConsumerStatefulWidget {
  final String gid;
  final GroupNoteModel note;
  final int sessionBudget;

  const EditGroupNoteBottomSheet({
    super.key,
    required this.gid,
    required this.note,
    required this.sessionBudget,
  });

  @override
  ConsumerState<EditGroupNoteBottomSheet> createState() =>
      _EditGroupNoteBottomSheetState();
}

class _EditGroupNoteBottomSheetState
    extends ConsumerState<EditGroupNoteBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _amountController = TextEditingController(
      text: RupiahFormatter.format(widget.note.amount),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _formatNominal(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      _amountController.value = const TextEditingValue(text: '');
      return;
    }
    final number = int.tryParse(clean) ?? 0;
    final formatted = RupiahFormatter.format(number);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(rawAmount) ?? 0;

    if (title.isEmpty) {
      showStickerSnackbar(context, message: 'Masukkan nama pengeluaran');
      return;
    }
    if (amount <= 0) {
      showStickerSnackbar(
        context,
        message: 'Masukkan nominal belanja yang valid',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateNote(
        gid: widget.gid,
        noteId: widget.note.noteId,
        newTitle: title,
        newAmount: amount,
        sessionBudget: widget.sessionBudget,
      );

      SoundService.instance.play(Sfx.coinRecord);
      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showStickerSnackbar(context, message: 'Gagal menyimpan perubahan');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.ink, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Ubah Catatan Grup',
                    style: AppTypography.titleMedium.copyWith(fontSize: 18),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    Navigator.pop(context, false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: const CustomPaint(
                      size: Size(16, 16),
                      painter: CustomCrossPainter(
                        color: AppColors.ink,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nama Barang
            TextField(
              key: const ValueKey('edit_group_note_title_field'),
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nama barang / jajanan',
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.ink,
                    width: 2.5,
                  ),
                ),
              ),
              style: AppTypography.bodyLargeBold.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),

            // Nominal Rupiah
            TextField(
              key: const ValueKey('edit_group_note_amount_field'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: _formatNominal,
              decoration: InputDecoration(
                hintText: 'Rp 0',
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.ink,
                    width: 2.5,
                  ),
                ),
              ),
              style: AppTypography.displayMedium.copyWith(
                fontSize: 24,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),

            StickerButton(
              text: _isSaving ? 'Menyimpan...' : 'Simpan Pengeluaran',
              backgroundColor: AppColors.matahari,
              height: 50,
              onPressed: _isSaving ? null : _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
