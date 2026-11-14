import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group/models/group_event_model.dart';
import '../../../core/group/models/group_history_models.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/sync/sync_state.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/group/widgets/sync_strip.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/indonesian_date_formatter.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/sticker_button.dart';

/// Provider filter Riwayat Grup (Semua / Lolos / Lewat) agar tetap bertahan
/// saat pengguna membuka Layar 63 lalu kembali ke Layar 62.
final groupHistoryFilterProvider = StateProvider<GroupHistoryFilter>(
  (ref) => GroupHistoryFilter.semua,
);

/// Provider batas jumlah sesi yang ditampilkan (bertambah 30 tiap muat)
final groupHistoryDisplayLimitProvider = StateProvider<int>((ref) => 30);

/// Layar 62: Riwayat Grup (Daftar Date & Filter)
/// Acuan visual: design/source/Rgrup1.dc.html
class GroupHistoryView extends ConsumerStatefulWidget {
  const GroupHistoryView({super.key});

  @override
  ConsumerState<GroupHistoryView> createState() => _GroupHistoryViewState();
}

class _GroupHistoryViewState extends ConsumerState<GroupHistoryView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 160) {
      final currentLimit = ref.read(groupHistoryDisplayLimitProvider);
      final sessions = ref.read(activeGroupSessionsStreamProvider).valueOrNull ?? [];
      if (currentLimit < sessions.length) {
        ref.read(groupHistoryDisplayLimitProvider.notifier).state = currentLimit + 30;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 340 ? 16.0 : 24.0;
    final unreadCount = ref.watch(unreadActivityCountProvider);
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final groupService = ref.watch(groupServiceProvider);

    final group = activeGroupAsync.valueOrNull ??
        (activeGroupId != null && activeGroupId.isNotEmpty
            ? groupService.getLocalGroup(activeGroupId)
            : null);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: group == null
            ? _buildNoGroupView(context, horizontalPad, unreadCount)
            : _buildGroupHistoryContent(context, group, horizontalPad, unreadCount),
      ),
    );
  }

  Widget _buildNoGroupView(
    BuildContext context,
    double horizontalPad,
    int unreadCount,
  ) {
    final t = context.putarTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopHeader(context, unreadCount),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ScopeSwitcher(
              currentScope: AppScope.grup,
              onScopeChanged: (scope) {
                ref.read(appScopeProvider.notifier).state = scope;
              },
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: t.secondary,
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
                    size: const Size(32, 32),
                    painter: CustomCrownPainter(
                      color: t.ink,
                      strokeWidth: 2.8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum Bergabung Grup',
                  style: t.titleMedium.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Buat atau gabung grup terlebih dahulu untuk melihat riwayat date bersama teman.',
                  style: t.bodySmall.copyWith(
                    color: t.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                StickerButton.large(
                  text: 'BUAT ATAU GABUNG GRUP',
                  backgroundColor: t.secondary,
                  onPressed: () => context.push('/group/join-or-create'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHistoryContent(
    BuildContext context,
    GroupModel group,
    double horizontalPad,
    int unreadCount,
  ) {
    final t = context.putarTheme;
    final sessionsAsync = ref.watch(activeGroupSessionsStreamProvider);
    final selectedFilter = ref.watch(groupHistoryFilterProvider);
    final displayLimit = ref.watch(groupHistoryDisplayLimitProvider);
    final groupService = ref.watch(groupServiceProvider);
    final authService = ref.watch(groupAuthServiceProvider);

    final allLocalNotes = groupService.getLocalNotes(group.id);
    final hasPendingWrites = allLocalNotes.any((n) => n.hasPendingWrites);
    final isOffline = ref.watch(groupOfflineModeProvider);
    final hasPendingOrOffline = hasPendingWrites || isOffline;

    final allSessions = sessionsAsync.valueOrNull ?? [];
    final isLoadingInitial = sessionsAsync.isLoading && !sessionsAsync.hasValue;

    // Urutkan terbaru di atas (startedAt descending)
    final sortedSessions = List<GroupSessionModel>.from(allSessions)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final summary = GroupHistoryCalculator.computeOverviewSummary(sortedSessions);

    final filteredSessions = sortedSessions.where((s) {
      switch (selectedFilter) {
        case GroupHistoryFilter.semua:
          return true;
        case GroupHistoryFilter.lolos:
          return s.isLolos;
        case GroupHistoryFilter.lewat:
          return s.isLewat;
      }
    }).toList();

    final visibleSessions = filteredSessions.take(displayLimit).toList();
    final hasMore = filteredSessions.length > visibleSessions.length;

    return Column(
      children: [
        if (hasPendingOrOffline)
          SyncStrip(
            state: hasPendingWrites ? SyncState.menunggu : SyncState.offline,
            isVisible: true,
          ),
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey<String>('group_history_scroll_62'),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Header ("Riwayat" + Lonceng + Roda Gigi)
                _buildTopHeader(context, unreadCount),
                const SizedBox(height: 10),

                // 2. Pemilih Pribadi / Grup (ScopeSwitcher + Nama Grup sesuai Rgrup1.dc.html)
                _buildScopePillSelector(t, group),
                const SizedBox(height: 10),

                // 3. Kartu Ringkasan Matahari ("Date Jumat · 4 date", "2 lolos, 2 lewat", "Rata-rata budget")
                _buildSummaryCard(t, group, summary, hasPendingOrOffline),
                const SizedBox(height: 10),

                // 4. Baris Chip Filter ("Semua · N", "Lolos", "Lewat") - Bisa digeser horizontal
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _FilterChipButton(
                        label: 'Semua · ${sortedSessions.length}',
                        isSelected: selectedFilter == GroupHistoryFilter.semua,
                        onTap: () {
                          ref.read(groupHistoryFilterProvider.notifier).state =
                              GroupHistoryFilter.semua;
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Lolos',
                        isSelected: selectedFilter == GroupHistoryFilter.lolos,
                        onTap: () {
                          ref.read(groupHistoryFilterProvider.notifier).state =
                              GroupHistoryFilter.lolos;
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Lewat',
                        isSelected: selectedFilter == GroupHistoryFilter.lewat,
                        onTap: () {
                          ref.read(groupHistoryFilterProvider.notifier).state =
                              GroupHistoryFilter.lewat;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Daftar Kartu Date / Loading Skeleton / Kosong
                if (isLoadingInitial)
                  _buildLoadingSkeletonList(t)
                else if (visibleSessions.isEmpty)
                  _buildEmptyStateCard(t)
                else ...[
                  ...List.generate(visibleSessions.length, (index) {
                    final session = visibleSessions[index];
                    final isCurrentUserBudget =
                        authService.isCurrentUser(session.budgetByUid);
                    final actorDisplayName = isCurrentUserBudget
                        ? 'Kamu'
                        : (session.budgetByName.trim().isNotEmpty
                            ? session.budgetByName.trim()
                            : 'Anggota');

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == visibleSessions.length - 1 ? 0 : 8,
                      ),
                      child: GroupDateHistoryCard(
                        key: ValueKey('hist_card_${session.sessionId}'),
                        index: index,
                        session: session,
                        actorDisplayName: actorDisplayName,
                        onTap: () {
                          SoundService.instance.play(Sfx.uiTap);
                          context.push(
                            '/group/history/${group.id}/${session.sessionId}',
                          );
                        },
                      ),
                    );
                  }),
                  if (hasMore) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          SoundService.instance.play(Sfx.uiTap);
                          ref
                              .read(groupHistoryDisplayLimitProvider.notifier)
                              .state = displayLimit + 30;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: t.ink,
                              width: t.subtleBorderWidth,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: t.ink,
                                offset: t.miniShadowOffset,
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            'Muat lebih banyak (${filteredSessions.length - visibleSessions.length} lagi)',
                            style: t.buttonSmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader(BuildContext context, int unreadCount) {
    final t = context.putarTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Riwayat',
            style: t.displayMedium.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Lonceng Aktivitas Grup
            Semantics(
              label: unreadCount > 0
                  ? 'Aktivitas grup, $unreadCount baru'
                  : 'Aktivitas grup',
              button: true,
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.uiTap);
                  context.push('/group/activity');
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
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
                        size: const Size(21, 21),
                        painter: CustomBellPainter(
                          color: t.ink,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 19),
                          height: 19,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: t.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.ink, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: t.buttonSmall.copyWith(
                              fontSize: 11,
                              color: t.surface,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol Pengaturan Roda Gigi
            Semantics(
              label: 'Pengaturan',
              button: true,
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.uiTap);
                  context.push('/settings');
                },
                child: Container(
                  width: 44,
                  height: 44,
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
                    size: const Size(21, 21),
                    painter: CustomGearPainter(
                      color: t.ink,
                      strokeWidth: 2.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pemilih Pribadi / Grup sesuai Rgrup1.dc.html ("Pribadi" | "Grup · Date Jumat")
  /// dan mendukung ketuk untuk beralih ke Pribadi
  Widget _buildScopePillSelector(PutarTheme t, GroupModel group) {
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
          Expanded(
            child: Semantics(
              button: true,
              selected: false,
              label: 'Beralih ke mode Pribadi',
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.uiTap);
                  HapticFeedback.selectionClick();
                  ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.transparent, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Pribadi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.buttonSmall.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Semantics(
              button: true,
              selected: true,
              label: 'Mode Grup aktif, ${group.name}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: t.secondary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: t.ink, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Grup · ${group.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.buttonSmall.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Ringkasan Matahari sesuai Rgrup1.dc.html
  Widget _buildSummaryCard(
    PutarTheme t,
    GroupModel group,
    GroupHistoryOverviewSummary summary,
    bool hasPendingWrites,
  ) {
    final semanticSummary =
        'Ringkasan ${group.name}, ${summary.totalDates} date. '
        '${summary.lolosCount} lolos, ${summary.lewatCount} lewat. '
        'Rata-rata budget ${RupiahFormatter.format(summary.averageBudget)}.'
        '${hasPendingWrites ? " Belum termasuk catatan terbaru anggota lain." : ""}';

    return Semantics(
      container: true,
      label: semanticSummary,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.name} · ${summary.totalDates} date',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${summary.lolosCount} lolos, ${summary.lewatCount} lewat',
                            style: t.displayMedium.copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rata-rata budget',
                            style: t.bodySmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: t.ink,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          Text(
                            RupiahFormatter.format(summary.averageBudget),
                            style: t.bodyLargeBold.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                              color: t.ink,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (hasPendingWrites) ...[
                const SizedBox(height: 6),
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
      ),
    );
  }

  Widget _buildEmptyStateCard(PutarTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
      alignment: Alignment.center,
      child: Text(
        'Belum ada date selesai',
        textAlign: TextAlign.center,
        style: t.titleMedium.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: t.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeletonList(PutarTheme t) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 8),
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          child: Row(
            children: [
              Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.ink, width: t.borderWidth),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 14,
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Tombol Chip Filter dengan efek membal kecil saat dipilih
class _FilterChipButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterChipButton> createState() => _FilterChipButtonState();
}

class _FilterChipButtonState extends State<_FilterChipButton>
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
  void didUpdateWidget(covariant _FilterChipButton oldWidget) {
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

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Filter ${widget.label}',
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isSelected ? t.secondary : t.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: t.ink, width: t.borderWidth),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: t.ink,
                        offset: t.smallShadowOffset,
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: t.buttonSmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu Date Riwayat Grup yang BISA DIKETUK (Layar 62 - Rgrup1.dc.html)
class GroupDateHistoryCard extends StatefulWidget {
  final int index;
  final GroupSessionModel session;
  final String actorDisplayName;
  final VoidCallback onTap;

  const GroupDateHistoryCard({
    super.key,
    required this.index,
    required this.session,
    required this.actorDisplayName,
    required this.onTap,
  });

  @override
  State<GroupDateHistoryCard> createState() => _GroupDateHistoryCardState();
}

class _GroupDateHistoryCardState extends State<GroupDateHistoryCard>
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

  String _monthShortUpper(DateTime date) {
    final idx = (date.month - 1).clamp(0, 11);
    return IndonesianDateFormatter.months[idx].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.putarTheme;
    final session = widget.session;
    final isLolos = session.isLolos;
    final dateTitle = IndonesianDateFormatter.fullDayAndDate(session.startedAt);
    final gameLabel = GroupEventModel.formatGameName(session.game);
    final budgetText = 'Budget ${RupiahFormatter.format(session.budget)}';
    final spentText = 'Terpakai ${RupiahFormatter.format(session.totalSpent)}';
    final statusBadgeText = isLolos
        ? 'Lolos'
        : GroupHistoryCalculator.formatLewatBadge(session.overBudgetAmount);

    final semanticLabel =
        '$dateTitle. ${widget.actorDisplayName}, $gameLabel. '
        '$budgetText, $spentText. Status: $statusBadgeText.';

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
                borderRadius: BorderRadius.circular(22),
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
                  // 1. Blok Tanggal Kiri (50x54, Mint untuk Lolos, Tomat untuk Lewat)
                  Container(
                    width: 50,
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLolos ? theme.accentMint : theme.danger,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.ink, width: theme.borderWidth),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${session.startedAt.day}',
                            style: theme.titleLarge.copyWith(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              color: theme.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _monthShortUpper(session.startedAt),
                            style: theme.buttonSmall.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              color: theme.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. Kolom Tengah (Judul Tanggal, Ikon Permainan + Nama, Chip Budget & Terpakai)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyLargeBold.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            GroupHistoryMiniGameIcon(
                              game: session.game,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${widget.actorDisplayName} · $gameLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _buildMiniMetricPill(
                              theme,
                              text: budgetText,
                              backgroundColor: theme.surface,
                            ),
                            _buildMiniMetricPill(
                              theme,
                              text: spentText,
                              backgroundColor: theme.secondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 3. Kolom Kanan (Lencana Lolos / Lewat Rp12rb + Panah Kanan)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isLolos ? theme.accentMint : theme.danger,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: theme.ink, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLolos) ...[
                                  CustomPaint(
                                    size: const Size(13, 13),
                                    painter: CustomCheckIconPainter(
                                      color: theme.ink,
                                      strokeWidth: 3.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  statusBadgeText,
                                  style: theme.buttonSmall.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: theme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetricPill(
    PutarTheme t, {
    required String text,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.ink, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: t.buttonSmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
      ),
    );
  }
}

/// Ikon Vektor Permainan Kecil (16x16 / 26x26) sesuai SVG di Rgrup1..Rgrup4.dc.html
class GroupHistoryMiniGameIcon extends StatelessWidget {
  final String game;
  final double size;

  const GroupHistoryMiniGameIcon({
    super.key,
    required this.game,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniGameIconPainter(game: game, theme: t),
      ),
    );
  }
}

class _MiniGameIconPainter extends CustomPainter {
  final String game;
  final PutarTheme theme;

  const _MiniGameIconPainter({
    required this.game,
    this.theme = PutarTheme.pasarMalam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (game.toLowerCase().trim()) {
      case 'dice':
      case 'dadu':
        // <rect x="3.5" y="3.5" width="17" height="17" rx="4.5" fill="#6FB1FF" stroke="#22163A" stroke-width="2"/>
        final rrect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.5, 3.5, 17, 17),
          const Radius.circular(4.5),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = theme.accentBlue
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(rrect, strokePaint);
        final dotPaint = Paint()
          ..color = theme.ink
          ..style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(9, 9), 1.5, dotPaint);
        canvas.drawCircle(const Offset(12, 12), 1.5, dotPaint);
        canvas.drawCircle(const Offset(15, 15), 1.5, dotPaint);
        break;

      case 'capsule':
      case 'kapsul':
        // <g transform="rotate(35 12 12)"><rect x="7" y="2.5" width="10" height="19" rx="5".../>
        canvas.translate(12, 12);
        canvas.rotate(35 * math.pi / 180);
        canvas.translate(-12, -12);
        final fullRRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(7, 2.5, 10, 19),
          const Radius.circular(5),
        );
        canvas.drawRRect(
          fullRRect,
          Paint()
            ..color = theme.surface
            ..style = PaintingStyle.fill,
        );
        final topPath = Path()
          ..moveTo(7, 12)
          ..lineTo(7, 7.5)
          ..arcTo(const Rect.fromLTWH(7, 2.5, 10, 10), math.pi, math.pi, false)
          ..lineTo(17, 12)
          ..close();
        canvas.drawPath(
          topPath,
          Paint()
            ..color = theme.accentPink
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(topPath, strokePaint);
        canvas.drawRRect(fullRRect, strokePaint);
        break;

      case 'envelope':
      case 'amplop':
        // <rect x="3" y="6" width="18" height="13" rx="3" fill="#3DDBB0".../>
        final envRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 6, 18, 13),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          envRect,
          Paint()
            ..color = theme.accentMint
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(envRect, strokePaint);
        final flap = Path()
          ..moveTo(3.5, 7.5)
          ..lineTo(12, 14)
          ..lineTo(20.5, 7.5);
        canvas.drawPath(flap, strokePaint);
        break;

      case 'coin':
      case 'koin':
        canvas.drawCircle(
          const Offset(12, 12),
          8.5,
          Paint()
            ..color = theme.accentOrange
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(const Offset(12, 12), 8.5, strokePaint);
        canvas.drawCircle(const Offset(12, 12), 5.0, strokePaint);
        break;

      case 'fixed':
      case 'tetap':
        final rect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(3.5, 5.5, 17, 13),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = theme.accentMint
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(rect, strokePaint);
        canvas.drawCircle(const Offset(12, 12), 2.5, strokePaint);
        break;

      case 'wheel':
      case 'roda':
      default:
        // <circle cx="12" cy="12" r="8.5" fill="#FFD23F" stroke="#22163A" stroke-width="2"/>
        // <path d="M12 12V3.5M12 12l7.4 4.3M12 12l-7.4 4.3"/>
        canvas.drawCircle(
          const Offset(12, 12),
          8.5,
          Paint()
            ..color = theme.secondary
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(const Offset(12, 12), 8.5, strokePaint);
        canvas.drawLine(const Offset(12, 12), const Offset(12, 3.5), strokePaint);
        canvas.drawLine(
          const Offset(12, 12),
          const Offset(19.4, 16.3),
          strokePaint,
        );
        canvas.drawLine(
          const Offset(12, 12),
          const Offset(4.6, 16.3),
          strokePaint,
        );
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniGameIconPainter oldDelegate) =>
      oldDelegate.game != game || oldDelegate.theme != theme;
}

