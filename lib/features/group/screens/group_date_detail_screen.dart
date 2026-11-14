import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/group/models/group_event_model.dart';
import '../../../core/group/models/group_history_models.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_note_model.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/sync/sync_state.dart';
import '../../../core/group/widgets/sync_badge.dart';
import '../../../core/group/widgets/sync_strip.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/indonesian_date_formatter.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../widgets/group_note_detail_sheet.dart';
import 'group_history_view.dart';

/// Tab aktif pada Layar 63 / 64 / 65 Detail Date Grup
enum GroupDateDetailTab {
  ringkasan, // Layar 63 (Rgrup2)
  catatan, // Layar 64 (Rgrup3)
  linimasa, // Layar 65 (Rgrup4)
}

/// Callback opsional ketika baris catatan diketuk pada Layar 64 (untuk Sheet 66 di Tahap H4)
typedef GroupNoteTapCallback = void Function(
  BuildContext context,
  GroupNoteWithRemaining noteWithRemaining,
  GroupSessionModel session,
  GroupModel? group,
);

/// Layar 63, 64, 65: Detail Date Grup dengan Pemilih Tab (Ringkasan | Catatan | Linimasa)
/// Acuan visual:
/// - Rgrup2.dc.html (Layar 63: Ringkasan)
/// - Rgrup3.dc.html (Layar 64: Catatan)
/// - Rgrup4.dc.html (Layar 65: Linimasa)
class GroupDateDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String sessionId;
  final GroupDateDetailTab initialTab;
  final GroupNoteTapCallback? onNoteTapped;

  const GroupDateDetailScreen({
    super.key,
    required this.groupId,
    required this.sessionId,
    this.initialTab = GroupDateDetailTab.ringkasan,
    this.onNoteTapped,
  });

  /// Palet warna avatar lingkaran sesuai tema aktif
  static List<Color> get avatarPalette =>
      PutarTheme.pasarMalam.detailMemberColors;

  static Color avatarColorFor(int index, {PutarTheme? theme}) {
    final palette = (theme ?? PutarTheme.pasarMalam).detailMemberColors;
    return palette[index.abs() % palette.length];
  }

  static String formatDotTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh.$mm';
  }

  static String formatDurationId(DateTime start, DateTime? end) {
    if (end == null) return 'Sedang berjalan';
    final diff = end.difference(start);
    final totalMinutes = math.max(1, diff.inMinutes);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0 && mins > 0) {
      return 'Lama $hours j $mins mnt';
    } else if (hours > 0) {
      return 'Lama $hours j';
    } else {
      return 'Lama $mins mnt';
    }
  }

  @override
  ConsumerState<GroupDateDetailScreen> createState() =>
      _GroupDateDetailScreenState();
}

class _GroupDateDetailScreenState extends ConsumerState<GroupDateDetailScreen> {
  late GroupDateDetailTab _activeTab;
  String? _selectedMemberUid; // null = Semua · N pada Tab Catatan (Layar 64)

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  void _switchTab(GroupDateDetailTab tab) {
    if (_activeTab == tab) return;
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.selectionClick();
    setState(() {
      _activeTab = tab;
    });
  }

  void _shareSummary({
    required GroupModel? group,
    required GroupSessionModel session,
    required int totalSpent,
    required int activeNoteCount,
  }) {
    SoundService.instance.play(Sfx.uiTap);
    final groupTitle = group?.name ?? 'Date Grup';
    final dateText = IndonesianDateFormatter.fullDayAndDate(session.startedAt);
    final isLolos = totalSpent <= session.budget;
    final diff = (session.budget - totalSpent).abs();
    final statusLine = isLolos
        ? 'Lolos · Hemat ${RupiahFormatter.format(diff)}'
        : 'Lewat ${RupiahFormatter.format(diff)}';
    final shareText =
        'Ringkasan $groupTitle ($dateText)\n'
        '$statusLine\n'
        'Budget: ${RupiahFormatter.format(session.budget)} · '
        'Terpakai: ${RupiahFormatter.format(totalSpent)} ($activeNoteCount catatan)';

    try {
      SharePlus.instance.share(ShareParams(text: shareText));
    } catch (_) {}
  }

  int _resolveMemberColorIndex({
    required String uid,
    required String displayName,
    required List<GroupMemberModel> members,
    required bool isCurrentUser,
  }) {
    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      if (m.uid == uid) {
        return m.colorIndex > 0 ? m.colorIndex : i;
      }
    }
    if (isCurrentUser) return 1;
    final clean = displayName.trim().toLowerCase();
    if (clean.startsWith('d')) return 0;
    if (clean.startsWith('k')) return 1;
    if (clean.startsWith('r')) return 2;
    if (clean.startsWith('b')) return 3;
    return uid.hashCode.abs() % GroupDateDetailScreen.avatarPalette.length;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 340 ? 16.0 : 24.0;
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final groupService = ref.watch(groupServiceProvider);
    final authService = ref.watch(groupAuthServiceProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final group = activeGroupAsync.valueOrNull ??
        groupService.getLocalGroup(widget.groupId);

    final sessionsAsync = ref.watch(activeGroupSessionsStreamProvider);
    final streamedSessions = sessionsAsync.valueOrNull ?? [];
    final localSessions = groupService.getLocalSessions(widget.groupId);
    final allSessions = <String, GroupSessionModel>{
      for (final s in localSessions) s.sessionId: s,
      for (final s in streamedSessions) s.sessionId: s,
    };
    if (group?.activeSession != null &&
        group!.activeSession!.sessionId == widget.sessionId &&
        !allSessions.containsKey(widget.sessionId)) {
      allSessions[widget.sessionId] = group.activeSession!;
    }

    final rawSession = allSessions[widget.sessionId];
    final notesAsync = ref.watch(groupSessionNotesStreamProvider(widget.sessionId));
    final eventsAsync = ref.watch(groupSessionEventsStreamProvider(widget.sessionId));
    final membersAsync = ref.watch(activeGroupMembersStreamProvider);

    final localNotes = groupService
        .getLocalNotes(widget.groupId)
        .where((n) => n.sessionId == widget.sessionId)
        .toList();
    final streamedNotes = notesAsync.valueOrNull ?? [];
    final notesMap = <String, GroupNoteModel>{
      for (final n in localNotes) n.noteId: n,
      for (final n in streamedNotes) n.noteId: n,
    };
    final sessionNotes = notesMap.values.toList();

    final localEvents = groupService
        .getLocalEvents(widget.groupId)
        .where((e) => e.sessionId == widget.sessionId)
        .toList();
    final streamedEvents = eventsAsync.valueOrNull ?? [];
    final eventsMap = <String, GroupEventModel>{
      for (final e in localEvents) e.eventId: e,
      for (final e in streamedEvents) e.eventId: e,
    };
    final sessionEvents = eventsMap.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final members = membersAsync.valueOrNull ?? [];

    if (rawSession == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(
                  context: context,
                  title: 'Detail Date',
                  session: null,
                ),
                const Expanded(
                  child: Center(
                    child: Text('Data sesi date tidak ditemukan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final recalculatedSession = GroupHistoryCalculator.recalculateSession(
      session: rawSession,
      sessionNotes: sessionNotes,
    );
    final notesWithRemaining = GroupHistoryCalculator.computeNotesWithRemaining(
      budget: recalculatedSession.budget,
      notes: sessionNotes,
    );
    final hasPendingWrites = sessionNotes.any((n) => n.hasPendingWrites);
    final isOffline = ref.watch(groupOfflineModeProvider);
    final hasPendingOrOffline = hasPendingWrites || isOffline;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (hasPendingOrOffline)
              SyncStrip(
                state: hasPendingWrites ? SyncState.menunggu : SyncState.offline,
                isVisible: true,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  20,
                  horizontalPad,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header: Kembali + Tanggal + Lencana Status
                    _buildTopBar(
                      context: context,
                      title: IndonesianDateFormatter.fullDayAndDate(
                        recalculatedSession.startedAt,
                      ),
                      session: recalculatedSession,
                    ),
                    const SizedBox(height: 10),

                    // 2. Pemilih Tab: Ringkasan | Catatan | Linimasa
                    _buildTabSwitcher(t),
                    const SizedBox(height: 10),

                    // 3. Isi Tab dengan transisi fade 150ms (100ms bila disableAnimations)
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: disableAnim ? 100 : 150),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _buildActiveTabBody(
                          context: context,
                          group: group,
                          session: recalculatedSession,
                          notesWithRemaining: notesWithRemaining,
                          sessionEvents: sessionEvents,
                          members: members,
                          authService: authService,
                          hasPendingWrites: hasPendingOrOffline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar({
    required BuildContext context,
    required String title,
    required GroupSessionModel? session,
  }) {
    final t = context.putarTheme;
    final isLolos = session?.isLolos ?? true;
    final statusBadgeText = session == null
        ? ''
        : (isLolos
            ? 'Lolos'
            : GroupHistoryCalculator.formatLewatBadge(session.overBudgetAmount));

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Kembali',
          child: GestureDetector(
            onTap: () {
              SoundService.instance.play(Sfx.uiTap);
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/riwayat');
              }
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                border: Border.all(color: t.ink, width: t.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: t.ink,
                    offset: t.smallShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(22, 22),
                painter: CustomBackIconPainter(
                  color: t.ink,
                  strokeWidth: 3.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: t.displayMedium.copyWith(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          ),
        ),
        if (session != null) ...[
          const SizedBox(width: 8),
          Semantics(
            label: 'Status date: $statusBadgeText',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isLolos ? t.accentMint : t.danger,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: t.ink, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLolos) ...[
                    CustomPaint(
                      size: const Size(13, 13),
                      painter: CustomCheckIconPainter(
                        color: t.ink,
                        strokeWidth: 3.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    statusBadgeText,
                    style: t.buttonSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabSwitcher(PutarTheme t) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.ink, width: t.borderWidth),
        boxShadow: [
          BoxShadow(
            color: t.ink,
            offset: t.smallShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabSegment(
            t,
            tab: GroupDateDetailTab.ringkasan,
            label: 'Ringkasan',
          ),
          const SizedBox(width: 4),
          _buildTabSegment(
            t,
            tab: GroupDateDetailTab.catatan,
            label: 'Catatan',
          ),
          const SizedBox(width: 4),
          _buildTabSegment(
            t,
            tab: GroupDateDetailTab.linimasa,
            label: 'Linimasa',
          ),
        ],
      ),
    );
  }

  Widget _buildTabSegment(
    PutarTheme t, {
    required GroupDateDetailTab tab,
    required String label,
  }) {
    final isSelected = _activeTab == tab;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Tab $label',
        child: GestureDetector(
          onTap: () => _switchTab(tab),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? t.secondary : t.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: isSelected ? t.ink : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: t.buttonSmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabBody({
    required BuildContext context,
    required GroupModel? group,
    required GroupSessionModel session,
    required List<GroupNoteWithRemaining> notesWithRemaining,
    required List<GroupEventModel> sessionEvents,
    required List<GroupMemberModel> members,
    required GroupAuthService authService,
    required bool hasPendingWrites,
  }) {
    switch (_activeTab) {
      case GroupDateDetailTab.ringkasan:
        return KeyedSubtree(
          key: const ValueKey('tab_ringkasan_63'),
          child: _buildRingkasanTab(
            context: context,
            group: group,
            session: session,
            notesWithRemaining: notesWithRemaining,
            members: members,
            authService: authService,
            hasPendingWrites: hasPendingWrites,
          ),
        );
      case GroupDateDetailTab.catatan:
        return KeyedSubtree(
          key: const ValueKey('tab_catatan_64'),
          child: _buildCatatanTab(
            context: context,
            group: group,
            session: session,
            notesWithRemaining: notesWithRemaining,
            members: members,
            authService: authService,
          ),
        );
      case GroupDateDetailTab.linimasa:
        return KeyedSubtree(
          key: const ValueKey('tab_linimasa_65'),
          child: _buildLinimasaTab(
            context: context,
            session: session,
            notesWithRemaining: notesWithRemaining,
            sessionEvents: sessionEvents,
            members: members,
            authService: authService,
          ),
        );
    }
  }

  // ===========================================================================
  // LAYAR 63: TAB RINGKASAN (Rgrup2.dc.html)
  // ===========================================================================
  Widget _buildRingkasanTab({
    required BuildContext context,
    required GroupModel? group,
    required GroupSessionModel session,
    required List<GroupNoteWithRemaining> notesWithRemaining,
    required List<GroupMemberModel> members,
    required GroupAuthService authService,
    required bool hasPendingWrites,
  }) {
    final t = context.putarTheme;
    final activeNotes = notesWithRemaining.map((e) => e.note).toList();
    final totalSpent = session.totalSpent;
    final isLolos = totalSpent <= session.budget;
    final hematOrLewatAmount = (session.budget - totalSpent).abs();
    final spentFraction = session.budget > 0
        ? (totalSpent / session.budget).clamp(0.0, 1.0)
        : 0.0;

    final memberSpending = GroupHistoryCalculator.computeMemberSpending(
      members: members,
      notes: activeNotes,
    );

    final isBudgetByMe = authService.isCurrentUser(session.budgetByUid);
    final budgetActorName = isBudgetByMe
        ? 'Kamu'
        : (session.budgetByName.trim().isNotEmpty
            ? session.budgetByName.trim()
            : 'Anggota');
    final budgetActorColorIdx = _resolveMemberColorIndex(
      uid: session.budgetByUid,
      displayName: budgetActorName,
      members: members,
      isCurrentUser: isBudgetByMe,
    );
    final gameTitle = GroupEventModel.formatGameName(session.game);
    final gameDetail = GroupHistoryCalculator.formatGameResultDetail(session);
    final gameTime = GroupDateDetailScreen.formatDotTime(session.startedAt);

    final isStartedByMe = authService.isCurrentUser(session.startedByUid);
    final startedByLabel = isStartedByMe
        ? 'Kamu'
        : (session.startedByName.trim().isNotEmpty
            ? session.startedByName.trim()
            : 'Anggota');
    final startClock = GroupDateDetailScreen.formatDotTime(session.startedAt);
    final endClock = session.endedAt != null
        ? GroupDateDetailScreen.formatDotTime(session.endedAt!)
        : null;
    final durationLabel = GroupDateDetailScreen.formatDurationId(
      session.startedAt,
      session.endedAt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Kartu Hero Matahari: "Hemat Rp26.000" / "Lewat Rp12.000"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: t.secondary,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.ink, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: t.ink,
                        offset: t.dialogShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLolos ? 'Hemat' : 'Lewat budget',
                        style: t.bodySmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          RupiahFormatter.format(hematOrLewatAmount),
                          style: t.displayLarge.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: t.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _GrowingProgressBar(
                        fraction: spentFraction,
                        height: 16,
                        borderRadius: 10,
                        borderWidth: 3.0,
                        fillColor: isLolos ? t.accentMint : t.danger,
                        showRightDividerBorder: true,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Terpakai ${RupiahFormatter.format(totalSpent)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'dari ${RupiahFormatter.format(session.budget)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: t.bodySmall.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: t.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasPendingWrites) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Belum termasuk catatan terbaru anggota lain',
                          style: t.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Kartu "BUDGET DITENTUKAN OLEH"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.ink, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: t.ink,
                        offset: t.smallShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BUDGET DITENTUKAN OLEH',
                        style: t.buttonSmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: t.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GroupCircleAvatar(
                            name: budgetActorName,
                            color: GroupDateDetailScreen.avatarColorFor(
                              budgetActorColorIdx,
                              theme: t,
                            ),
                            size: 34,
                            fontSize: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$budgetActorName · $gameTitle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyLargeBold.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: t.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$gameDetail · $gameTime',
                                  style: t.bodySmall.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GroupHistoryMiniGameIcon(
                            game: session.game,
                            size: 30,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Kartu "Pengeluaran per orang"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Pengeluaran per orang',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${notesWithRemaining.length} catatan',
                            style: t.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (memberSpending.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Belum ada data anggota',
                            style: t.bodySmall.copyWith(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        )
                      else
                        ...List.generate(memberSpending.length, (idx) {
                          final item = memberSpending[idx];
                          final isMe = authService.isCurrentUser(item.uid);
                          final displayName = isMe ? 'Kamu' : item.name;
                          final colorIdx = _resolveMemberColorIndex(
                            uid: item.uid,
                            displayName: displayName,
                            members: members,
                            isCurrentUser: isMe,
                          );
                          final barColor = GroupDateDetailScreen.avatarColorFor(
                            colorIdx,
                            theme: t,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GroupCircleAvatar(
                                  name: displayName,
                                  color: barColor,
                                  size: 32,
                                  fontSize: 15,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: t.bodySmall.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: t.ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item.hasRecorded
                                                ? RupiahFormatter.format(
                                                    item.amountSpent,
                                                  )
                                                : 'Rp0',
                                            style: t.bodySmall.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: t.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      _GrowingProgressBar(
                                        fraction: item.percentageOfTotalSpent,
                                        height: 12,
                                        borderRadius: 7,
                                        borderWidth: 2.5,
                                        fillColor: barColor,
                                      ),
                                      if (!item.hasRecorded) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Belum mencatat',
                                          style: t.bodySmall.copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: t.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Baris Chip Waktu (Mulai, Selesai, Lama)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildWhiteInfoPill(t, 'Mulai $startClock oleh $startedByLabel'),
                    if (endClock != null) _buildWhiteInfoPill(t, 'Selesai $endClock'),
                    _buildWhiteInfoPill(t, durationLabel),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // 5. Tombol "Bagikan ringkasan" di bagian bawah (Rgrup2.dc.html)
        Semantics(
          button: true,
          label: 'Bagikan ringkasan date grup',
          child: GestureDetector(
            onTap: () => _shareSummary(
              group: group,
              session: session,
              totalSpent: totalSpent,
              activeNoteCount: notesWithRemaining.length,
            ),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: t.ink, width: t.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: t.ink,
                    offset: t.smallShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Bagikan ringkasan',
                    style: t.buttonLarge.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteInfoPill(PutarTheme t, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.ink, width: 2),
      ),
      child: Text(
        label,
        style: t.buttonSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: t.ink,
        ),
      ),
    );
  }

  // ===========================================================================
  // LAYAR 64: TAB CATATAN (Rgrup3.dc.html)
  // ===========================================================================
  Widget _buildCatatanTab({
    required BuildContext context,
    required GroupModel? group,
    required GroupSessionModel session,
    required List<GroupNoteWithRemaining> notesWithRemaining,
    required List<GroupMemberModel> members,
    required GroupAuthService authService,
  }) {
    final t = context.putarTheme;
    // Susun daftar anggota untuk chip filter (Semua · N, lalu tiap anggota)
    final memberChips = <_MemberChipInfo>[];
    final seenUids = <String>{};

    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      if (m.uid.isEmpty || seenUids.contains(m.uid)) continue;
      seenUids.add(m.uid);
      final isMe = authService.isCurrentUser(m.uid);
      final name = isMe ? 'Kamu' : m.name;
      final cIdx = _resolveMemberColorIndex(
        uid: m.uid,
        displayName: name,
        members: members,
        isCurrentUser: isMe,
      );
      memberChips.add(
        _MemberChipInfo(
          uid: m.uid,
          displayName: name,
          color: GroupDateDetailScreen.avatarColorFor(cIdx, theme: t),
        ),
      );
    }

    for (final item in notesWithRemaining) {
      final uid = item.note.authorUid;
      if (uid.isEmpty || seenUids.contains(uid)) continue;
      seenUids.add(uid);
      final isMe = authService.isCurrentUser(uid);
      final name = isMe
          ? 'Kamu'
          : (item.note.authorName.trim().isNotEmpty
              ? item.note.authorName.trim()
              : 'Anggota');
      final cIdx = _resolveMemberColorIndex(
        uid: uid,
        displayName: name,
        members: members,
        isCurrentUser: isMe,
      );
      memberChips.add(
        _MemberChipInfo(
          uid: uid,
          displayName: name,
          color: GroupDateDetailScreen.avatarColorFor(cIdx, theme: t),
        ),
      );
    }

    final filteredNotes = _selectedMemberUid == null
        ? notesWithRemaining
        : notesWithRemaining
            .where((n) => n.note.authorUid == _selectedMemberUid)
            .toList();

    final filteredTotal = filteredNotes.fold<int>(
      0,
      (sum, item) => sum + item.note.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Chip filter per anggota dengan avatar kecil (bisa digeser horizontal)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _MemberFilterChip(
                label: 'Semua · ${notesWithRemaining.length}',
                isSelected: _selectedMemberUid == null,
                onTap: () {
                  setState(() {
                    _selectedMemberUid = null;
                  });
                },
              ),
              ...memberChips.map((mc) {
                final isSelected = _selectedMemberUid == mc.uid;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _MemberFilterChip(
                    label: mc.displayName,
                    avatarColor: mc.color,
                    avatarName: mc.displayName,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedMemberUid = mc.uid;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Baris "Total Rp54.000" & "3 catatan"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total ${RupiahFormatter.format(filteredTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${filteredNotes.length} catatan',
                style: t.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Daftar Kartu Catatan yang BISA DIKETUK
        Expanded(
          child: filteredNotes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _selectedMemberUid == null
                          ? 'Belum ada catatan pengeluaran'
                          : '${memberChips.any((m) => m.uid == _selectedMemberUid) ? memberChips.firstWhere((m) => m.uid == _selectedMemberUid).displayName : 'Anggota'} belum mencatat pengeluaran di date ini',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredNotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filteredNotes[index];
                    final isMe = authService.isCurrentUser(item.note.authorUid);
                    final authorLabel = isMe
                        ? 'Kamu'
                        : (item.note.authorName.trim().isNotEmpty
                            ? item.note.authorName.trim()
                            : 'Anggota');
                    final cIdx = _resolveMemberColorIndex(
                      uid: item.note.authorUid,
                      displayName: authorLabel,
                      members: members,
                      isCurrentUser: isMe,
                    );

                    return _SessionNoteCard(
                      key: ValueKey('sess_note_${item.note.noteId}'),
                      index: index,
                      item: item,
                      authorDisplayName: authorLabel,
                      avatarColor: GroupDateDetailScreen.avatarColorFor(
                        cIdx,
                        theme: t,
                      ),
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        if (widget.onNoteTapped != null) {
                          widget.onNoteTapped!(
                            context,
                            item,
                            session,
                            group,
                          );
                        } else {
                          showGroupNoteDetailSheet(
                            context: context,
                            gid: widget.groupId,
                            initialItem: item,
                            session: session,
                            group: group,
                            authorDisplayName: authorLabel,
                            authorAvatarColor:
                                GroupDateDetailScreen.avatarColorFor(
                              cIdx,
                              theme: t,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),

        // 4. Keterangan bawah (Rgrup3.dc.html)
        Text(
          'Ketuk catatan untuk melihat detailnya. Filter per anggota di atas.',
          textAlign: TextAlign.center,
          style: t.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textSecondary,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LAYAR 65: TAB LINIMASA (Rgrup4.dc.html)
  // ===========================================================================
  Widget _buildLinimasaTab({
    required BuildContext context,
    required GroupSessionModel session,
    required List<GroupNoteWithRemaining> notesWithRemaining,
    required List<GroupEventModel> sessionEvents,
    required List<GroupMemberModel> members,
    required GroupAuthService authService,
  }) {
    final t = context.putarTheme;
    final timelineItems = _buildTimelineEntries(
      theme: t,
      session: session,
      notesWithRemaining: notesWithRemaining,
      sessionEvents: sessionEvents,
      members: members,
      authService: authService,
    );

    if (timelineItems.isEmpty) {
      return Center(
        child: Text(
          'Belum ada aktivitas di linimasa',
          style: t.bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(timelineItems.length, (index) {
          final entry = timelineItems[index];
          return _TimelineNodeRow(
            key: ValueKey('tl_${entry.id}_$index'),
            index: index,
            entry: entry,
            isLast: index == timelineItems.length - 1,
          );
        }),
      ),
    );
  }

  List<_TimelineEntry> _buildTimelineEntries({
    required PutarTheme theme,
    required GroupSessionModel session,
    required List<GroupNoteWithRemaining> notesWithRemaining,
    required List<GroupEventModel> sessionEvents,
    required List<GroupMemberModel> members,
    required GroupAuthService authService,
  }) {
    final entries = <_TimelineEntry>[];
    bool hasStartEvent = false;
    bool hasGameEvent = false;
    bool hasEndEvent = false;
    final recordedExpenseIds = <String>{};

    for (final evt in sessionEvents) {
      final isMe = authService.isCurrentUser(evt.actorUid);
      final actorName = isMe
          ? 'Kamu'
          : (evt.actorName.trim().isNotEmpty ? evt.actorName.trim() : 'Anggota');
      final colorIdx = _resolveMemberColorIndex(
        uid: evt.actorUid,
        displayName: actorName,
        members: members,
        isCurrentUser: isMe,
      );
      final avatarColor = GroupDateDetailScreen.avatarColorFor(
        colorIdx,
        theme: theme,
      );

      if (evt.type == GroupEventType.sessionStart) {
        hasStartEvent = true;
        entries.add(
          _TimelineEntry(
            id: evt.eventId,
            timestamp: evt.createdAt,
            kind: _TimelineNodeKind.flagMint,
            actorName: actorName,
            avatarColor: avatarColor,
            actionText: 'memulai date',
          ),
        );
      } else if ((evt.type == GroupEventType.gameResult &&
              evt.payload['valid'] != false) ||
          evt.type == GroupEventType.spin) {
        hasGameEvent = true;
        final game = evt.payload['game']?.toString() ?? session.game;
        final gameLabel = GroupEventModel.formatGameName(game);
        final amount =
            ((evt.payload['amount'] ?? evt.payload['budget']) as num?)?.toInt() ??
                session.budget;
        final detail = evt.payload['detail'] ?? session.detail;
        final sub = GroupHistoryCalculator.formatTimelineGameSubtitle(
          game: game,
          amount: amount,
          detail: detail,
        );
        entries.add(
          _TimelineEntry(
            id: evt.eventId,
            timestamp: evt.createdAt,
            kind: _TimelineNodeKind.gameYellow,
            gameType: game,
            actorName: actorName,
            avatarColor: avatarColor,
            actionText: 'memainkan $gameLabel',
            subtitle: sub,
          ),
        );
      } else if (evt.type == GroupEventType.expense &&
          evt.payload['deleted'] != true) {
        final noteId = evt.payload['noteId']?.toString() ?? '';
        if (noteId.isNotEmpty) {
          recordedExpenseIds.add(noteId);
        }
        final amount = (evt.payload['amount'] as num?)?.toInt() ?? 0;
        final title = evt.payload['title']?.toString() ?? 'Jajan';
        final isEdited = evt.payload['edited'] == true;
        entries.add(
          _TimelineEntry(
            id: evt.eventId,
            timestamp: evt.createdAt,
            kind: _TimelineNodeKind.receiptBlue,
            actorName: actorName,
            avatarColor: avatarColor,
            actionText: isEdited
                ? 'mengubah catatan ${RupiahFormatter.format(amount)}'
                : 'menambahkan ${RupiahFormatter.format(amount)}',
            subtitle: title,
          ),
        );
      } else if (evt.type == GroupEventType.expenseDeleted ||
          (evt.type == GroupEventType.expense &&
              evt.payload['deleted'] == true)) {
        final amount = (evt.payload['amount'] as num?)?.toInt() ?? 0;
        final title = evt.payload['title']?.toString() ?? 'Catatan';
        entries.add(
          _TimelineEntry(
            id: evt.eventId,
            timestamp: evt.createdAt,
            kind: _TimelineNodeKind.deletedCoral,
            actorName: actorName,
            avatarColor: avatarColor,
            actionText: 'menghapus catatan ${RupiahFormatter.format(amount)}',
            subtitle: title,
          ),
        );
      } else if (evt.type == GroupEventType.sessionEnd ||
          (evt.type == GroupEventType.custom &&
              evt.payload['action'] == 'end_session')) {
        hasEndEvent = true;
        final isLolos = session.isLolos;
        final diff = (session.budget - session.totalSpent).abs();
        final statusWord = isLolos ? 'Lolos' : 'Lewat';
        final subPrefix = isLolos
            ? 'Hemat ${RupiahFormatter.format(diff)}'
            : 'Lewat ${RupiahFormatter.format(diff)}';
        entries.add(
          _TimelineEntry(
            id: evt.eventId,
            timestamp: evt.createdAt,
            kind: _TimelineNodeKind.flagMint,
            actorName: actorName,
            avatarColor: avatarColor,
            actionText: 'menyelesaikan date: ',
            boldTrailing: statusWord,
            subtitle: '$subPrefix · ${notesWithRemaining.length} catatan',
          ),
        );
      } else if (evt.type == GroupEventType.custom &&
          evt.payload['action'] == 'session_result_updated') {
        final rawStatus = evt.payload['status']?.toString().toLowerCase();
        final isLolos = rawStatus != null && rawStatus.isNotEmpty
            ? rawStatus == 'lolos'
            : session.isLolos;
        final updatedTotal =
            (evt.payload['totalSpent'] as num?)?.toInt() ?? session.totalSpent;
        final updatedBudget =
            (evt.payload['budget'] as num?)?.toInt() ?? session.budget;
        final diff = (updatedBudget - updatedTotal).abs();
        final statusWord = isLolos ? 'Lolos' : 'Lewat';
        final diffLabel = isLolos
            ? 'Hemat ${RupiahFormatter.format(diff)}'
            : 'Lewat ${RupiahFormatter.format(diff)}';
        final isLateOffline = evt.payload['lateOfflineSync'] == true;
        entries.add(
          _TimelineEntry(
            id: evt.eventId,
            timestamp: evt.createdAt,
            kind: _TimelineNodeKind.flagMint,
            actorName: actorName,
            avatarColor: avatarColor,
            actionText: isLateOffline
                ? 'menyelaraskan catatan offline · Hasil date diperbarui: '
                : 'memicu pembaruan · Hasil date diperbarui: ',
            boldTrailing: statusWord,
            subtitle:
                'Terpakai ${RupiahFormatter.format(updatedTotal)} · $diffLabel',
          ),
        );
      }
    }

    // Sintesis simpul mulai, permainan, catatan, atau selesai bila belum tercatat di log event
    if (!hasStartEvent) {
      final isMe = authService.isCurrentUser(session.startedByUid);
      final actorName = isMe
          ? 'Kamu'
          : (session.startedByName.trim().isNotEmpty
              ? session.startedByName.trim()
              : 'Anggota');
      final colorIdx = _resolveMemberColorIndex(
        uid: session.startedByUid,
        displayName: actorName,
        members: members,
        isCurrentUser: isMe,
      );
      entries.add(
        _TimelineEntry(
          id: 'synth_start_${session.sessionId}',
          timestamp: session.startedAt,
          kind: _TimelineNodeKind.flagMint,
          actorName: actorName,
          avatarColor: GroupDateDetailScreen.avatarColorFor(
            colorIdx,
            theme: theme,
          ),
          actionText: 'memulai date',
        ),
      );
    }

    if (!hasGameEvent) {
      final isMe = authService.isCurrentUser(session.budgetByUid);
      final actorName = isMe
          ? 'Kamu'
          : (session.budgetByName.trim().isNotEmpty
              ? session.budgetByName.trim()
              : 'Anggota');
      final colorIdx = _resolveMemberColorIndex(
        uid: session.budgetByUid,
        displayName: actorName,
        members: members,
        isCurrentUser: isMe,
      );
      final gameLabel = GroupEventModel.formatGameName(session.game);
      final sub = GroupHistoryCalculator.formatTimelineGameSubtitle(
        game: session.game,
        amount: session.budget,
        detail: session.detail,
      );
      entries.add(
        _TimelineEntry(
          id: 'synth_game_${session.sessionId}',
          timestamp: session.startedAt.add(const Duration(seconds: 1)),
          kind: _TimelineNodeKind.gameYellow,
          gameType: session.game,
          actorName: actorName,
          avatarColor: GroupDateDetailScreen.avatarColorFor(
            colorIdx,
            theme: theme,
          ),
          actionText: 'memainkan $gameLabel',
          subtitle: sub,
        ),
      );
    }

    for (final item in notesWithRemaining) {
      final note = item.note;
      if (recordedExpenseIds.contains(note.noteId)) continue;
      final isMe = authService.isCurrentUser(note.authorUid);
      final actorName = isMe
          ? 'Kamu'
          : (note.authorName.trim().isNotEmpty
              ? note.authorName.trim()
              : 'Anggota');
      final colorIdx = _resolveMemberColorIndex(
        uid: note.authorUid,
        displayName: actorName,
        members: members,
        isCurrentUser: isMe,
      );
      entries.add(
        _TimelineEntry(
          id: 'synth_note_${note.noteId}',
          timestamp: note.createdAt,
          kind: _TimelineNodeKind.receiptBlue,
          actorName: actorName,
          avatarColor: GroupDateDetailScreen.avatarColorFor(
            colorIdx,
            theme: theme,
          ),
          actionText: 'menambahkan ${RupiahFormatter.format(note.amount)}',
          subtitle: note.title,
        ),
      );
    }

    if (!hasEndEvent && session.endedAt != null) {
      final endUid = session.endedByUid ?? session.startedByUid;
      final endRawName = session.endedByName ?? session.startedByName;
      final isMe = authService.isCurrentUser(endUid);
      final actorName = isMe
          ? 'Kamu'
          : (endRawName.trim().isNotEmpty ? endRawName.trim() : 'Anggota');
      final colorIdx = _resolveMemberColorIndex(
        uid: endUid,
        displayName: actorName,
        members: members,
        isCurrentUser: isMe,
      );
      final isLolos = session.isLolos;
      final diff = (session.budget - session.totalSpent).abs();
      final statusWord = isLolos ? 'Lolos' : 'Lewat';
      final subPrefix = isLolos
          ? 'Hemat ${RupiahFormatter.format(diff)}'
          : 'Lewat ${RupiahFormatter.format(diff)}';
      entries.add(
        _TimelineEntry(
          id: 'synth_end_${session.sessionId}',
          timestamp: session.endedAt!,
          kind: _TimelineNodeKind.flagMint,
          actorName: actorName,
          avatarColor: GroupDateDetailScreen.avatarColorFor(
            colorIdx,
            theme: theme,
          ),
          actionText: 'menyelesaikan date: ',
          boldTrailing: statusWord,
          subtitle: '$subPrefix · ${notesWithRemaining.length} catatan',
        ),
      );
    }

    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }
}

/// Avatar Lingkaran Neo-Brutalist sesuai Rgrup2..Rgrup5.dc.html
class GroupCircleAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final double fontSize;
  final double borderWidth;

  const GroupCircleAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 34,
    this.fontSize = 15,
    this.borderWidth = 3.0,
  });

  String _initial() {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: t.ink, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            _initial(),
            style: t.buttonSmall.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bar Proporsi yang tumbuh dari 0 selama 500ms (atau 100ms bila disableAnimations)
class _GrowingProgressBar extends StatelessWidget {
  final double fraction;
  final double height;
  final double borderRadius;
  final double borderWidth;
  final Color fillColor;
  final bool showRightDividerBorder;

  const _GrowingProgressBar({
    required this.fraction,
    required this.height,
    required this.borderRadius,
    required this.borderWidth,
    required this.fillColor,
    this.showRightDividerBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = fraction.clamp(0.0, 1.0);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: t.ink, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: disableAnim ? target : 0.0,
              end: target,
            ),
            duration: Duration(milliseconds: disableAnim ? 100 : 500),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              final fillWidth = constraints.maxWidth * val;
              if (fillWidth <= 0) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: fillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: fillColor,
                    border: (showRightDividerBorder && val > 0.02 && val < 0.98)
                        ? Border(
                            right: BorderSide(
                              color: t.ink,
                              width: borderWidth,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MemberChipInfo {
  final String uid;
  final String displayName;
  final Color color;

  const _MemberChipInfo({
    required this.uid,
    required this.displayName,
    required this.color,
  });
}

/// Chip Filter per Anggota dengan Avatar Kecil (Layar 64 - Rgrup3.dc.html)
class _MemberFilterChip extends StatefulWidget {
  final String label;
  final String? avatarName;
  final Color? avatarColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberFilterChip({
    required this.label,
    this.avatarName,
    this.avatarColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MemberFilterChip> createState() => _MemberFilterChipState();
}

class _MemberFilterChipState extends State<_MemberFilterChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.07), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.07, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant _MemberFilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!disableAnim) {
        _bounceController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hasAvatar = widget.avatarName != null && widget.avatarColor != null;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Filter anggota ${widget.label}',
      child: GestureDetector(
        onTap: () {
          SoundService.instance.play(Sfx.uiTap);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: ScaleTransition(
          scale: disableAnim
              ? const AlwaysStoppedAnimation<double>(1.0)
              : _scaleAnimation,
          child: AnimatedContainer(
            duration: Duration(milliseconds: disableAnim ? 100 : 180),
            padding: EdgeInsets.fromLTRB(hasAvatar ? 5 : 12, 4, 12, 4),
            decoration: BoxDecoration(
              color: widget.isSelected ? t.secondary : t.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: t.ink, width: t.borderWidth),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: t.ink,
                        offset: t.miniShadowOffset,
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasAvatar) ...[
                  GroupCircleAvatar(
                    name: widget.avatarName!,
                    color: widget.avatarColor!,
                    size: 22,
                    fontSize: 10,
                    borderWidth: 2.5,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: t.buttonSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu Baris Catatan yang BISA DIKETUK pada Layar 64 (Rgrup3.dc.html)
class _SessionNoteCard extends StatefulWidget {
  final int index;
  final GroupNoteWithRemaining item;
  final String authorDisplayName;
  final Color avatarColor;
  final VoidCallback onTap;

  const _SessionNoteCard({
    super.key,
    required this.index,
    required this.item,
    required this.authorDisplayName,
    required this.avatarColor,
    required this.onTap,
  });

  @override
  State<_SessionNoteCard> createState() => _SessionNoteCardState();
}

class _SessionNoteCardState extends State<_SessionNoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_controller.status == AnimationStatus.dismissed && _delayTimer == null) {
      if (_reduceMotion) {
        _controller.duration = const Duration(milliseconds: 100);
        _controller.forward();
      } else {
        _controller.duration = const Duration(milliseconds: 500);
        final delayMs = math.min(widget.index * 100, 600);
        if (delayMs == 0) {
          _controller.forward();
        } else {
          _delayTimer = Timer(Duration(milliseconds: delayMs), () {
            if (mounted) _controller.forward();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.putarTheme;
    final note = widget.item.note;
    final clock = GroupDateDetailScreen.formatDotTime(note.createdAt);
    final remainingFormatted = RupiahFormatter.format(widget.item.remainingAfter);
    final amountFormatted = RupiahFormatter.format(note.amount);
    final subtitleText =
        '${widget.authorDisplayName} · $clock · sisa setelahnya $remainingFormatted';

    final semanticLabel =
        '${note.title}, $amountFormatted. Dicatat oleh ${widget.authorDisplayName} '
        'pukul $clock, sisa budget setelahnya $remainingFormatted. '
        '${note.hasPendingWrites ? "Status menunggu sinkron." : "Status terkirim."}';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final dy = _reduceMotion ? 0.0 : (1.0 - t) * 14.0;
        return Opacity(
          alwaysIncludeSemantics: true,
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(theme.cardRadius),
                border: Border.all(color: theme.ink, width: theme.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: theme.ink,
                    offset: theme.smallShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GroupCircleAvatar(
                    name: widget.authorDisplayName,
                    color: widget.avatarColor,
                    size: 34,
                    fontSize: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodyLargeBold.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: theme.ink,
                                ),
                              ),
                            ),
                            if (note.hasPendingWrites) ...[
                              const SizedBox(width: 6),
                              const SyncBadge(
                                hasPendingWrites: true,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        amountFormatted,
                        style: theme.bodyLargeBold.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CustomPaint(
                    size: const Size(18, 18),
                    painter: CustomChevronRightPainter(
                      color: theme.ink,
                      strokeWidth: 3.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TimelineNodeKind {
  flagMint,
  gameYellow,
  receiptBlue,
  deletedCoral,
}

class _TimelineEntry {
  final String id;
  final DateTime timestamp;
  final _TimelineNodeKind kind;
  final String? gameType;
  final String actorName;
  final Color avatarColor;
  final String actionText;
  final String? boldTrailing;
  final String? subtitle;

  const _TimelineEntry({
    required this.id,
    required this.timestamp,
    required this.kind,
    this.gameType,
    required this.actorName,
    required this.avatarColor,
    required this.actionText,
    this.boldTrailing,
    this.subtitle,
  });
}

/// Satu Baris Simpul Linimasa pada Layar 65 (Rgrup4.dc.html)
class _TimelineNodeRow extends StatefulWidget {
  final int index;
  final _TimelineEntry entry;
  final bool isLast;

  const _TimelineNodeRow({
    super.key,
    required this.index,
    required this.entry,
    required this.isLast,
  });

  @override
  State<_TimelineNodeRow> createState() => _TimelineNodeRowState();
}

class _TimelineNodeRowState extends State<_TimelineNodeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_controller.status == AnimationStatus.dismissed && _delayTimer == null) {
      if (_reduceMotion) {
        _controller.duration = const Duration(milliseconds: 100);
        _controller.forward();
      } else {
        _controller.duration = const Duration(milliseconds: 500);
        final delayMs = math.min(widget.index * 100, 600);
        if (delayMs == 0) {
          _controller.forward();
        } else {
          _delayTimer = Timer(Duration(milliseconds: delayMs), () {
            if (mounted) _controller.forward();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _badgeBackground(_TimelineNodeKind kind, PutarTheme theme) {
    switch (kind) {
      case _TimelineNodeKind.flagMint:
        return theme.accentMint;
      case _TimelineNodeKind.gameYellow:
        return theme.secondary;
      case _TimelineNodeKind.receiptBlue:
        return theme.accentBlue;
      case _TimelineNodeKind.deletedCoral:
        return theme.danger;
    }
  }

  Widget _buildNodeIcon(_TimelineEntry entry, PutarTheme theme) {
    switch (entry.kind) {
      case _TimelineNodeKind.flagMint:
        return CustomPaint(
          size: const Size(16, 16),
          painter: CustomFlagPainter(
            color: theme.ink,
            strokeWidth: 2.8,
          ),
        );
      case _TimelineNodeKind.gameYellow:
        return GroupHistoryMiniGameIcon(
          game: entry.gameType ?? 'wheel',
          size: 15,
        );
      case _TimelineNodeKind.receiptBlue:
        return CustomPaint(
          size: const Size(16, 16),
          painter: CustomReceiptPainter(
            color: theme.ink,
            strokeWidth: 2.8,
          ),
        );
      case _TimelineNodeKind.deletedCoral:
        return CustomPaint(
          size: const Size(15, 15),
          painter: CustomTrashPainter(
            color: theme.ink,
            strokeWidth: 2.6,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.putarTheme;
    final entry = widget.entry;
    final clock = GroupDateDetailScreen.formatDotTime(entry.timestamp);
    final semanticLabel =
        'Pukul $clock, ${entry.actorName} ${entry.actionText}'
        '${entry.boldTrailing ?? ""}'
        '${entry.subtitle != null ? ". ${entry.subtitle}" : ""}';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final dy = _reduceMotion ? 0.0 : (1.0 - t) * 14.0;
        return Opacity(
          alwaysIncludeSemantics: true,
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Kolom Jam di Kiri (lebar 42px)
                SizedBox(
                  width: 42,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topRight,
                      child: Text(
                        clock,
                        textAlign: TextAlign.right,
                        style: theme.buttonSmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Garis Vertikal & Titik Berikon (27x27)
                SizedBox(
                  width: 27,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          color: theme.ink,
                        ),
                      ),
                      Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          color: _badgeBackground(entry.kind, theme),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.ink,
                            width: theme.borderWidth,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _buildNodeIcon(entry, theme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Kartu Kecil Berisi Avatar (24x24) dan Kalimat Aksi
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: widget.isLast ? 4 : 11),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(theme.cardRadius),
                        border: Border.all(
                          color: theme.ink,
                          width: theme.borderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.ink,
                            offset: theme.miniShadowOffset,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GroupCircleAvatar(
                            name: entry.actorName,
                            color: entry.avatarColor,
                            size: 24,
                            fontSize: 11,
                            borderWidth: 2.5,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: theme.bodySmall.copyWith(
                                      fontSize: 13,
                                      height: 1.25,
                                      color: theme.ink,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${entry.actorName} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(text: entry.actionText),
                                      if (entry.boldTrailing != null)
                                        TextSpan(
                                          text: entry.boldTrailing,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (entry.subtitle != null &&
                                    entry.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    entry.subtitle!,
                                    style: theme.bodySmall.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                      color: theme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

