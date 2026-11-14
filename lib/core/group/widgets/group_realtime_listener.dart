import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/sound_service.dart';
import '../../utils/rupiah_formatter.dart';
import '../models/group_event_model.dart';
import '../models/group_member_model.dart';
import '../services/group_auth_service.dart';
import '../services/group_service.dart';
import '../services/group_notification_settings_service.dart';
import 'in_app_banner.dart';
import 'group_important_dialog.dart';
import 'scope_switcher.dart';
import '../../../features/group/screens/group_date_result_screen.dart';
import '../../../features/navigation/app_router.dart';
import '../../../features/notifications/notification_service.dart';
import '../../notifications/notifications.dart';
import '../models/live_play_model.dart';
import '../services/clock_sync_service.dart';
import 'live_spin_overlay.dart';

/// Global Realtime Listener untuk Notifikasi Aktivitas Grup (Layar 18-21 & InAppBanner)
/// Menghubungkan Supabase/Firestore group_events ke InAppBanner dan Notifikasi Sistem Android.
class GroupRealtimeNotificationListener extends ConsumerStatefulWidget {
  final Widget child;
  final ValueChanged<String>? onNavigateRoute;

  const GroupRealtimeNotificationListener({
    super.key,
    required this.child,
    this.onNavigateRoute,
  });

  @override
  ConsumerState<GroupRealtimeNotificationListener> createState() =>
      _GroupRealtimeNotificationListenerState();
}

class _GroupRealtimeNotificationListenerState
    extends ConsumerState<GroupRealtimeNotificationListener>
    with WidgetsBindingObserver {
  final Set<String> _seenEventIds = {};
  bool _isFirstEventSnapshot = true;
  String? _currentListeningGid;
  late final DateTime _listenerStartTime;
  bool _isEvicting = false;
  LivePlayModel? _activeLivePlay;
  String? _lastDismissedSpinId;

  void _evictUserFromGroup({required String groupName}) {
    if (_isEvicting) return;
    _isEvicting = true;

    // Reset status grup dan scope segera
    ref.read(groupServiceProvider).setActiveGroupId(null);
    ref.read(activeGroupIdProvider.notifier).state = null;
    ref.read(appScopeProvider.notifier).state = AppScope.pribadi;

    final overlayContext = rootNavigatorKey.currentContext ?? context;

    // Arahkan keluar dari layar grup manapun ke root / mode pribadi
    try {
      Navigator.of(overlayContext, rootNavigator: true).popUntil((route) => route.isFirst);
      overlayContext.go('/');
    } catch (_) {
      try {
        overlayContext.go('/');
      } catch (_) {}
    }

    GroupImportantDialog.showKickedFromGroup(
      overlayContext,
      groupName: groupName,
      onConfirm: () {
        try {
          Navigator.of(overlayContext, rootNavigator: true).popUntil((route) => route.isFirst);
          overlayContext.go('/');
        } catch (_) {}
      },
    ).then((_) {
      _isEvicting = false;
    });
  }

  void _maybeOpenGroupResultScreen({
    required String gid,
    required String groupName,
    required GroupEventModel evt,
    required bool isMe,
  }) {
    if (isMe) return;
    if (NotificationCoordinator.instance.currentLifecycleState !=
        AppLifecycleState.resumed) {
      return;
    }
    if (ref.read(groupOfflineModeProvider)) return;

    final endedSid =
        (evt.payload['endedSessionId'] ?? evt.payload['sessionId'])
                ?.toString() ??
            '';
    if (endedSid.isEmpty) return;

    final age = DateTime.now().difference(evt.createdAt).abs();
    if (age > const Duration(seconds: 30)) {
      return;
    }

    final groupService = ref.read(groupServiceProvider);
    if (groupService.hasShownResultForSession(gid, endedSid)) return;

    final customNavigate = widget.onNavigateRoute;
    final navCtx = rootNavigatorKey.currentContext;
    if (customNavigate == null && (navCtx == null || !navCtx.mounted)) {
      return;
    }
    final contextRouter = navCtx != null ? GoRouter.maybeOf(navCtx) : null;
    final hasMountedAppRouter = navCtx != null &&
        navCtx.mounted &&
        appRouter.routerDelegate.currentConfiguration.matches.isNotEmpty;
    if (customNavigate == null &&
        contextRouter == null &&
        !hasMountedAppRouter) {
      return;
    }

    groupService.markResultAsShown(gid, endedSid);

    final sessions = groupService.getLocalSessions(gid);
    final matched =
        sessions.where((s) => s.sessionId == endedSid).firstOrNull;
    final budget =
        (evt.payload['budget'] as num?)?.toInt() ?? matched?.budget ?? 0;
    final totalSpent = (evt.payload['totalSpent'] as num?)?.toInt() ??
        matched?.totalSpent ??
        0;
    final noteCount = (evt.payload['noteCount'] as num?)?.toInt() ??
        groupService
            .getLocalNotes(gid)
            .where((n) => !n.deleted && n.sessionId == endedSid)
            .length;

    final uri = buildGroupDateResultUri(
      groupName: groupName,
      budget: budget,
      totalSpent: totalSpent,
      itemCount: noteCount,
      groupId: gid,
      sessionId: endedSid,
      budgetByName:
          evt.payload['budgetByName']?.toString() ?? matched?.budgetByName,
      budgetGame: evt.payload['game']?.toString() ?? matched?.game,
      endedByName: evt.payload['endedByName']?.toString() ?? evt.actorName,
      endedByUid: evt.payload['endedByUid']?.toString() ?? evt.actorUid,
      sessionDate: matched?.startedAt ?? evt.createdAt,
      endedAt: evt.createdAt,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (customNavigate != null) {
        customNavigate(uri.toString());
        return;
      }
      final ctx = rootNavigatorKey.currentContext;
      final router = ctx != null && ctx.mounted ? GoRouter.maybeOf(ctx) : null;
      if (router != null) {
        router.push(uri.toString());
      } else if (ctx != null &&
          ctx.mounted &&
          appRouter.routerDelegate.currentConfiguration.matches.isNotEmpty) {
        appRouter.push(uri.toString());
      }
    });
  }

  ClockSyncService? _clockSyncService;
  bool Function(String gid)? _boundGroupMutedGetter;
  bool Function(NotificationCategory category)? _boundCategoryEnabledGetter;

  @override
  void initState() {
    super.initState();
    _listenerStartTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    final coordinator = NotificationCoordinator.instance;
    if (identical(coordinator.isGroupMutedGetter, _boundGroupMutedGetter)) {
      coordinator.isGroupMutedGetter = null;
    }
    if (identical(
      coordinator.isCategoryEnabledGetter,
      _boundCategoryEnabledGetter,
    )) {
      coordinator.isCategoryEnabledGetter = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _clockSyncService?.stopPeriodicSync();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationCoordinator.instance.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final gid = _currentListeningGid;
      if (gid != null && gid.isNotEmpty) {
        final gs = ref.read(groupServiceProvider);
        gs.reconnectAndRefresh(gid);
        unawaited(gs.updatePresence(gid));
      }
    }
  }

  void _loadSeenEventIdsSync(String gid, SharedPreferences prefs) {
    try {
      final saved = prefs.getStringList('seen_group_events_$gid') ?? [];
      _seenEventIds.addAll(saved);
    } catch (_) {}
  }

  Future<void> _saveSeenEventIds(String gid, SharedPreferences prefs) async {
    try {
      final list = _seenEventIds.toList();
      final toSave = list.length > 200 ? list.sublist(list.length - 200) : list;
      await prefs.setStringList('seen_group_events_$gid', toSave);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final activeGid = ref.watch(activeGroupIdProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    if (activeGid != _currentListeningGid) {
      _currentListeningGid = activeGid;
      _isFirstEventSnapshot = true;
      _seenEventIds.clear();
      if (activeGid != null && activeGid.isNotEmpty) {
        _loadSeenEventIdsSync(activeGid, prefs);
        final gs = ref.read(groupServiceProvider);
        gs.ensureRealtimeActive(activeGid);
        unawaited(gs.updatePresence(activeGid));
        unawaited(NotificationService.instance.ensureAndroidPermissionIfNeeded());
        _clockSyncService = ref.read(clockSyncServiceProvider);
        _clockSyncService!.startPeriodicSync(
          activeGid,
          firestore: gs.firestore,
          supabase: gs.supabase,
          uid: ref.read(groupAuthServiceProvider).currentUid,
        );
      } else {
        _clockSyncService?.stopPeriodicSync();
      }
    }

    // Konfigurasi delegate filter di NotificationCoordinator
    final coordinator = ref.read(notificationCoordinatorProvider);
    final auth = ref.watch(groupAuthServiceProvider);
    coordinator.currentUidGetter = () => auth.currentUid ?? auth.fallbackUid;
    coordinator.isCurrentUserGetter = (uid) => auth.isCurrentUser(uid);
    _boundGroupMutedGetter = (gid) {
      if (!mounted) return false;
      if (activeGid != null && activeGid == gid) {
        final notifSettings = ref.read(groupNotificationSettingsProvider(activeGid));
        return notifSettings.isCurrentlyMuted;
      }
      return false;
    };
    coordinator.isGroupMutedGetter = _boundGroupMutedGetter;
    _boundCategoryEnabledGetter = (cat) {
      if (!mounted) return true;
      if (activeGid != null) {
        final notifSettings = ref.read(groupNotificationSettingsProvider(activeGid));
        switch (cat) {
          case NotificationCategory.expense:
          case NotificationCategory.expenseDeleted:
            return notifSettings.notifyExpenses;
          case NotificationCategory.spin:
            return notifSettings.notifySpin;
          case NotificationCategory.budgetWarning80:
          case NotificationCategory.budgetOver:
            return notifSettings.notifyWarning80;
          case NotificationCategory.sessionEnd:
            return notifSettings.notifyDateComplete;
          case NotificationCategory.memberJoin:
          case NotificationCategory.memberLeave:
            return notifSettings.notifyMembers;
          default:
            return true;
        }
      }
      return true;
    };
    coordinator.isCategoryEnabledGetter = _boundCategoryEnabledGetter;

    // Pantau keanggotaan untuk dialog DIKELUARKAN (Notif3.dc.html)
    ref.listen<AsyncValue<List<GroupMemberModel>>>(
      activeGroupMembersStreamProvider,
      (previous, next) {
        if (!mounted || activeGid == null || activeGid.isEmpty) return;
        final members = next.valueOrNull;
        if (members == null || members.isEmpty) return;

        final authService = ref.read(groupAuthServiceProvider);

        final group = ref.read(activeGroupStreamProvider).valueOrNull;

        // 1. ATURAN MUTLAK: Pemilik grup TIDAK PERNAH bisa dikeluarkan dari grupnya sendiri!
        if (group != null && authService.isCurrentUser(group.ownerUid)) {
          return;
        }

        // Cek jika member ber-role 'owner' cocok dengan user saat ini
        final isOwnerMember = members.any((m) => m.role == 'owner' && authService.isCurrentUser(m.uid));
        if (isOwnerMember) {
          return;
        }

        // Pengaman: Jangan evict pada snapshot pertama saat baru masuk/memuat data
        final prevMembers = previous?.valueOrNull;
        if (prevMembers == null || prevMembers.isEmpty) {
          return;
        }

        final wasInGroup = prevMembers.any((m) => authService.isCurrentUser(m.uid));
        final isCurrentlyInGroup = members.any((m) => authService.isCurrentUser(m.uid));

        // Hanya evict jika sebelumnya sudah terkonfirmasi ada di dalam grup,
        // lalu sekarang tidak ada lagi (artinya telah dikeluarkan oleh pemilik)
        if (wasInGroup && !isCurrentlyInGroup) {
          final groupName = group?.name ?? 'grup ini';
          _evictUserFromGroup(groupName: groupName);
          return;
        }
      },
    );

    // Dengarkan event stream secara reaktif menggunakan ref.listen
    ref.listen<AsyncValue<List<GroupEventModel>>>(
      activeGroupEventsStreamProvider,
      (previous, next) async {
        if (!mounted || activeGid == null || activeGid.isEmpty) return;
        final events = next.valueOrNull;
        if (events == null || events.isEmpty) return;

        // 1. Snapshot pertama saat membuka/masuk grup: tandai event historis (>15 detik lalu) agar tidak spam ulang,
        //    sedangkan snapshot realtime berikutnya mengizinkan event dengan clock skew ringan hingga 5 menit.
        if (_isFirstEventSnapshot) {
          final initialCutoff = _listenerStartTime.subtract(const Duration(seconds: 15));
          for (final evt in events) {
            if (evt.eventId.isNotEmpty && evt.createdAt.isBefore(initialCutoff)) {
              _seenEventIds.add(evt.eventId);
            }
          }
          _isFirstEventSnapshot = false;
          _saveSeenEventIds(activeGid, prefs);
        } else {
          final historyCutoff = _listenerStartTime.subtract(const Duration(minutes: 5));
          for (final evt in events) {
            if (evt.eventId.isNotEmpty && evt.createdAt.isBefore(historyCutoff)) {
              _seenEventIds.add(evt.eventId);
            }
          }
        }
        while (_seenEventIds.length > 500) {
          _seenEventIds.remove(_seenEventIds.first);
        }

        // 3. Cari event baru yang belum pernah diproses
        final newEvents = events
            .where((e) => e.eventId.isNotEmpty && !_seenEventIds.contains(e.eventId))
            .toList();

        if (newEvents.isEmpty) return;

        final authService = ref.read(groupAuthServiceProvider);
        final settings = ref.read(groupNotificationSettingsProvider(activeGid));
        final members = ref.read(activeGroupMembersStreamProvider).valueOrNull ?? [];
        final group = ref.read(activeGroupStreamProvider).valueOrNull;
        final groupName = group?.name ?? 'Grup Bersama';
        final memberCount = members.isNotEmpty ? members.length : 1;

        for (final evt in newEvents) {
          _seenEventIds.add(evt.eventId);

          // Cek khusus: jika ini event dikeluarkan untuk diri saya sendiri
          if (evt.type == GroupEventType.memberLeave &&
              (evt.payload['kicked'] == true || (evt.summary != null && evt.summary!.contains('dikeluarkan'))) &&
              authService.isCurrentUser(evt.payload['kickedUid']?.toString() ?? evt.actorUid)) {
            if (NotificationCoordinator.instance.currentLifecycleState !=
                AppLifecycleState.resumed) {
              await ref.read(notificationCoordinatorProvider).dispatch(
                    NotificationIntent.kickedFromGroup(
                      gid: activeGid,
                      groupName: groupName,
                    ),
                  );
            }
            // Pemilik grup tidak bisa dikeluarkan
            if (group == null || !authService.isCurrentUser(group.ownerUid)) {
              _evictUserFromGroup(groupName: groupName);
            }
            continue;
          }

          final isMe = authService.isCurrentUser(evt.actorUid);

          // Periksa apakah grup sedang dibisukan
          if (settings.isCurrentlyMuted) continue;

          // Periksa filter jenis notifikasi berdasarkan sakelar di Layar 44 (untuk aksi anggota lain)
          if (!isMe) {
            if ((evt.type == GroupEventType.expense ||
                    evt.type == GroupEventType.expenseDeleted) &&
                !settings.notifyExpenses) {
              continue;
            }
            if (evt.type == GroupEventType.spin && !settings.notifySpin) continue;
            if (evt.type == GroupEventType.gameResult && !settings.notifySpin) continue;
            if (evt.type == GroupEventType.memberJoin && !settings.notifyMembers) continue;
            if (evt.type == GroupEventType.memberLeave && !settings.notifyMembers) continue;
          }

          // Bangun teks banner dan sistem persis sesuai katalog Notif1 & Notif2
          final String bannerTitle;
          final String bannerSubtitle;
          final String systemMessage;
          final InAppBannerCategory category;
          final Sfx bannerSound;
          bool isExpense = false;

          switch (evt.type) {
            case GroupEventType.expense:
            case GroupEventType.expenseDeleted:
              final isDeleted = evt.type == GroupEventType.expenseDeleted ||
                  evt.payload['deleted'] == true;
              final amount = (evt.payload['amount'] as num?)?.toInt() ?? 0;
              // Guard: Catatan pengeluaran tidak boleh Rp0 kecuali jika catatan dihapus
              if (amount <= 0 && !isDeleted) {
                continue;
              }
              isExpense = true;
              final title = evt.payload['title'] ?? 'pengeluaran';
              final remaining = (evt.payload['remaining'] as num?)?.toInt() ?? 0;
              final formattedAmount = RupiahFormatter.format(amount);
              final formattedRemaining = RupiahFormatter.format(remaining);

              if (isDeleted) {
                category = InAppBannerCategory.expenseDeleted;
                bannerTitle = isMe
                    ? 'Kamu menghapus sebuah catatan'
                    : '${evt.actorName} menghapus sebuah catatan';
                bannerSubtitle = '$title $formattedAmount · Sisa grup $formattedRemaining';
                systemMessage = '${evt.actorName} menghapus pengeluaran $title $formattedAmount.';
                bannerSound = Sfx.uiTap;
              } else {
                category = InAppBannerCategory.expense;
                bannerTitle = isMe
                    ? 'Kamu mencatat $title'
                    : '${evt.actorName} mencatat $title';
                bannerSubtitle = '$formattedAmount · Sisa grup $formattedRemaining';
                systemMessage =
                    '${evt.actorName} mencatat pengeluaran $formattedAmount untuk $title. Sisa budget grup sekarang $formattedRemaining.';
                bannerSound = Sfx.coinRecord;
              }
              break;

            case GroupEventType.spin:
              final sessId = evt.payload['sessionId']?.toString() ?? '';
              if (sessId.isNotEmpty) {
                ref.read(groupServiceProvider).markSpinAsShown(sessId);
              }

              category = InAppBannerCategory.spin;
              final budget = (evt.payload['budget'] as num?)?.toInt() ?? 0;
              final formattedBudget = RupiahFormatter.format(budget);

              if (evt.summary != null && evt.summary!.contains('memutar roda')) {
                bannerTitle = isMe
                    ? evt.summary!.replaceFirst(evt.actorName, 'Kamu')
                    : evt.summary!;
              } else {
                bannerTitle = isMe
                    ? 'Kamu memutar roda: $formattedBudget'
                    : '${evt.actorName} memutar roda: $formattedBudget';
              }
              bannerSubtitle = 'Budget baru untuk sesi ini';
              systemMessage =
                  '${evt.actorName} memutar roda dan mendapat ${budget > 0 ? formattedBudget : (evt.summary ?? "budget baru")} untuk sesi ini.';
              bannerSound = Sfx.wheelLand;
              break;

            case GroupEventType.memberJoin:
              category = InAppBannerCategory.memberJoin;
              bannerTitle = isMe ? 'Kamu bergabung ke $groupName' : '${evt.actorName} bergabung ke grup';
              final newMemberCount = members.length + (members.any((m) => m.uid == evt.actorUid) ? 0 : 1);
              bannerSubtitle = 'Sekarang ada $newMemberCount anggota di $groupName';
              systemMessage = '${evt.actorName} bergabung ke grup $groupName.';
              bannerSound = Sfx.winLolos;
              break;

            case GroupEventType.memberLeave:
              category = InAppBannerCategory.memberLeave;
              final isKicked = evt.payload['kicked'] == true ||
                  (evt.summary != null && evt.summary!.contains('dikeluarkan'));
              final targetName = (evt.payload['kickedName'] ??
                      evt.payload['leaverName'] ??
                      (isKicked ? 'anggota' : evt.actorName))
                  .toString();
              final kickedUid = evt.payload['kickedUid']?.toString();

              if (isKicked && kickedUid != null && authService.isCurrentUser(kickedUid)) {
                _evictUserFromGroup(groupName: groupName);
                return;
              }

              final remainingCount = (memberCount > 1 ? memberCount - 1 : 1);

              if (isKicked) {
                bannerTitle = isMe
                    ? 'Kamu mengeluarkan $targetName'
                    : '${evt.actorName} mengeluarkan $targetName';
                systemMessage = '$targetName telah dikeluarkan dari grup $groupName.';
              } else {
                bannerTitle = isMe
                    ? 'Kamu keluar dari grup'
                    : '$targetName keluar dari grup';
                systemMessage = '$targetName keluar dari grup $groupName.';
              }
              bannerSubtitle = 'Sisa $remainingCount anggota di $groupName';
              bannerSound = Sfx.uiTap;
              break;

            case GroupEventType.sessionStart:
              category = InAppBannerCategory.sessionEnd;
              final sessionBudget = (evt.payload['budget'] as num?)?.toInt() ?? 0;
              final formattedSessBudget = sessionBudget > 0 ? RupiahFormatter.format(sessionBudget) : '';
              bannerTitle = isMe
                  ? (sessionBudget > 0 ? 'Kamu memulai date: $formattedSessBudget' : 'Kamu memulai sesi jajan')
                  : (sessionBudget > 0 ? '${evt.actorName} memulai date: $formattedSessBudget' : '${evt.actorName} memulai sesi jajan');
              bannerSubtitle = sessionBudget > 0 ? 'Budget grup telah ditentukan' : 'Ayo buka roda dan mulai!';
              systemMessage = '${evt.actorName} telah memulai sesi jajan ${formattedSessBudget.isNotEmpty ? "dengan budget $formattedSessBudget" : ""} di grup $groupName.';
              bannerSound = Sfx.winLolos;
              break;

            case GroupEventType.budgetChanged:
              category = InAppBannerCategory.sessionEnd;
              bannerTitle = isMe
                  ? 'Pengaturan budget diperbarui'
                  : '${evt.actorName} mengubah budget grup';
              bannerSubtitle = evt.summary ?? 'Pengaturan budget grup telah diperbarui.';
              systemMessage = '${evt.actorName} mengubah pengaturan budget grup $groupName.';
              bannerSound = Sfx.uiTap;
              break;

            case GroupEventType.codeChanged:
              category = InAppBannerCategory.codeChanged;
              final newCode = evt.payload['code']?.toString() ?? '';
              bannerTitle = isMe
                  ? 'Kode undangan diperbarui'
                  : '${evt.actorName} memperbarui kode grup';
              bannerSubtitle = newCode.isNotEmpty ? 'Kode undangan baru: $newCode' : 'Kode undangan grup telah diganti.';
              systemMessage = '${evt.actorName} memperbarui kode undangan grup $groupName.';
              bannerSound = Sfx.uiTap;
              break;

            case GroupEventType.sessionEnd:
            case GroupEventType.custom:
              category = InAppBannerCategory.sessionEnd;
              if (evt.type == GroupEventType.sessionEnd ||
                  evt.payload['action'] == 'end_session') {
                _maybeOpenGroupResultScreen(
                  gid: activeGid,
                  groupName: groupName,
                  evt: evt,
                  isMe: isMe,
                );
                bannerTitle = isMe
                    ? 'Kamu menyelesaikan date grup'
                    : '${evt.actorName} menyelesaikan date grup';
                bannerSubtitle =
                    'Sesi date selesai · Permainan grup kini terbuka';
                systemMessage =
                    '${evt.actorName} telah menyelesaikan sesi date di grup $groupName.';
              } else if (evt.payload['action'] == 'session_result_updated') {
                bannerTitle = 'Hasil date diperbarui';
                bannerSubtitle = evt.summary ??
                    'Catatan offline masuk, hasil date dihitung ulang.';
                systemMessage =
                    'Hasil date grup $groupName diperbarui setelah catatan offline tersinkron.';
              } else {
                bannerTitle = isMe
                    ? 'Nominal roda diperbarui'
                    : '${evt.actorName} memperbarui nominal roda';
                bannerSubtitle = evt.summary ?? 'Pilihan nominal roda telah diperbarui.';
                systemMessage = '${evt.actorName} memperbarui pilihan nominal roda di grup $groupName.';
              }
              bannerSound = Sfx.uiTap;
              break;

            case GroupEventType.gameResult:
              if (evt.payload['valid'] == false) {
                continue;
              }
              category = InAppBannerCategory.spin;
              final game = evt.payload['game']?.toString() ?? 'game';
              final gameName = GroupEventModel.formatGameName(game);
              final amount = (evt.payload['amount'] as num?)?.toInt() ?? 0;
              final formattedAmount = RupiahFormatter.format(amount);
              bannerTitle = isMe
                  ? 'Kamu memainkan $gameName: $formattedAmount'
                  : '${evt.actorName} memainkan $gameName: $formattedAmount';
              bannerSubtitle = 'Budget baru untuk date ini';
              systemMessage = '${evt.actorName} memainkan $gameName dan mendapat budget $formattedAmount.';
              bannerSound = Sfx.winLolos;
              break;
          }

          // SATU PINTU: Kirim NotificationIntent ke NotificationCoordinator
          // - Pelaku aksi (isMe == true): hanya tampil info ringan di dalam aplikasi (saat resumed),
          //   tidak pernah dikirim ke status bar HP maupun menaikkan angka badge.
          // - Anggota lain (isMe == false): jika sedang di dalam aplikasi (resumed) -> banner saja (+ badge);
          //   jika di luar aplikasi (paused/ditutup) -> notifikasi sistem di luar aplikasi beserta suara (+ badge).
          if (isMe) {
            if (NotificationCoordinator.instance.currentLifecycleState == AppLifecycleState.resumed) {
              final selfIntent = NotificationIntent.groupEvent(
                gid: activeGid,
                groupName: groupName,
                eventId: evt.eventId,
                eventType: evt.type.value,
                actorUid: evt.actorUid,
                actorName: evt.actorName,
                title: bannerTitle,
                subtitle: bannerSubtitle,
                systemBody: systemMessage,
                amount: (evt.payload['amount'] as num?)?.toInt(),
                createdAt: evt.createdAt,
                payload: '/group/activity',
                extra: {
                  'sound': bannerSound,
                  'isExpense': isExpense,
                  'bannerCategory': category,
                },
              );
              await NotificationCoordinator.instance.onRenderBanner?.call(selfIntent);
            }
          } else {
            final intent = NotificationIntent.groupEvent(
              gid: activeGid,
              groupName: groupName,
              eventId: evt.eventId,
              eventType: evt.type.value,
              actorUid: evt.actorUid,
              actorName: evt.actorName,
              title: bannerTitle,
              subtitle: bannerSubtitle,
              systemBody: systemMessage,
              amount: (evt.payload['amount'] as num?)?.toInt(),
              createdAt: evt.createdAt,
              payload: '/group/activity',
              extra: {
                'sound': bannerSound,
                'isExpense': isExpense,
                'bannerCategory': category,
              },
            );

            await ref.read(notificationCoordinatorProvider).dispatch(intent);
          }
        }

        _saveSeenEventIds(activeGid, prefs);
      },
    );

    // Dengarkan siaran putaran live realtime (F2: LiveSpinOverlay)
    ref.listen<AsyncValue<LivePlayModel?>>(
      activeLivePlayStreamProvider,
      (previous, next) {
        if (!mounted || activeGid == null || activeGid.isEmpty) return;
        final play = next.valueOrNull;
        if (play == null) return;

        // Abaikan jika sudah di-dismiss
        if (play.spinId == _lastDismissedSpinId) return;

        // Abaikan jika aktor adalah diri sendiri (host sudah melihat animasi di layarnya)
        final auth = ref.read(groupAuthServiceProvider);
        if (auth.isCurrentUser(play.startedByUid)) return;

        // Abaikan siaran yang lebih tua dari durationMs + 10 detik (jangan memutar ulang)
        final clockSync = ref.read(clockSyncServiceProvider);
        if (play.isExpired(clockSync.serverNowMs)) return;

        setState(() {
          _activeLivePlay = play;
        });
      },
    );

    return Stack(
      children: [
        widget.child,
        if (_activeLivePlay != null)
          LiveSpinOverlay(
            play: _activeLivePlay!,
            onDismiss: () {
              if (mounted) {
                setState(() {
                  _lastDismissedSpinId = _activeLivePlay!.spinId;
                  _activeLivePlay = null;
                });
              }
            },
          ),
      ],
    );
  }
}
