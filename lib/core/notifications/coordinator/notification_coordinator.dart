import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_intent.dart';
import '../storage/notified_claim_store.dart';
import '../../group/widgets/in_app_banner.dart';
import '../../group/widgets/group_important_dialog.dart';
import '../../utils/sound_service.dart';

/// Catatan hasil keputusan koordinator notifikasi (untuk observabilitas)
@immutable
class NotificationDecision {
  final String dedupeKey;
  final NotificationSource source;
  final NotificationSurface surface;
  final NotificationDropReason reason;
  final DateTime timestamp;
  final String? groupName;
  final String title;

  const NotificationDecision({
    required this.dedupeKey,
    required this.source,
    required this.surface,
    required this.reason,
    required this.timestamp,
    required this.title,
    this.groupName,
  });

  @override
  String toString() {
    return 'notif key=$dedupeKey source=${source.name} surface=${surface.name} reason=${reason.name}';
  }
}

/// Provider Riverpod untuk NotificationCoordinator
final notificationCoordinatorProvider = Provider<NotificationCoordinator>((ref) {
  return NotificationCoordinator.instance;
});

/// Koordinator Tunggal Notifikasi (Singleton & Riverpod)
/// Sesuai Prinsip Utama:
/// "Satu kejadian = satu notifikasi, di satu tempat, satu kali, pada satu perangkat."
class NotificationCoordinator with WidgetsBindingObserver {
  NotificationCoordinator._() {
    _claimStore = SharedPrefsNotifiedClaimStore();
    try {
      final binding = WidgetsBinding.instance;
      binding.addObserver(this);
      _lifecycleState = binding.lifecycleState ?? AppLifecycleState.resumed;
    } catch (_) {
      // Pada unit test binding mungkin belum diinisialisasi
      _lifecycleState = AppLifecycleState.resumed;
    }
  }

  static final NotificationCoordinator instance = NotificationCoordinator._();

  static const Duration _maxAllowedClockSkew = Duration(minutes: 2);

  Future<void> _saveWatermarkIfValid(String? gid, DateTime createdAt) async {
    if (gid == null || gid.isEmpty) return;
    if (!createdAt.isAfter(DateTime.now().add(_maxAllowedClockSkew))) {
      await _claimStore.setLastDeliveredEventAt(gid, createdAt);
    }
  }

  late NotifiedClaimStore _claimStore;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  final DateTime appLaunchTime = DateTime.now();

  // Layar yang sedang aktif (untuk pembersihan & supresi banner aktivitas yang sudah tampil di layar)
  String? _activeScreenGid;
  String? get activeScreenGid => _activeScreenGid;

  // Buffer & Timer Penggabungan (Aggregation)
  // Banner: 3 detik (UPDATE 2C Bagian 2)
  final Map<String, List<NotificationIntent>> _bannerBuffers = {};
  final Map<String, Timer> _bannerTimers = {};

  // Sistem: 60 detik per grup (UPDATE 2C Bagian 2)
  final Map<String, List<NotificationIntent>> _systemBuffers = {};
  final Map<String, Timer> _systemTimers = {};

  // Delegates untuk konfigurasi & render
  String? Function()? currentUidGetter;
  bool Function(String actorUid)? isCurrentUserGetter;
  bool Function(String gid)? isGroupMutedGetter;
  bool Function(NotificationCategory category)? isCategoryEnabledGetter;
  Future<bool> Function()? hasSystemNotificationPermissionGetter;

  // Renderers per permukaan
  Future<void> Function(NotificationIntent intent)? onRenderBanner;
  Future<void> Function(NotificationIntent intent)? onRenderSystem;
  Future<void> Function(NotificationIntent intent)? onRenderDialog;
  Future<void> Function(String gid)? onCancelSystemGroup;

  // Ring buffer observabilitas (50 keputusan terakhir)
  final Queue<NotificationDecision> _recentDecisions = Queue<NotificationDecision>();

  /// Konfigurasi renderer bawaan aplikasi
  void setupDefaultRenderers({
    required BuildContext Function() contextGetter,
    required void Function(String route) navigator,
    required Future<void> Function(NotificationIntent intent) systemRenderer,
    Future<void> Function(String gid)? cancelSystemGroupRenderer,
    Future<void> Function(BuildContext ctx, String groupName)? kickedDialogRenderer,
    Future<void> Function(BuildContext ctx, int unsyncedCount)? syncFailedDialogRenderer,
  }) {
    onCancelSystemGroup = cancelSystemGroupRenderer;
    onRenderBanner = (intent) async {
      try {
        final ctx = contextGetter();
        final bannerCategory = (intent.extra['bannerCategory'] as InAppBannerCategory?) ??
            _mapToBannerCategory(intent.category);
        InAppBanner.show(
          ctx,
          title: intent.title,
          subtitle: intent.subtitle,
          category: bannerCategory,
          sound: intent.extra['sound'] as Sfx?,
          onTap: () {
            if (intent.payload != null) {
              navigator(intent.payload!);
            }
          },
        );
      } catch (e) {
        debugPrint('[NotificationCoordinator] Banner render error: $e');
      }
    };

    onRenderDialog = (intent) async {
      try {
        final ctx = contextGetter();
        if (intent.category == NotificationCategory.kickedFromGroup) {
          if (kickedDialogRenderer != null) {
            await kickedDialogRenderer(ctx, intent.groupName ?? 'Grup');
          } else {
            GroupImportantDialog.showKickedFromGroup(
              ctx,
              groupName: intent.groupName ?? 'Grup',
            );
          }
        } else if (intent.category == NotificationCategory.syncFailed) {
          if (syncFailedDialogRenderer != null) {
            final count = (intent.extra['unsyncedCount'] as num?)?.toInt() ?? 1;
            await syncFailedDialogRenderer(ctx, count);
          }
        }
      } catch (e) {
        debugPrint('[NotificationCoordinator] Dialog render error: $e');
      }
    };

    onRenderSystem = (intent) async {
      await systemRenderer(intent);
    };
  }

  static InAppBannerCategory _mapToBannerCategory(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.expense:
        return InAppBannerCategory.expense;
      case NotificationCategory.expenseDeleted:
        return InAppBannerCategory.expenseDeleted;
      case NotificationCategory.spin:
        return InAppBannerCategory.spin;
      case NotificationCategory.budgetWarning80:
        return InAppBannerCategory.budgetWarning80;
      case NotificationCategory.budgetOver:
        return InAppBannerCategory.budgetOver;
      case NotificationCategory.sessionEnd:
      case NotificationCategory.streakCelebration:
      case NotificationCategory.weeklyReminder:
        return InAppBannerCategory.sessionEnd;
      case NotificationCategory.memberJoin:
        return InAppBannerCategory.memberJoin;
      case NotificationCategory.memberLeave:
        return InAppBannerCategory.memberLeave;
      case NotificationCategory.codeChanged:
        return InAppBannerCategory.codeChanged;
      default:
        return InAppBannerCategory.sessionEnd;
    }
  }

  /// Mengganti claim store (misal InMemoryNotifiedClaimStore untuk unit test)
  void setClaimStore(NotifiedClaimStore store) {
    _claimStore = store;
  }

  /// Override lifecycle state (untuk testing & isolate latar)
  void setLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  AppLifecycleState get currentLifecycleState => _lifecycleState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  /// Mendapatkan daftar 50 keputusan terakhir (Observabilitas)
  List<NotificationDecision> get recentDecisions => _recentDecisions.toList();

  /// Menghapus histori keputusan (untuk test)
  void clearDecisionHistory() {
    _recentDecisions.clear();
  }

  /// Reset buffer dan timer penggabungan (untuk test & isolasi)
  void resetAggregationBuffers() {
    for (final timer in _bannerTimers.values) {
      timer.cancel();
    }
    _bannerTimers.clear();
    _bannerBuffers.clear();

    for (final timer in _systemTimers.values) {
      timer.cancel();
    }
    _systemTimers.clear();
    _systemBuffers.clear();
  }

  /// Dipanggil saat pengguna membuka layar Aktivitas grup (UPDATE 2C Bagian 2 Pembersihan)
  /// - Batalkan notifikasi sistem untuk event yang sudah terlihat
  /// - Jangan tampilkan banner untuk event yang sedang aktif di layar
  Future<void> onActivityScreenOpened(String gid) async {
    _activeScreenGid = gid;
    _systemBuffers.remove(gid);
    _systemTimers[gid]?.cancel();
    _systemTimers.remove(gid);
    _bannerBuffers.remove(gid);
    _bannerTimers[gid]?.cancel();
    _bannerTimers.remove(gid);

    if (onCancelSystemGroup != null) {
      try {
        await onCancelSystemGroup!(gid);
      } catch (e) {
        debugPrint('[NotificationCoordinator] onCancelSystemGroup error: $e');
      }
    }
    InAppBanner.dismiss();
  }

  /// Dipanggil saat layar Aktivitas grup ditutup
  void onScreenClosed(String gid) {
    if (_activeScreenGid == gid) {
      _activeScreenGid = null;
    }
  }

  /// Pemulihan setelah offline (UPDATE 2C Bagian 2):
  /// Kumpulkan event yang menumpuk. Jika lebih dari satu, tampilkan SATU ringkasan
  /// "N aktivitas baru di {grup}" (id tetap per grup) dan bukan N notifikasi.
  Future<List<NotificationDecision>> dispatchBatch(List<NotificationIntent> intents) async {
    if (intents.isEmpty) return [];

    final Map<String?, List<NotificationIntent>> byGid = {};
    for (final it in intents) {
      byGid.putIfAbsent(it.gid, () => []).add(it);
    }

    final results = <NotificationDecision>[];
    for (final entry in byGid.entries) {
      final gid = entry.key;
      final groupIntents = entry.value;

      if (gid == null || groupIntents.length <= 1) {
        for (final it in groupIntents) {
          results.add(await dispatch(it));
        }
      } else {
        // Lebih dari 1 event menumpuk untuk grup yang sama:
        groupIntents.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final latest = groupIntents.last;
        final groupName = latest.groupName ?? 'Grup';
        final count = groupIntents.length;

        // Klaim semua event individual sebagai merged agar tidak terjadi double
        for (final it in groupIntents) {
          await _claimStore.tryClaim(
            dedupeKey: it.dedupeKey,
            surface: NotificationSurface.dropped,
            reason: NotificationDropReason.merged,
          );
        }

        final summaryIntent = NotificationIntent.groupEvent(
          gid: gid,
          groupName: groupName,
          eventId: 'summary_${DateTime.now().millisecondsSinceEpoch}',
          eventType: 'summary',
          actorUid: latest.actorUid ?? '',
          actorName: latest.actorName ?? 'Anggota',
          title: '$count aktivitas baru di $groupName',
          subtitle: '${latest.title}: ${latest.subtitle}',
          systemBody: '$count aktivitas baru di $groupName',
          createdAt: latest.createdAt,
        );

        final decision = await dispatch(summaryIntent);
        results.add(decision);

        for (final it in groupIntents) {
          final mergedDec = _recordDecision(
            intent: it,
            surface: decision.surface,
            reason: NotificationDropReason.merged,
            timestamp: DateTime.now(),
          );
          results.add(mergedDec);
        }
      }
    }
    return results;
  }

  /// SATU-SATUNYA PINTU MASUK: Memproses NotificationIntent melalui pipeline berurutan
  Future<NotificationDecision> dispatch(NotificationIntent intent) async {
    final now = DateTime.now();

    // -------------------------------------------------------------------------
    // Langkah 1: Normalisasi
    // -------------------------------------------------------------------------
    final key = intent.dedupeKey.trim();
    if (key.isEmpty) {
      return _recordDecision(
        intent: intent,
        surface: NotificationSurface.dropped,
        reason: NotificationDropReason.duplicate,
        timestamp: now,
      );
    }

    // -------------------------------------------------------------------------
    // Langkah 2: Filter
    // -------------------------------------------------------------------------
    final myUid = currentUidGetter?.call();

    // 2a. Abaikan aksi diri sendiri (actorUid == uid) di semua kondisi aplikasi:
    // pelaku cukup mendapat info di dalam aplikasi dan tidak perlu notif luar HP maupun badge.
    final isOwnAction = intent.actorUid != null &&
        ((isCurrentUserGetter != null && isCurrentUserGetter!(intent.actorUid!)) ||
            (myUid != null && intent.actorUid == myUid));
    if (isOwnAction) {
      await _claimStore.tryClaim(
        dedupeKey: key,
        surface: NotificationSurface.dropped,
        reason: NotificationDropReason.ownAction,
      );
      return _recordDecision(
        intent: intent,
        surface: NotificationSurface.dropped,
        reason: NotificationDropReason.ownAction,
        timestamp: now,
      );
    }

    // 2b. Abaikan jika grup dibisukan
    if (intent.gid != null && isGroupMutedGetter != null) {
      final isMuted = isGroupMutedGetter!(intent.gid!);
      if (isMuted) {
        await _claimStore.tryClaim(
          dedupeKey: key,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.muted,
        );
        return _recordDecision(
          intent: intent,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.muted,
          timestamp: now,
        );
      }
    }

    // 2c. Abaikan jika sakelar jenis tertentu dimatikan
    if (isCategoryEnabledGetter != null) {
      final isEnabled = isCategoryEnabledGetter!(intent.category);
      if (!isEnabled) {
        await _claimStore.tryClaim(
          dedupeKey: key,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.toggleDisabled,
        );
        return _recordDecision(
          intent: intent,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.toggleDisabled,
          timestamp: now,
        );
      }
    }

    // 2d. Cek duplikasi jika dedupeKey sudah pernah diklaim sebelumnya (Anti-Double)
    if (await _claimStore.isClaimed(key)) {
      return _recordDecision(
        intent: intent,
        surface: NotificationSurface.dropped,
        reason: NotificationDropReason.duplicate,
        timestamp: now,
      );
    }

    // 2e. Watermark & Event lama (UPDATE 2C Bagian 2)
    // Event yang createdAt-nya lebih tua dari watermark, atau lebih dari 5 menit
    // sebelum aplikasi dibuka, tidak memicu banner atau notifikasi sistem
    if (intent.gid != null) {
      final rawWatermark = await _claimStore.getLastDeliveredEventAt(intent.gid!);
      // Self-heal jika watermark tersimpan > 2 menit di masa depan akibat bug timezone lama
      final DateTime? watermark;
      if (rawWatermark != null &&
          rawWatermark.isAfter(now.add(_maxAllowedClockSkew))) {
        await _claimStore.clearLastDeliveredEventAt(intent.gid!);
        watermark = null;
      } else {
        watermark = rawWatermark;
      }
      final isOlderThanWatermark = watermark != null && intent.createdAt.isBefore(watermark);
      final isOlderThan5MinBeforeLaunch = appLaunchTime.difference(intent.createdAt).inMinutes > 5;

      if (isOlderThanWatermark || isOlderThan5MinBeforeLaunch) {
        await _claimStore.tryClaim(
          dedupeKey: key,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.oldEvent,
        );
        return _recordDecision(
          intent: intent,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.oldEvent,
          timestamp: now,
        );
      }
    }

    // 2f. Pembersihan saat layar dibuka (UPDATE 2C Bagian 2)
    // Jangan tampilkan banner jika pengguna sedang aktif membuka layar Aktivitas grup ini
    if (_lifecycleState == AppLifecycleState.resumed &&
        _activeScreenGid != null &&
        _activeScreenGid == intent.gid &&
        !intent.isImportantDialog) {
      await _claimStore.tryClaim(
        dedupeKey: key,
        surface: NotificationSurface.banner,
        reason: NotificationDropReason.none,
      );
      await _saveWatermarkIfValid(intent.gid, intent.createdAt);
      return _recordDecision(
        intent: intent,
        surface: NotificationSurface.banner,
        reason: NotificationDropReason.none,
        timestamp: now,
      );
    }

    // -------------------------------------------------------------------------
    // Langkah 3: Rute berdasarkan AppLifecycleState
    // -------------------------------------------------------------------------
    NotificationSurface targetSurface;
    if (_lifecycleState == AppLifecycleState.resumed) {
      // Aplikasi di depan: dialog jika butuh keputusan/kritis, selain itu banner
      targetSurface = intent.isImportantDialog
          ? NotificationSurface.dialog
          : NotificationSurface.banner;
    } else {
      // Aplikasi di latar atau tertutup: notifikasi sistem
      targetSurface = NotificationSurface.system;
    }

    // 3a. Izin notifikasi sistem Android
    if (targetSurface == NotificationSurface.system &&
        hasSystemNotificationPermissionGetter != null) {
      final hasPerm = await hasSystemNotificationPermissionGetter!();
      if (!hasPerm) {
        await _claimStore.tryClaim(
          dedupeKey: key,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.permissionDenied,
        );
        return _recordDecision(
          intent: intent,
          surface: NotificationSurface.dropped,
          reason: NotificationDropReason.permissionDenied,
          timestamp: now,
        );
      }
    }

    // -------------------------------------------------------------------------
    // Langkah 4: Klaim Atomik (Anti-Double)
    // -------------------------------------------------------------------------
    final claimed = await _claimStore.tryClaim(
      dedupeKey: key,
      surface: targetSurface,
      reason: NotificationDropReason.none,
    );

    if (!claimed) {
      // Sudah pernah diklaim sebelumnya oleh listener lain / FCM / isolate lain!
      return _recordDecision(
        intent: intent,
        surface: NotificationSurface.dropped,
        reason: NotificationDropReason.duplicate,
        timestamp: now,
      );
    }

    // -------------------------------------------------------------------------
    // Langkah 5: Render lewat satu renderer per permukaan dengan Penggabungan
    // -------------------------------------------------------------------------
    try {
      switch (targetSurface) {
        case NotificationSurface.banner:
          if (intent.gid != null) {
            // Penggabungan banner dalam 3 detik per grup (UPDATE 2C Bagian 2)
            final buf = _bannerBuffers.putIfAbsent(intent.gid!, () => []);
            buf.add(intent);

            _bannerTimers[intent.gid!]?.cancel();
            _bannerTimers[intent.gid!] = Timer(const Duration(seconds: 3), () {
              _bannerBuffers.remove(intent.gid!);
              _bannerTimers.remove(intent.gid!);
            });

            if (buf.length == 1) {
              if (onRenderBanner != null) {
                await onRenderBanner!(intent);
              }
            } else {
              // Kejadian beruntun dalam 3 detik: perbarui satu banner ("N aktivitas baru di {grup}")
              final count = buf.length;
              final aggregated = intent.copyWith(
                title: '$count aktivitas baru di ${intent.groupName ?? 'grup'}',
                subtitle: '${intent.title}: ${intent.subtitle}',
              );
              if (onRenderBanner != null) {
                await onRenderBanner!(aggregated);
              }
              await _saveWatermarkIfValid(intent.gid, intent.createdAt);
              return _recordDecision(
                intent: intent,
                surface: NotificationSurface.banner,
                reason: NotificationDropReason.merged,
                timestamp: now,
              );
            }
          } else {
            if (onRenderBanner != null) {
              await onRenderBanner!(intent);
            }
          }
          break;

        case NotificationSurface.system:
          if (intent.category == NotificationCategory.spin) {
            // Event penentuan budget permainan langsung tayang di status bar Android tanpa delay
            if (onRenderSystem != null) {
              await onRenderSystem!(intent);
            }
            break;
          }
          if (intent.gid != null) {
            // Penggabungan notifikasi sistem dalam 60 detik per grup (UPDATE 2C Bagian 2)
            final buf = _systemBuffers.putIfAbsent(intent.gid!, () => []);
            buf.add(intent);

            _systemTimers[intent.gid!]?.cancel();
            _systemTimers[intent.gid!] = Timer(const Duration(seconds: 60), () {
              _systemBuffers.remove(intent.gid!);
              _systemTimers.remove(intent.gid!);
            });

            if (buf.length == 1) {
              if (onRenderSystem != null) {
                await onRenderSystem!(intent);
              }
            } else {
              // Kejadian beruntun dalam 60 detik: perbarui satu notifikasi sistem per grup
              final count = buf.length;
              final aggregated = intent.copyWith(
                systemTitle: '$count aktivitas baru di ${intent.groupName ?? 'grup'}',
                systemBody: '${intent.systemBody}, dan ${count - 1} lainnya.',
              );
              if (onRenderSystem != null) {
                await onRenderSystem!(aggregated);
              }
              await _saveWatermarkIfValid(intent.gid, intent.createdAt);
              return _recordDecision(
                intent: intent,
                surface: NotificationSurface.system,
                reason: NotificationDropReason.merged,
                timestamp: now,
              );
            }
          } else {
            if (onRenderSystem != null) {
              await onRenderSystem!(intent);
            }
          }
          break;

        case NotificationSurface.dialog:
          if (onRenderDialog != null) {
            await onRenderDialog!(intent);
          }
          break;

        case NotificationSurface.dropped:
          break;
      }
    } catch (e) {
      debugPrint('[NotificationCoordinator] Render error on $targetSurface: $e');
    }

    await _saveWatermarkIfValid(intent.gid, intent.createdAt);

    return _recordDecision(
      intent: intent,
      surface: targetSurface,
      reason: NotificationDropReason.none,
      timestamp: now,
    );
  }

  NotificationDecision _recordDecision({
    required NotificationIntent intent,
    required NotificationSurface surface,
    required NotificationDropReason reason,
    required DateTime timestamp,
  }) {
    final decision = NotificationDecision(
      dedupeKey: intent.dedupeKey,
      source: intent.source,
      surface: surface,
      reason: reason,
      timestamp: timestamp,
      title: intent.title,
      groupName: intent.groupName,
    );

    if (_recentDecisions.length >= 50) {
      _recentDecisions.removeFirst();
    }
    _recentDecisions.addLast(decision);

    // Logging observabilitas sesuai format dokumen:
    // notif key=... source=listener|fcm|schedule surface=banner|system|dialog|dropped reason=own|muted|toggle|duplicate|old|merged
    debugPrint(decision.toString());

    return decision;
  }
}

