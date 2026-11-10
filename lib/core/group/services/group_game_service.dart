import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_model.dart';
import '../models/group_event_model.dart';
import 'group_service.dart';
import 'group_auth_service.dart';
import '../../utils/rupiah_formatter.dart';

/// Hasil klaim sesi permainan grup (atomic & resolusi race condition)
class ClaimSessionResult {
  final bool success;
  final bool isRaceConditionLost;
  final GroupSessionModel? activeSession;
  final GroupEventModel? event;
  final String message;

  const ClaimSessionResult({
    required this.success,
    this.isRaceConditionLost = false,
    this.activeSession,
    this.event,
    required this.message,
  });
}

/// Service untuk orkestrasi sesi bermain bersama dalam grup (UPDATE 2D)
class GroupGameService {
  final GroupService groupService;
  final GroupAuthService authService;

  GroupGameService({
    required this.groupService,
    required this.authService,
  });

  /// Cek apakah pengguna saat ini berhak memainkan permainan grup (F1 canPlay)
  bool canUserPlay({
    required GroupModel group,
    required String uid,
    GroupSessionModel? session,
  }) {
    return canPlay(group, session ?? group.activeSession, uid);
  }

  /// Cek apakah jenis permainan tertentu diaktifkan oleh pemilik (enabledGames)
  bool isGameEnabled({required GroupModel group, required String gameKey}) {
    return group.isGameEnabled(gameKey);
  }

  /// Klaim sesi permainan grup & tulis event game_result dalam SATU transaksi/batch
  /// Aturan multi-klien (F1 & Section 2 & 3):
  /// - Hasil ditentukan DULU di perangkat pemain (Random.secure) memakai pool grup.
  /// - Ditulis sebagai event game_result {game, amount, detail}.
  /// - Pemilik SELALU boleh memutar atau mengulang, kapan pun, termasuk saat sesi terkunci.
  /// - Bila lockPolicy == lock dan belum ada budget sesi, dibuat session baru {budget = amount, game, locked: true}.
  /// - Bila 2 anggota bermain bersamaan: sesi yang createdAt server-nya paling awal menang,
  ///   hasil yang lain ditandai 'tidak berlaku' di feed dan pemainnya melihat pesan ramah.
  /// - Bila lockPolicy == free, hasil terbaru menggantikan budget sesi.
  Future<ClaimSessionResult> claimSessionAndWriteResult({
    required String gid,
    required String game,
    required int amount,
    dynamic detail,
    String? customSessionId,
    String? customEventId,
  }) async {
    final uid = await authService.ensureSignedIn();
    final actorName = authService.displayName ?? 'Anggota';
    final now = DateTime.now();

    final currentGroup = groupService.getLocalGroup(gid) ?? await groupService.fetchGroup(gid);
    if (currentGroup == null) {
      return const ClaimSessionResult(
        success: false,
        message: 'Grup tidak ditemukan',
      );
    }

    final isOwner = currentGroup.isOwner(uid) || authService.isCurrentUser(currentGroup.ownerUid);

    final effectiveSessionId = customSessionId ??
        'sess_${now.millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final effectiveEventId = customEventId ??
        'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';

    // 1. Validasi hak bermain (F1 canPlay & PlayDenied)
    final existingSession = currentGroup.activeSession;
    final perm = evaluateCanPlay(
      group: currentGroup,
      session: existingSession,
      uid: uid,
      isCurrentUserOwner: isOwner,
    );
    if (!perm.allowed) {
      if (perm.deniedReason == PlayDenied.sessionLocked && existingSession != null) {
        final invalidEvt = GroupEventModel(
          eventId: effectiveEventId,
          type: GroupEventType.gameResult,
          actorUid: uid,
          actorName: actorName,
          summary: null,
          payload: {
            'game': game,
            'amount': amount,
            'detail': detail,
            'valid': false,
            'sessionId': existingSession.sessionId,
            'reason': 'race_condition_lost',
          },
          createdAt: now,
        );

        await groupService.recordEventOnly(gid, invalidEvt);

        return ClaimSessionResult(
          success: false,
          isRaceConditionLost: true,
          activeSession: existingSession,
          event: invalidEvt,
          message: 'Sesi sudah dimulai oleh ${existingSession.startedByName}. Hasilmu tidak berlaku.',
        );
      }
      return ClaimSessionResult(
        success: false,
        message: perm.message,
      );
    }

    // 2. Validasi status permainan aktif (enabledGames)
    if (!currentGroup.isGameEnabled(game)) {
      return const ClaimSessionResult(
        success: false,
        message: 'Permainan ini dimatikan oleh pemilik',
      );
    }
    final isLocked = currentGroup.lockPolicy == 'lock' &&
        existingSession != null &&
        existingSession.locked &&
        existingSession.sessionId.isNotEmpty;

    // Aturan F1: Pemilik SELALU boleh memutar atau mengulang, kapan pun!
    // Hanya tolak jika BUKAN pemilik dan sesi terkunci.
    if (isLocked && !isOwner) {
      // Ada sesi locked yang sudah lebih dulu aktif dari pemain lain!
      // Hasil pemain yang kalah balapan ditandai "tidak berlaku" di feed
      final invalidEvt = GroupEventModel(
        eventId: effectiveEventId,
        type: GroupEventType.gameResult,
        actorUid: uid,
        actorName: actorName,
        summary: null,
        payload: {
          'game': game,
          'amount': amount,
          'detail': detail,
          'valid': false,
          'sessionId': existingSession.sessionId,
          'reason': 'race_condition_lost',
        },
        createdAt: now,
      );

      // Simpan event yang ditandai tidak berlaku ke feed
      await groupService.recordEventOnly(gid, invalidEvt);

      return ClaimSessionResult(
        success: false,
        isRaceConditionLost: true,
        activeSession: existingSession,
        event: invalidEvt,
        message: 'Sesi sudah dimulai oleh ${existingSession.startedByName}. Hasilmu tidak berlaku.',
      );
    }

    // 4. Sukses: Buat sesi baru & event game_result yang valid
    final isLockActive = currentGroup.lockPolicy == 'lock';
    final newSession = GroupSessionModel(
      sessionId: effectiveSessionId,
      budget: amount,
      game: game,
      startedByUid: uid,
      startedByName: actorName,
      startedAt: now,
      locked: isLockActive,
      turnLockedByUid: null,
      turnLockedByName: null,
      turnLockedAt: null,
    );

    final validEvt = GroupEventModel(
      eventId: effectiveEventId,
      type: GroupEventType.gameResult,
      actorUid: uid,
      actorName: actorName,
      summary: null,
      payload: {
        'game': game,
        'amount': amount,
        'detail': detail,
        'valid': true,
        'sessionId': effectiveSessionId,
      },
      createdAt: now,
    );

    await groupService.saveSessionAndEvent(
      gid: gid,
      session: newSession,
      event: validEvt,
    );

    return ClaimSessionResult(
      success: true,
      activeSession: newSession,
      event: validEvt,
      message: 'Budget grup berhasil ditentukan: ${RupiahFormatter.format(amount)}',
    );
  }

  /// Kunci giliran Lempar Koin (hanya 1 anggota yang bisa melempar pada 1 waktu)
  Future<bool> claimCoinTurn({
    required String gid,
    required String uid,
    required String userName,
  }) async {
    final currentGroup = await groupService.fetchGroup(gid) ?? groupService.getLocalGroup(gid);
    if (currentGroup == null) return false;

    final session = currentGroup.activeSession;
    if (session != null && session.isTurnLocked && !session.isTurnLockedBy(uid)) {
      // Sedang dikunci anggota lain
      return false;
    }

    final now = DateTime.now();
    final updatedSession = (session ??
            GroupSessionModel(
              sessionId: 'sess_${now.millisecondsSinceEpoch}',
              budget: 0,
              game: 'coin',
              startedByUid: uid,
              startedByName: userName,
              startedAt: now,
              locked: false,
            ))
        .copyWith(
      turnLockedByUid: uid,
      turnLockedByName: userName,
      turnLockedAt: now,
    );

    await groupService.saveSessionOnly(gid: gid, session: updatedSession);
    return true;
  }

  /// Lepas kunci giliran Lempar Koin
  Future<void> releaseCoinTurn({
    required String gid,
    required String uid,
  }) async {
    final currentGroup = await groupService.fetchGroup(gid) ?? groupService.getLocalGroup(gid);
    if (currentGroup == null) return;

    final session = currentGroup.activeSession;
    if (session != null && session.isTurnLockedBy(uid)) {
      final updated = session.copyWith(clearTurnLock: true);
      await groupService.saveSessionOnly(gid: gid, session: updated);
    }
  }

  /// Buka kunci sesi grup / selesaikan date (hanya pemilik atau saat date berakhir)
  Future<void> unlockOrFinishSession({
    required String gid,
  }) async {
    final currentGroup = await groupService.fetchGroup(gid) ?? groupService.getLocalGroup(gid);
    if (currentGroup == null) return;

    final session = currentGroup.activeSession;
    if (session != null) {
      final updated = session.copyWith(locked: false, clearTurnLock: true);
      await groupService.saveSessionOnly(gid: gid, session: updated);
    }
  }

  /// Mulai sesi budget tetap (Angka Tetap) - TANPA menulis game_result (Section 5)
  Future<ClaimSessionResult> startFixedBudgetSession({
    required String gid,
    required int fixedBudget,
  }) async {
    final uid = await authService.ensureSignedIn();
    final actorName = authService.displayName ?? 'Anggota';
    final now = DateTime.now();

    final currentGroup = await groupService.fetchGroup(gid) ?? groupService.getLocalGroup(gid);
    if (currentGroup == null) {
      return const ClaimSessionResult(
        success: false,
        message: 'Grup tidak ditemukan',
      );
    }

    final perm = evaluateCanPlay(
      group: currentGroup,
      session: currentGroup.activeSession,
      uid: uid,
    );
    if (!perm.allowed) {
      return ClaimSessionResult(
        success: false,
        message: perm.message,
      );
    }

    final sessionId = 'sess_${now.millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final newSession = GroupSessionModel(
      sessionId: sessionId,
      budget: fixedBudget,
      game: 'fixed',
      startedByUid: uid,
      startedByName: actorName,
      startedAt: now,
      locked: currentGroup.lockPolicy == 'lock',
    );

    final evtId = 'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final startEvt = GroupEventModel(
      eventId: evtId,
      type: GroupEventType.sessionStart,
      actorUid: uid,
      actorName: actorName,
      summary: '$actorName memulai date dengan budget ${RupiahFormatter.format(fixedBudget)}',
      payload: {
        'sessionId': sessionId,
        'budget': fixedBudget,
        'startedByUid': uid,
        'startedByName': actorName,
        'type': 'fixed',
      },
      createdAt: now,
    );

    // Simpan sesi dan event session_start (BUKAN game_result)
    await groupService.saveSessionAndEvent(
      gid: gid,
      session: newSession,
      event: startEvt,
    );

    return ClaimSessionResult(
      success: true,
      activeSession: newSession,
      event: startEvt,
      message: 'Date berhasil dimulai dengan budget ${RupiahFormatter.format(fixedBudget)}',
    );
  }

  /// Mengakhiri sesi date grup aktif (membuka kembali kunci date dan permainan)
  Future<void> endSession({required String gid}) async {
    await groupService.endSession(gid: gid);
  }
}

/// Provider GroupGameService
final groupGameServiceProvider = Provider<GroupGameService>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final authService = ref.watch(groupAuthServiceProvider);

  return GroupGameService(
    groupService: groupService,
    authService: authService,
  );
});

