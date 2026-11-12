import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sticker_card.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/sticker_snackbar.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_note_model.dart';
import '../../../core/group/models/group_event_model.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/services/group_game_service.dart';
import '../../../core/group/sync/sync_state.dart';
import '../../../core/group/widgets/sync_strip.dart';
import '../../../core/group/widgets/sync_badge.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/group/widgets/member_avatar.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../../navigation/app_router.dart';

/// Layar 19: Catatan Pengeluaran Grup Bersama
/// Menampilkan sisa budget deterministik append-only, badge sinkron, dan mode offline penuh
class GroupNotesView extends ConsumerStatefulWidget {
  final bool autoOpenAdd;
  const GroupNotesView({super.key, this.autoOpenAdd = false});

  @override
  ConsumerState<GroupNotesView> createState() => _GroupNotesViewState();
}

class _GroupNotesViewState extends ConsumerState<GroupNotesView> {
  bool _didAutoOpen = false;

  void _checkAutoOpen(GroupModel group) {
    if (widget.autoOpenAdd && !_didAutoOpen && group.activeSession != null) {
      _didAutoOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openAddExpenseSheet(
            group.id,
            group.activeSession!.sessionId,
            group.activeSession!.budget,
          );
        }
      });
    }
  }

  void _openAddExpenseSheet(String gid, String sessionId, int sessionBudget) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddGroupExpenseBottomSheet(
        gid: gid,
        sessionId: sessionId,
        sessionBudget: sessionBudget,
      ),
    );
  }

  Future<void> _handleDeleteNote({
    required String gid,
    required GroupNoteModel note,
    required int sessionBudget,
  }) async {
    final confirmed = await GroupImportantDialog.showConfirmDeleteNote(
      context,
      title: note.title,
      formattedAmount: RupiahFormatter.format(note.amount),
    );

    if (confirmed == true) {
      try {
        final groupService = ref.read(groupServiceProvider);
        await groupService.deleteNote(
          gid: gid,
          noteId: note.noteId,
          title: note.title,
          amount: note.amount,
          sessionBudget: sessionBudget,
        );
      } catch (e) {
        if (mounted) {
          showStickerSnackbar(context, message: 'Gagal menghapus catatan');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final streamedGroup = activeGroupAsync.valueOrNull;
    final localGroup = (activeGroupId != null && activeGroupId.isNotEmpty)
        ? ref.read(groupServiceProvider).getLocalGroup(activeGroupId)
        : null;

    final resolvedSession = (activeGroupId != null && activeGroupId.isNotEmpty)
        ? ref.read(groupServiceProvider).resolveEffectiveSession(
              activeGroupId,
              streamedGroup?.activeSession,
              localGroup?.activeSession,
            )
        : (streamedGroup?.activeSession ?? localGroup?.activeSession);

    GroupModel? rawGroup = (streamedGroup != null || localGroup != null)
        ? (streamedGroup ?? localGroup)!.copyWith(
            activeSession: resolvedSession,
            clearActiveSession: resolvedSession == null,
          )
        : null;

    // Pemulihan Sesi Mandiri (Failsafe): Jika activeSession bernilai null karena delay stream
    // tetapi ada event putaran roda / game result yang valid di log lokal grup (dan belum diakhiri), pulihkan sesi seketika!
    if (rawGroup != null && rawGroup.activeSession == null && activeGroupId != null && activeGroupId.isNotEmpty) {
      final groupService = ref.read(groupServiceProvider);
      final evts = groupService.getLocalEvents(activeGroupId);
      for (final evt in evts) {
        if (evt.payload['action'] == 'end_session') break;
        if ((evt.type == GroupEventType.gameResult || evt.type == GroupEventType.spin) &&
            evt.payload['valid'] != false &&
            (evt.payload['amount'] != null || evt.payload['budget'] != null)) {
          final amt = ((evt.payload['amount'] ?? evt.payload['budget']) as num).toInt();
          final sessId = evt.payload['sessionId']?.toString() ??
              'sess_${evt.createdAt.millisecondsSinceEpoch}';
          final gm = evt.payload['game']?.toString() ?? 'wheel';
          final recoveredSession = GroupSessionModel(
            sessionId: sessId,
            budget: amt,
            game: gm,
            startedByUid: evt.actorUid,
            startedByName: evt.actorName,
            startedAt: evt.createdAt,
          );
          if (!groupService.isSessionEnded(activeGroupId, recoveredSession)) {
            rawGroup = rawGroup!.copyWith(activeSession: recoveredSession);
            groupService.saveLocalGroup(rawGroup);
          }
          break;
        } else if (evt.type == GroupEventType.sessionStart && evt.payload['budget'] != null) {
          final amt = (evt.payload['budget'] as num).toInt();
          final sessId = evt.payload['sessionId']?.toString() ??
              'sess_${evt.createdAt.millisecondsSinceEpoch}';
          final recoveredSession = GroupSessionModel(
            sessionId: sessId,
            budget: amt,
            startedByUid: evt.actorUid,
            startedByName: evt.actorName,
            startedAt: evt.createdAt,
          );
          if (!groupService.isSessionEnded(activeGroupId, recoveredSession)) {
            rawGroup = rawGroup!.copyWith(activeSession: recoveredSession);
            groupService.saveLocalGroup(rawGroup);
          }
          break;
        }
      }
    }

    final group = rawGroup;

    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final members = membersAsync.valueOrNull ?? [];
    final authService = ref.watch(groupAuthServiceProvider);
    final isOwner = (group != null && authService.isCurrentUser(group.ownerUid)) ||
        members.any((m) => m.role == 'owner' && authService.isCurrentUser(m.uid));

    // Keamanan: Jika bukan pemilik dan sudah bukan anggota grup, segera evict
    if (group != null && !isOwner && members.isNotEmpty && !members.any((m) => authService.isCurrentUser(m.uid))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(groupServiceProvider).setActiveGroupId(null);
        ref.read(activeGroupIdProvider.notifier).state = null;
        ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
        final rootCtx = rootNavigatorKey.currentContext ?? context;
        try {
          Navigator.of(rootCtx, rootNavigator: true).popUntil((route) => route.isFirst);
          GoRouter.of(rootCtx).go('/');
        } catch (_) {}
        GroupImportantDialog.showKickedFromGroup(
          rootCtx,
          groupName: group.name,
        );
      });
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: _buildNoGroupState(),
        ),
      );
    }

    Widget bodyContent;
    if (group != null) {
      _checkAutoOpen(group);
      bodyContent = _buildGroupContent(group);
    } else if (activeGroupId != null && activeGroupId.isNotEmpty) {
      bodyContent = const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 3),
        ),
      );
    } else {
      bodyContent = _buildNoGroupState();
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Header ScopeSwitcher (Pribadi vs Grup)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ScopeSwitcher(
                          currentScope: AppScope.grup,
                          onScopeChanged: (newScope) {
                            ref.read(appScopeProvider.notifier).state = newScope;
                          },
                        ),
                      ),
                    ),
                  ),
                  if (group != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        context.push('/group/invite/${group.id}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.ink, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CustomPaint(
                              size: Size(13, 13),
                              painter: CustomSharePainter(color: AppColors.ink),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              group.code,
                              style: AppTypography.buttonSmall.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Konten Utama
            Expanded(
              child: bodyContent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoGroupState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.matahari,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const CustomPaint(
              size: Size(36, 36),
              painter: CustomCrownPainter(color: AppColors.ink, strokeWidth: 2.8),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Bergabung Grup',
            style: AppTypography.titleMedium.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Buat grup baru bersama teman atau masukkan kode undangan untuk mencatat budget bersama.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          StickerButton.large(
            text: 'BUAT ATAU GABUNG GRUP',
            backgroundColor: AppColors.matahari,
            onPressed: () => context.push('/group/join-or-create'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupContent(GroupModel group) {
    final activeSession = group.activeSession;
    if (activeSession == null) {
      return _buildNoActiveSessionState(group);
    }

    final notesAsync = ref.watch(activeGroupNotesStreamProvider);
    final List<GroupNoteModel> streamedNotes = notesAsync.valueOrNull ?? [];
    final List<GroupNoteModel> localNotes = ref.read(groupServiceProvider).getLocalNotes(group.id);
    final Map<String, GroupNoteModel> notesMap = {for (final n in localNotes) n.noteId: n};
    for (final n in streamedNotes) {
      notesMap[n.noteId] = n;
    }
    final List<GroupNoteModel> allNotes = notesMap.values.toList();
    final List<GroupNoteModel> activeNotes = allNotes
        .where((n) => !n.deleted && (n.sessionId == activeSession.sessionId || n.sessionId.isEmpty))
        .toList();

    // Hitung budget secara murni deterministik (append-only)
    final totalSpent = GroupModel.calculateTotalSpent(activeSession.sessionId, activeNotes);
    final remainingBudget = GroupModel.calculateRemainingBudget(
      sessionBudget: activeSession.budget,
      sessionId: activeSession.sessionId,
      notes: activeNotes,
    );

    final hasPendingWrites = allNotes.any((n) => n.hasPendingWrites);
    final syncState = hasPendingWrites ? SyncState.menunggu : SyncState.tersinkron;

    return Column(
      children: [
        // Strip Sinkronisasi di bagian atas
        SyncStrip(
          state: syncState,
          isVisible: hasPendingWrites,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Nama Grup & Sesi
                Text(
                  group.name,
                  style: AppTypography.displayMedium.copyWith(fontSize: 26),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sesi dimulai oleh ${activeSession.startedByName}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),

                // Hero Card: Sisa Budget Grup Bersama
                _buildHeroBudgetCard(
                  session: activeSession,
                  totalSpent: totalSpent,
                  remainingBudget: remainingBudget,
                ),
                const SizedBox(height: 16),

                // Tombol Catat Pengeluaran
                StickerButton(
                  text: '+ CATAT PENGELUARAN',
                  backgroundColor: AppColors.tomat,
                  height: 50,
                  borderRadius: 16,
                  onPressed: () => _openAddExpenseSheet(
                    group.id,
                    activeSession.sessionId,
                    activeSession.budget,
                  ),
                ),
                if (group.isOwner(ref.watch(groupAuthServiceProvider).currentUid ?? '')) ...[
                  const SizedBox(height: 10),
                  StickerButton(
                    text: 'AKHIRI DATE GRUP',
                    backgroundColor: AppColors.matahari,
                    height: 46,
                    borderRadius: 16,
                    onPressed: () async {
                      final confirm = await GroupImportantDialog.showConfirmEndGroupSession(
                        context,
                        groupName: group.name,
                        budget: activeSession.budget,
                      );
                      if (confirm == true) {
                        await ref.read(groupGameServiceProvider).endSession(gid: group.id);
                        if (mounted) {
                          showStickerSnackbar(context, message: 'Date grup telah diakhiri. Permainan grup kini terbuka!');
                        }
                      }
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Subtitle Daftar Catatan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Catatan Belanja (${activeNotes.length})',
                        style: AppTypography.titleMedium.copyWith(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasPendingWrites) ...[
                      const SizedBox(width: 8),
                      const SyncBadge(hasPendingWrites: true),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // List Catatan Pengeluaran
                if (activeNotes.isEmpty)
                  _buildEmptyNotesCard()
                else
                  ...activeNotes.map((note) => _buildNoteTile(
                        gid: group.id,
                        note: note,
                        group: group,
                      )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveSessionState(GroupModel group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const CustomPaint(
              size: Size(36, 36),
              painter: CustomCheckPainter(color: AppColors.ink, strokeWidth: 3.0),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Grup "${group.name}"',
            style: AppTypography.titleMedium.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada sesi roda yang diputar. Putar roda bersama untuk menentukan batas budget sesi ini!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          StickerButton.large(
            text: 'PUTAR RODA SEKARANG',
            backgroundColor: AppColors.tomat,
            onPressed: () {
              ref.read(appScopeProvider.notifier).state = AppScope.grup;
              context.go('/roda');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBudgetCard({
    required GroupSessionModel session,
    required int totalSpent,
    required int remainingBudget,
  }) {
    final progress = session.budget > 0
        ? (totalSpent / session.budget).clamp(0.0, 1.0)
        : 1.0;
    final statusColor = AppColors.getBudgetStatusColor(progress);

    return StickerCard.hero(
      backgroundColor: statusColor,
      borderColor: AppColors.ink,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SISA BUDGET GRUP',
                  style: AppTypography.buttonSmall.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.5,
                    color: AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: Text(
                  remainingBudget >= 0 ? 'AMAN' : 'OVERBUDGET',
                  style: AppTypography.buttonSmall.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nominal Besar Sisa Budget
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              RupiahFormatter.format(remainingBudget),
              style: AppTypography.displayLarge.copyWith(
                fontSize: 34,
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Progress Bar Neo-Brutalist
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Baris Detail Terpakai vs Total Budget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Terpakai: ${RupiahFormatter.format(totalSpent)}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget: ${RupiahFormatter.format(session.budget)}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          const CustomPaint(
            size: Size(36, 40),
            painter: CustomReceiptPainter(color: AppColors.disabled, strokeWidth: 2.2),
          ),
          const SizedBox(height: 10),
          Text(
            'Belum Ada Pengeluaran',
            style: AppTypography.titleMedium.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Setiap pengeluaran yang dicatat anggota akan otomatis mengurangi sisa budget bersama secara realtime.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile({
    required String gid,
    required GroupNoteModel note,
    required GroupModel group,
  }) {
    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid;
    final isAuthorOrOwner = note.authorUid == myUid || group.ownerUid == myUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MemberAvatar(
            name: note.authorName,
            colorIndex: 0,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: AppTypography.bodyLargeBold.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SyncBadge(
                      hasPendingWrites: note.hasPendingWrites,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Oleh ${note.authorName}',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    RupiahFormatter.format(note.amount),
                    style: AppTypography.bodyLargeBold.copyWith(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (isAuthorOrOwner)
                  GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.uiTap);
                      _handleDeleteNote(
                        gid: gid,
                        note: note,
                        sessionBudget: group.activeSession?.budget ?? 0,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Hapus',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.tomat,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// BottomSheet Tambah Catatan Pengeluaran Grup
class _AddGroupExpenseBottomSheet extends ConsumerStatefulWidget {
  final String gid;
  final String sessionId;
  final int sessionBudget;

  const _AddGroupExpenseBottomSheet({
    required this.gid,
    required this.sessionId,
    required this.sessionBudget,
  });

  @override
  ConsumerState<_AddGroupExpenseBottomSheet> createState() => _AddGroupExpenseBottomSheetState();
}

class _AddGroupExpenseBottomSheetState extends ConsumerState<_AddGroupExpenseBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSaving = false;

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
      showStickerSnackbar(context, message: 'Masukkan nominal belanja yang valid');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.addNote(
        gid: widget.gid,
        sessionId: widget.sessionId,
        title: title,
        amount: amount,
        sessionBudget: widget.sessionBudget,
      );

      // Mainkan suara koin tercatat & getar
      SoundService.instance.play(Sfx.coinRecord);
      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showStickerSnackbar(context, message: 'Gagal menyimpan catatan');
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
                Text(
                  'Catat Pengeluaran Grup',
                  style: AppTypography.titleMedium.copyWith(fontSize: 18),
                ),
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    Navigator.pop(context);
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
                      painter: CustomCrossPainter(color: AppColors.ink, strokeWidth: 2.2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nama Barang
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nama barang / jajanan',
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide: const BorderSide(color: AppColors.ink, width: 2.5),
                ),
              ),
              style: AppTypography.bodyLargeBold.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),

            // Nominal Rupiah
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: _formatNominal,
              decoration: InputDecoration(
                hintText: 'Rp 0',
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide: const BorderSide(color: AppColors.ink, width: 2.5),
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

