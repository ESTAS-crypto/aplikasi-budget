import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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

enum ActivityFilter { semua, roda, catatan }

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
  String? _activeGid;

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
      NotificationCoordinator.instance.onScreenClosed(_activeGid!);
    }
    super.dispose();
  }

  void _markAsRead() {
    _activeGid = ref.read(groupServiceProvider).getActiveGroupId();
    if (_activeGid != null) {
      ref.read(groupServiceProvider).markActivityAsRead(_activeGid!);
      NotificationCoordinator.instance.onActivityScreenOpened(_activeGid!);
    }
  }

  List<GroupEventModel> _filterEvents(List<GroupEventModel> events) {
    switch (_selectedFilter) {
      case ActivityFilter.semua:
        return events;
      case ActivityFilter.roda:
        return events.where((e) => e.type == GroupEventType.spin).toList();
      case ActivityFilter.catatan:
        return events.where((e) => e.type == GroupEventType.expense).toList();
    }
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
    final authService = ref.watch(groupAuthServiceProvider);
    final currentUid = authService.currentUid;
    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final eventsAsync = ref.watch(activeGroupEventsStreamProvider);

    final members = membersAsync.valueOrNull ?? [];
    final allEvents = eventsAsync.valueOrNull ?? [];
    final filteredEvents = _filterEvents(allEvents);

    final activeGid = ref.watch(activeGroupIdProvider);
    final groupAsync = ref.watch(activeGroupStreamProvider);
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
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: SizedBox.shrink()),
      );
    }

    if (activeGid == null) {
      return _buildNoGroupScaffold();
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

    if (_initialReadThreshold == null && myMember.lastReadAt.millisecondsSinceEpoch > 0) {
      _initialReadThreshold = myMember.lastReadAt;
    }

    final threshold = _initialReadThreshold ?? myMember.lastReadAt;
    final newEvents = filteredEvents.where((e) => !authService.isCurrentUser(e.actorUid) && e.createdAt.isAfter(threshold)).toList();
    final previousEvents = filteredEvents.where((e) => authService.isCurrentUser(e.actorUid) || !e.createdAt.isAfter(threshold)).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
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
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3.0),
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
                          size: Size(20, 20),
                          painter: CustomBackIconPainter(strokeWidth: 2.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aktivitas grup',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
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
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3.0),
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
                          size: Size(22, 22),
                          painter: CustomGearPainter(color: AppColors.ink, strokeWidth: 2.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips: "Semua · N", "Roda", "Catatan" (Grup5.dc.html)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('Semua', ActivityFilter.semua, count: allEvents.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Roda', ActivityFilter.roda),
                  const SizedBox(width: 8),
                  _buildFilterChip('Catatan', ActivityFilter.catatan),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Daftar Aktivitas & Status Sinkronisasi
            Expanded(
              child: filteredEvents.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
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
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  color: AppColors.ink.withValues(alpha: 0.65),
                                ),
                              ),
                            ),
                            ...newEvents.map((e) => ActivityTile(
                                  event: e,
                                  isUnread: true,
                                  isMe: authService.isCurrentUser(e.actorUid),
                                  colorIndex: _findMemberColorIndex(e.actorUid, members),
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: AppColors.ink, width: 2.5),
                                ),
                                child: Text(
                                  'SEBELUMNYA',
                                  style: AppTypography.buttonSmall.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
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
                                )),
                            const SizedBox(height: 16),
                          ],

                          // 3. Kartu Bawah: Arti Status Sinkron (Grup5.dc.html)
                          const SyncLegend(isCard: true),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ActivityFilter filter, {int? count}) {
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
            color: isSelected ? AppColors.matahari : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.ink, width: 3.0),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(3, 3),
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
                style: AppTypography.buttonSmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              if (count != null && count > 0)
                Text(
                  ' · $count',
                  style: AppTypography.buttonSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 3.0),
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
              painter: CustomClockPainter(
                color: AppColors.disabled,
                strokeWidth: 2.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada aktivitas',
            style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Putaran roda dan pengeluaran belanja yang dicatat bersama akan muncul di sini.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
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

  Widget _buildNoGroupScaffold() {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const CustomPaint(
            size: Size(22, 22),
            painter: CustomBackArrowPainter(color: AppColors.ink),
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
          style: AppTypography.titleMedium.copyWith(color: AppColors.ink),
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
                  painter: CustomBellPainter(color: AppColors.ink, strokeWidth: 2.8),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum Ada Notifikasi Grup',
                style: AppTypography.titleMedium.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gabung atau buat grup bersama teman untuk melihat riwayat putar roda, catatan belanja, dan aktivitas grup.',
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
