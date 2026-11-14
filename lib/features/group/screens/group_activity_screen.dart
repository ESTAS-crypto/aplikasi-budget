import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/group/models/group_event_model.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/widgets/activity_tile.dart';
import '../../../core/group/widgets/sync_legend.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/notifications/coordinator/notification_coordinator.dart';
import '../../navigation/app_router.dart';

enum ActivityFilter { semua, roda, catatan, date, anggota }

/// Layar 20: Aktivitas Grup (Grup5.dc.html)
/// Menampilkan log aktivitas realtime (BARU dan SEBELUMNYA), filter, dan arti status sinkron
class GroupActivityScreen extends ConsumerStatefulWidget {
  const GroupActivityScreen({super.key});

  @override
  ConsumerState<GroupActivityScreen> createState() => _GroupActivityScreenState();
}

class _GroupActivityScreenState extends ConsumerState<GroupActivityScreen> {
  ActivityFilter _selectedFilter = ActivityFilter.semua;
  DateTime? _initialReadThreshold;
  DateTime? _markedReadAt;
  DateTime? _preMarkReadAt;
  final Set<String> _knownEventIdsOnOpen = {};
  final Set<String> _liveArrivedIds = {};
  bool _capturedInitialEvents = false;
  String? _activeGid;
  GroupService? _groupService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    if (_activeGid != null) {
      _groupService?.markActivityAsRead(_activeGid!);
      NotificationCoordinator.instance.onScreenClosed(_activeGid!);
    }
    super.dispose();
  }

  void _markAsRead() {
    final gs = ref.read(groupServiceProvider);
    _groupService = gs;
    _activeGid = gs.getActiveGroupId();
    if (_activeGid != null) {
      if (_markedReadAt == null) {
        final now = DateTime.now();
        final members = ref.read(activeGroupMembersStreamProvider).valueOrNull ?? [];
        final authService = ref.read(groupAuthServiceProvider);
        DateTime? preOpen;
        for (final m in members) {
          if (authService.isCurrentUser(m.uid) &&
              m.lastReadAt.millisecondsSinceEpoch > 0 &&
              !m.lastReadAt.isAfter(now.add(const Duration(minutes: 15)))) {
            preOpen = m.lastReadAt;
            break;
          }
        }
        final localRead = gs.getLocalLastReadAt(_activeGid!);
        if (preOpen == null &&
            localRead != null &&
            localRead.millisecondsSinceEpoch > 0 &&
            !localRead.isAfter(now.add(const Duration(minutes: 15)))) {
          preOpen = localRead;
        }
        _preMarkReadAt = preOpen;
        _markedReadAt = now;
      }
      gs.markActivityAsRead(_activeGid!);
      gs.refreshEvents(_activeGid!);
      NotificationCoordinator.instance.onActivityScreenOpened(_activeGid!);
    }
  }

  bool _matchesFilter(GroupEventModel e, ActivityFilter filter) {
    switch (filter) {
      case ActivityFilter.semua:
        return true;
      case ActivityFilter.roda:
        return e.type == GroupEventType.spin ||
            e.type == GroupEventType.gameResult ||
            (e.type == GroupEventType.custom &&
                (e.payload['action'] == 'update_slots' ||
                    e.payload['wheelSlots'] != null));
      case ActivityFilter.catatan:
        return e.type == GroupEventType.expense ||
            e.type == GroupEventType.expenseDeleted;
      case ActivityFilter.date:
        return e.type == GroupEventType.sessionStart ||
            e.type == GroupEventType.sessionEnd ||
            e.type == GroupEventType.budgetChanged ||
            (e.type == GroupEventType.custom &&
                e.payload['action'] != 'update_slots' &&
                e.payload['wheelSlots'] == null);
      case ActivityFilter.anggota:
        return e.type == GroupEventType.memberJoin ||
            e.type == GroupEventType.memberLeave ||
            e.type == GroupEventType.codeChanged;
    }
  }

  List<GroupEventModel> _filterEvents(List<GroupEventModel> events) {
    return events.where((e) => _matchesFilter(e, _selectedFilter)).toList();
  }

  int _countForFilter(List<GroupEventModel> events, ActivityFilter filter) {
    if (filter == ActivityFilter.semua) return events.length;
    return events.where((e) => _matchesFilter(e, filter)).length;
  }

  int _findMemberColorIndex(String actorUid, List<GroupMemberModel> members) {
    final member = members.firstWhere(
      (m) => m.uid == actorUid,
      orElse: () => GroupMemberModel(
        uid: actorUid,
        name: '',
        colorIndex: 0,
        role: 'member',
        joinedAt: DateTime.now(),
        lastReadAt: DateTime.now(),
      ),
    );
    return member.colorIndex;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final authService = ref.watch(groupAuthServiceProvider);
    final currentUid = authService.currentUid;
    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final eventsAsync = ref.watch(activeGroupEventsStreamProvider);

    final gs = ref.read(groupServiceProvider);
    _groupService = gs;
    final activeGid = ref.watch(activeGroupIdProvider);
    _activeGid = activeGid ?? _activeGid;
    final groupAsync = ref.watch(activeGroupStreamProvider);
    final members = membersAsync.valueOrNull ?? [];
    final allEvents = eventsAsync.valueOrNull ??
        (activeGid != null ? gs.getLocalEvents(activeGid) : const <GroupEventModel>[]);
    if (!_capturedInitialEvents && (eventsAsync.hasValue || allEvents.isNotEmpty)) {
      _capturedInitialEvents = true;
      for (final e in allEvents) {
        if (e.eventId.isNotEmpty) {
          _knownEventIdsOnOpen.add(e.eventId);
        }
      }
    } else if (_capturedInitialEvents) {
      for (final e in allEvents) {
        if (e.eventId.isNotEmpty && !_knownEventIdsOnOpen.contains(e.eventId)) {
          _liveArrivedIds.add(e.eventId);
        }
      }
    }
    final filteredEvents = _filterEvents(allEvents);
    final group = groupAsync.valueOrNull;
    final isOwner = (group != null && authService.isCurrentUser(group.ownerUid)) ||
        members.any((m) => m.role == 'owner' && authService.isCurrentUser(m.uid));

    // Jika pengguna sudah dikeluarkan dari grup aktif
    if (activeGid != null && !isOwner && members.isNotEmpty && !members.any((m) => authService.isCurrentUser(m.uid))) {
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
      });
      return Scaffold(
        backgroundColor: t.bg,
        body: const Center(child: SizedBox.shrink()),
      );
    }

    if (activeGid == null) {
      return _buildNoGroupScaffold(t);
    }

    final myMember = members.firstWhere(
      (m) => authService.isCurrentUser(m.uid),
      orElse: () => GroupMemberModel(
        uid: currentUid ?? '',
        name: '',
        colorIndex: 0,
        role: 'member',
        joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
        lastReadAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );

    final now = DateTime.now();
    final maxFutureLimit = now.add(const Duration(minutes: 2));
    final hasValidMemberReadAt = myMember.lastReadAt.millisecondsSinceEpoch > 0 &&
        !myMember.lastReadAt.isAfter(maxFutureLimit);
    final localReadAt = gs.getLocalLastReadAt(activeGid);
    final safeLocalReadAt =
        (localReadAt != null && !localReadAt.isAfter(maxFutureLimit))
            ? localReadAt
            : null;
    final memberReadPredatesOpen = _markedReadAt == null ||
        myMember.lastReadAt.isBefore(_markedReadAt!.subtract(const Duration(seconds: 1)));

    if (_initialReadThreshold == null) {
      if (hasValidMemberReadAt && memberReadPredatesOpen) {
        _initialReadThreshold = myMember.lastReadAt;
      } else if (_preMarkReadAt != null) {
        _initialReadThreshold = _preMarkReadAt;
      } else if (_markedReadAt == null && safeLocalReadAt != null) {
        _initialReadThreshold = safeLocalReadAt;
      }
    }

    final threshold = _initialReadThreshold ??
        (_markedReadAt == null
            ? (hasValidMemberReadAt
                ? myMember.lastReadAt
                : (safeLocalReadAt ?? DateTime.fromMillisecondsSinceEpoch(0)))
            : (_preMarkReadAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    bool isNewActivity(GroupEventModel e) {
      if (authService.isCurrentUser(e.actorUid)) {
        return false;
      }
      if (e.type == GroupEventType.gameResult && e.payload['valid'] == false) {
        return false;
      }
      if (_liveArrivedIds.contains(e.eventId)) return true;
      return gs.isUnreadEligibleEvent(e, threshold);
    }

    final newEvents = filteredEvents.where(isNewActivity).toList();
    final previousEvents = filteredEvents.where((e) => !isNewActivity(e)).toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Tombol Kembali (46x46) + Judul 22px + Tombol Pengaturan (46x46)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: Row(
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
                          context.go('/roda');
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
                              color: t.shadowColor,
                              offset: t.smallShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: CustomPaint(
                          size: const Size(20, 20),
                          painter: CustomBackIconPainter(
                            color: t.ink,
                            strokeWidth: 2.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aktivitas grup',
                      style: t.displayMedium.copyWith(
                        fontSize: 22,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: 'Pengaturan notifikasi grup',
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        context.push('/group/notifications');
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
                              color: t.shadowColor,
                              offset: t.smallShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: CustomPaint(
                          size: const Size(22, 22),
                          painter: CustomGearPainter(color: t.ink, strokeWidth: 2.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips: "Semua · N", "Roda", "Catatan", "Date", "Anggota"
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip(
                    t,
                    'Semua',
                    ActivityFilter.semua,
                    count: allEvents.length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    t,
                    'Roda',
                    ActivityFilter.roda,
                    count: _countForFilter(allEvents, ActivityFilter.roda),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    t,
                    'Catatan',
                    ActivityFilter.catatan,
                    count: _countForFilter(allEvents, ActivityFilter.catatan),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    t,
                    'Date',
                    ActivityFilter.date,
                    count: _countForFilter(allEvents, ActivityFilter.date),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    t,
                    'Anggota',
                    ActivityFilter.anggota,
                    count: _countForFilter(allEvents, ActivityFilter.anggota),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Daftar Aktivitas & Status Sinkronisasi
            Expanded(
              child: RefreshIndicator(
                color: t.ink,
                backgroundColor: t.secondary,
                onRefresh: () async {
                  await Future.wait([
                    gs.refreshEvents(activeGid),
                    gs.fetchGroup(activeGid),
                  ]);
                },
                child: allEvents.isEmpty
                    ? _buildEmptyState(t)
                    : filteredEvents.isEmpty
                        ? _buildFilteredEmptyState(t)
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Bagian BARU (Grup5.dc.html)
                                if (newEvents.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 6),
                                    child: Text(
                                      'BARU',
                                      style: t.bodySmall.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        color: t.ink.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ),
                                  ...newEvents.map((e) => ActivityTile(
                                        event: e,
                                        isUnread: true,
                                        isMe: authService.isCurrentUser(e.actorUid),
                                        colorIndex: _findMemberColorIndex(e.actorUid, members),
                                        onTap: _resolveEventTap(context, e, activeGid),
                                      )),
                                  const SizedBox(height: 12),
                                ],

                                // 2. Bagian SEBELUMNYA
                                if (previousEvents.isNotEmpty) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: t.surface,
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(color: t.ink, width: t.subtleBorderWidth),
                                      ),
                                      child: Text(
                                        'SEBELUMNYA',
                                        style: t.buttonSmall.copyWith(
                                          fontSize: 11,
                                          fontWeight: t.weightExtraBold,
                                          color: t.ink,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...previousEvents.map((e) => ActivityTile(
                                        event: e,
                                        isUnread: false,
                                        isMe: authService.isCurrentUser(e.actorUid),
                                        colorIndex: _findMemberColorIndex(e.actorUid, members),
                                        onTap: _resolveEventTap(context, e, activeGid),
                                      )),
                                  const SizedBox(height: 16),
                                ],

                                // 3. Kartu Bawah: Arti Status Sinkron (Grup5.dc.html)
                                const SyncLegend(isCard: true),
                              ],
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(PutarTheme t, String label, ActivityFilter filter, {int? count}) {
    final isSelected = _selectedFilter == filter;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Filter $label',
      child: GestureDetector(
        onTap: () {
          SoundService.instance.play(Sfx.uiTap);
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? t.secondary : t.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: t.ink, width: t.borderWidth),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: t.shadowColor,
                      offset: t.smallShadowOffset,
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: t.buttonSmall.copyWith(
                  fontSize: 13,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
              if (count != null && count > 0)
                Text(
                  ' · $count',
                  style: t.buttonSmall.copyWith(
                    fontSize: 13,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _resolveEventTap(
    BuildContext context,
    GroupEventModel e,
    String activeGid,
  ) {
    final isWheelSlots = e.type == GroupEventType.custom &&
        (e.payload['action'] == 'update_slots' || e.payload['wheelSlots'] != null);
    if (e.type == GroupEventType.budgetChanged || isWheelSlots) {
      return () {
        SoundService.instance.play(Sfx.uiTap);
        context.push('/group/budget-settings/$activeGid');
      };
    }
    if (e.type == GroupEventType.memberJoin ||
        e.type == GroupEventType.memberLeave ||
        e.type == GroupEventType.codeChanged) {
      return () {
        SoundService.instance.play(Sfx.uiTap);
        context.push('/group/invite/$activeGid');
      };
    }
    if (e.sessionId.isNotEmpty) {
      final isNote = e.type == GroupEventType.expense ||
          e.type == GroupEventType.expenseDeleted;
      return () {
        SoundService.instance.play(Sfx.uiTap);
        final suffix = isNote ? '?tab=catatan' : '';
        context.push('/group/history/$activeGid/${e.sessionId}$suffix');
      };
    }
    return null;
  }

  Widget _buildEmptyState(PutarTheme t) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: t.surface,
              shape: BoxShape.circle,
              border: Border.all(color: t.ink, width: t.borderWidth),
              boxShadow: [
                BoxShadow(
                  color: t.shadowColor,
                  offset: t.smallShadowOffset,
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(36, 36),
              painter: CustomClockPainter(
                color: t.textDisabled,
                strokeWidth: 2.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada aktivitas',
            style: t.titleMedium.copyWith(fontSize: 18, fontWeight: t.weightExtraBold),
          ),
          const SizedBox(height: 6),
          Text(
            'Putaran roda dan pengeluaran belanja yang dicatat bersama akan muncul di sini.',
            style: t.bodySmall.copyWith(
              color: t.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const SyncLegend(isCard: true),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState(PutarTheme t) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: t.surface,
              shape: BoxShape.circle,
              border: Border.all(color: t.ink, width: t.borderWidth),
              boxShadow: [
                BoxShadow(
                  color: t.shadowColor,
                  offset: t.smallShadowOffset,
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(36, 36),
              painter: CustomClockPainter(
                color: t.textDisabled,
                strokeWidth: 2.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada notifikasi di kategori ini',
            textAlign: TextAlign.center,
            style: t.titleMedium.copyWith(fontSize: 18, fontWeight: t.weightExtraBold),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba pilih kategori lain atau tampilkan semua aktivitas grup.',
            textAlign: TextAlign.center,
            style: t.bodySmall.copyWith(
              color: t.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          StickerButton(
            text: 'Tampilkan Semua',
            backgroundColor: t.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            onPressed: () {
              setState(() {
                _selectedFilter = ActivityFilter.semua;
              });
            },
          ),
          const SizedBox(height: 24),
          const SyncLegend(isCard: true),
        ],
      ),
    );
  }

  Widget _buildNoGroupScaffold(PutarTheme t) {
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: CustomPaint(
            size: const Size(22, 22),
            painter: CustomBackArrowPainter(color: t.ink),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'Aktivitas Grup',
          style: t.titleMedium.copyWith(color: t.ink),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: t.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.ink, width: t.borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: t.shadowColor,
                      offset: t.smallShadowOffset,
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: CustomPaint(
                  size: const Size(36, 36),
                  painter: CustomBellPainter(color: t.ink, strokeWidth: 2.8),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum Ada Notifikasi Grup',
                style: t.titleMedium.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gabung atau buat grup bersama teman untuk melihat riwayat putar roda, catatan belanja, dan aktivitas grup.',
                style: t.bodyMedium.copyWith(
                  color: t.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              StickerButton.large(
                text: 'BUAT ATAU GABUNG GRUP',
                backgroundColor: t.secondary,
                onPressed: () => context.push('/group/join-or-create'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
