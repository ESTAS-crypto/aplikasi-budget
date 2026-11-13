import '../../utils/rupiah_formatter.dart';
import 'group_event_model.dart';
import 'group_member_model.dart';
import 'group_note_model.dart';
import 'group_model.dart';

/// Filter daftar riwayat date grup pada Layar 62 (Rgrup1)
enum GroupHistoryFilter {
  semua,
  lolos,
  lewat,
}

/// Model satu catatan pengeluaran beserta sisa budget setelah catatan ke-n (Layar 64 & 66)
class GroupNoteWithRemaining {
  final GroupNoteModel note;
  final int sequenceNumber; // 1..N (berdasarkan urutan waktu server)
  final int totalNotes; // N
  final int cumulativeSpent; // jumlah catatan 1..n
  final int remainingAfter; // budget - jumlah catatan 1..n

  const GroupNoteWithRemaining({
    required this.note,
    required this.sequenceNumber,
    required this.totalNotes,
    required this.cumulativeSpent,
    required this.remainingAfter,
  });

  /// Proporsi sisa budget terhadap total budget sesi (0.0 .. 1.0) untuk bar Layar 66
  double remainingFraction(int budget) {
    if (budget <= 0) return 0.0;
    return (remainingAfter / budget).clamp(0.0, 1.0);
  }
}

/// Ringkasan pengeluaran per anggota grup pada satu sesi date (Layar 63 - Rgrup2)
class MemberSpendingSummary {
  final String uid;
  final String name;
  final int colorIndex;
  final int amountSpent;
  final int noteCount;

  /// Persentase dihitung dari totalSpent (BUKAN dari budget), rentang 0.0 .. 1.0
  final double percentageOfTotalSpent;

  const MemberSpendingSummary({
    required this.uid,
    required this.name,
    required this.colorIndex,
    required this.amountSpent,
    required this.noteCount,
    required this.percentageOfTotalSpent,
  });

  bool get hasRecorded => noteCount > 0 && amountSpent > 0;

  int get percentagePercent => (percentageOfTotalSpent * 100).round();
}

/// Ringkasan statistik keseluruhan riwayat date grup pada Kartu Matahari Layar 62 (Rgrup1)
class GroupHistoryOverviewSummary {
  final int totalDates;
  final int lolosCount;
  final int lewatCount;
  final int averageBudget;

  const GroupHistoryOverviewSummary({
    required this.totalDates,
    required this.lolosCount,
    required this.lewatCount,
    required this.averageBudget,
  });
}

/// Hasil migrasi aman sessionId pada sesi, catatan, dan event lama
class MigratedGroupHistoryData {
  final List<GroupSessionModel> sessions;
  final List<GroupNoteModel> notes;
  final List<GroupEventModel> events;
  final bool hasChanges;

  const MigratedGroupHistoryData({
    required this.sessions,
    required this.notes,
    required this.events,
    required this.hasChanges,
  });
}

/// Kalkulator deterministik & migrasi aman untuk Riwayat Grup (UPDATE 3B - H1)
class GroupHistoryCalculator {
  const GroupHistoryCalculator._();

  /// Deduplikasi catatan (tombstone menang bila ada duplikat ID) dan urutkan
  /// catatan yang tidak deleted menurut createdAt server (lalu noteId) secara ascending.
  static List<GroupNoteModel> sortActiveNotesChronologically(
    List<GroupNoteModel> notes,
  ) {
    final byId = <String, GroupNoteModel>{};
    for (final n in notes) {
      if (n.noteId.isEmpty) continue;
      final existing = byId[n.noteId];
      if (existing == null) {
        byId[n.noteId] = n;
      } else {
        // Tombstone (deleted: true) selalu menang atas salinan lama
        if (existing.deleted || n.deleted) {
          byId[n.noteId] = n.copyWith(deleted: true);
        } else if (n.createdAt.isAfter(existing.createdAt)) {
          byId[n.noteId] = n;
        } else {
          byId[n.noteId] = n;
        }
      }
    }

    final active = byId.values.where((n) => !n.deleted && n.amount > 0).toList();
    active.sort((a, b) {
      final cmpTime = a.createdAt.compareTo(b.createdAt);
      if (cmpTime != 0) return cmpTime;
      return a.noteId.compareTo(b.noteId);
    });
    return active;
  }

  /// Menghitung sisa budget setelah tiap catatan ke-n:
  /// Sisa setelah catatan ke-n = budget - jumlah catatan 1..n
  static List<GroupNoteWithRemaining> computeNotesWithRemaining({
    required int budget,
    required List<GroupNoteModel> notes,
  }) {
    final sorted = sortActiveNotesChronologically(notes);
    final totalCount = sorted.length;
    final result = <GroupNoteWithRemaining>[];
    int cumulative = 0;

    for (var i = 0; i < totalCount; i++) {
      final note = sorted[i];
      cumulative += note.amount;
      final remaining = budget - cumulative;
      result.add(
        GroupNoteWithRemaining(
          note: note,
          sequenceNumber: i + 1,
          totalNotes: totalCount,
          cumulativeSpent: cumulative,
          remainingAfter: remaining,
        ),
      );
    }

    return result;
  }

  /// Menghitung total pengeluaran dari daftar catatan (mengabaikan deleted & duplikat)
  static int computeTotalSpent(List<GroupNoteModel> notes) {
    final sorted = sortActiveNotesChronologically(notes);
    return sorted.fold<int>(0, (sum, n) => sum + n.amount);
  }

  /// Menghitung pengeluaran per orang:
  /// - Anggota tanpa catatan tetap tampil ("Rp0 · Belum mencatat")
  /// - Persentase dihitung dari totalSpent (BUKAN dari budget)
  static List<MemberSpendingSummary> computeMemberSpending({
    required List<GroupMemberModel> members,
    required List<GroupNoteModel> notes,
  }) {
    final activeNotes = sortActiveNotesChronologically(notes);
    final totalSpent = activeNotes.fold<int>(0, (sum, n) => sum + n.amount);

    final spentByUid = <String, int>{};
    final countByUid = <String, int>{};
    final authorNameByUid = <String, String>{};

    for (final note in activeNotes) {
      final uid = note.authorUid;
      spentByUid[uid] = (spentByUid[uid] ?? 0) + note.amount;
      countByUid[uid] = (countByUid[uid] ?? 0) + 1;
      if (note.authorName.trim().isNotEmpty) {
        authorNameByUid[uid] = note.authorName.trim();
      }
    }

    final summaries = <MemberSpendingSummary>[];
    final seenUids = <String>{};

    // 1. Masukkan semua anggota grup saat ini
    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      if (m.uid.isEmpty || seenUids.contains(m.uid)) continue;
      seenUids.add(m.uid);
      final spent = spentByUid[m.uid] ?? 0;
      final count = countByUid[m.uid] ?? 0;
      final pct = totalSpent > 0 ? (spent / totalSpent).clamp(0.0, 1.0) : 0.0;
      summaries.add(
        MemberSpendingSummary(
          uid: m.uid,
          name: m.name,
          colorIndex: m.colorIndex,
          amountSpent: spent,
          noteCount: count,
          percentageOfTotalSpent: pct,
        ),
      );
    }

    // 2. Masukkan pembuat catatan yang mungkin sudah keluar dari grup
    var extraColorIdx = members.length;
    for (final entry in spentByUid.entries) {
      final uid = entry.key;
      if (seenUids.contains(uid)) continue;
      seenUids.add(uid);
      final spent = entry.value;
      final count = countByUid[uid] ?? 0;
      final pct = totalSpent > 0 ? (spent / totalSpent).clamp(0.0, 1.0) : 0.0;
      summaries.add(
        MemberSpendingSummary(
          uid: uid,
          name: authorNameByUid[uid] ?? 'Anggota',
          colorIndex: extraColorIdx++,
          amountSpent: spent,
          noteCount: count,
          percentageOfTotalSpent: pct,
        ),
      );
    }

    // Urutkan anggota yang punya pengeluaran dari terbesar ke terkecil,
    // lalu anggota yang belum mencatat (Rp0) di bawah.
    summaries.sort((a, b) {
      if (a.hasRecorded != b.hasRecorded) {
        return a.hasRecorded ? -1 : 1;
      }
      final cmpSpent = b.amountSpent.compareTo(a.amountSpent);
      if (cmpSpent != 0) return cmpSpent;
      return 0;
    });

    return summaries;
  }

  /// Menghitung ulang totalSpent dan status ('lolos' | 'lewat' | 'running') untuk sesi
  static GroupSessionModel recalculateSession({
    required GroupSessionModel session,
    required List<GroupNoteModel> sessionNotes,
    bool forceEnded = false,
  }) {
    final relevantNotes = sessionNotes
        .where((n) => n.sessionId.isEmpty || n.sessionId == session.sessionId)
        .toList();
    final totalSpent = computeTotalSpent(relevantNotes);
    final isEnded = forceEnded || session.isEnded;
    final status = isEnded
        ? (totalSpent <= session.budget ? 'lolos' : 'lewat')
        : 'running';

    return session.copyWith(
      totalSpent: totalSpent,
      status: status,
    );
  }

  /// Menghitung ringkasan Kartu Matahari pada Layar 62 (Rgrup1)
  static GroupHistoryOverviewSummary computeOverviewSummary(
    List<GroupSessionModel> sessions,
  ) {
    if (sessions.isEmpty) {
      return const GroupHistoryOverviewSummary(
        totalDates: 0,
        lolosCount: 0,
        lewatCount: 0,
        averageBudget: 0,
      );
    }

    int lolos = 0;
    int lewat = 0;
    int sumBudget = 0;

    for (final s in sessions) {
      if (s.totalSpent <= s.budget) {
        lolos++;
      } else {
        lewat++;
      }
      sumBudget += s.budget;
    }

    final avg = (sumBudget / sessions.length).round();
    return GroupHistoryOverviewSummary(
      totalDates: sessions.length,
      lolosCount: lolos,
      lewatCount: lewat,
      averageBudget: avg,
    );
  }

  /// Format lencana "Lewat Rp12rb" seperti acuan visual Rgrup1.dc.html
  static String formatLewatBadge(int overAmount) {
    final absDiff = overAmount.abs();
    if (absDiff >= 1000 && absDiff < 1000000) {
      if (absDiff % 1000 == 0) {
        return 'Lewat Rp${absDiff ~/ 1000}rb';
      }
      final rb = (absDiff / 1000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
      return 'Lewat Rp${rb}rb';
    }
    if (absDiff >= 1000000) {
      if (absDiff % 1000000 == 0) {
        return 'Lewat Rp${absDiff ~/ 1000000}jt';
      }
      final jt = (absDiff / 1000000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
      return 'Lewat Rp${jt}jt';
    }
    return 'Lewat ${RupiahFormatter.format(absDiff)}';
  }

  /// Format rincian hasil permainan untuk Layar 63 ("5 + 3 = 8 × Rp10.000 = Rp80.000")
  static String formatGameResultDetail(GroupSessionModel session) {
    final rawDetail = session.detail;
    final formattedBudget = RupiahFormatter.format(session.budget);
    if (rawDetail is String && rawDetail.trim().isNotEmpty) {
      return rawDetail.trim();
    }
    if (rawDetail is Map) {
      final map = Map<String, dynamic>.from(rawDetail);
      if (map['summary'] is String && (map['summary'] as String).trim().isNotEmpty) {
        return (map['summary'] as String).trim();
      }
      if (session.game == 'dice' || map['rolls'] is List) {
        final rolls = (map['rolls'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
        final mult = (map['multiplier'] as num?)?.toInt() ?? 10000;
        if (rolls.isNotEmpty) {
          final sum = rolls.fold<int>(0, (a, b) => a + b);
          final rollsText = rolls.join(' + ');
          return '$rollsText = $sum × ${RupiahFormatter.format(mult)} = $formattedBudget';
        }
      }
      if (session.game == 'wheel') {
        final idx = (map['winningIndex'] ?? map['sliceIndex'] ?? map['index'] as num?)?.toInt();
        if (idx != null) {
          return 'Irisan #${idx + 1} · $formattedBudget';
        }
      }
      if (session.game == 'capsule') {
        final label = map['capsuleLabel'] ?? map['tier'];
        if (label != null) {
          return 'Kapsul $label · $formattedBudget';
        }
      }
      if (session.game == 'envelope') {
        final idx = (map['envelopeIndex'] ?? map['index'] as num?)?.toInt();
        if (idx != null) {
          return 'Amplop #${idx + 1} · $formattedBudget';
        }
      }
      if (session.game == 'coin') {
        final heads = (map['heads'] ?? map['headsCount'] as num?)?.toInt();
        if (heads != null) {
          return '$heads sisi gambar · $formattedBudget';
        }
      }
    }

    switch (session.game.toLowerCase().trim()) {
      case 'fixed':
        return 'Budget tetap $formattedBudget';
      case 'dice':
        return 'Kocok dadu · $formattedBudget';
      case 'capsule':
        return 'Kapsul kejutan · $formattedBudget';
      case 'envelope':
        return 'Amplop misteri · $formattedBudget';
      case 'coin':
        return 'Lempar koin · $formattedBudget';
      case 'wheel':
      default:
        return 'Putaran roda · $formattedBudget';
    }
  }

  /// Format subjudul permainan untuk Linimasa Layar 65 ("8 × Rp10.000 = budget Rp80.000")
  static String formatTimelineGameSubtitle({
    required String game,
    required int amount,
    dynamic detail,
  }) {
    final formattedAmount = RupiahFormatter.format(amount);
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is Map) {
      final map = Map<String, dynamic>.from(detail);
      if (game == 'dice' || map['rolls'] is List) {
        final rolls = (map['rolls'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
        final mult = (map['multiplier'] as num?)?.toInt() ?? 10000;
        if (rolls.isNotEmpty) {
          final sum = rolls.fold<int>(0, (a, b) => a + b);
          return '$sum × ${RupiahFormatter.format(mult)} = budget $formattedAmount';
        }
      }
    }
    return 'budget $formattedAmount';
  }

  /// Migrasi aman:
  /// 1. Merekonstruksi sesi dari event lama bila belum ada di daftar sessions.
  /// 2. Mengisi sessionId pada catatan dan event lama yang belum memiliki sessionId
  ///    berdasarkan rentang waktu [startedAt, endedAt] sesi.
  /// 3. Menghitung ulang totalSpent dan status tiap sesi secara deterministik.
  static MigratedGroupHistoryData migrateMissingSessionIds({
    required String gid,
    required List<GroupSessionModel> sessions,
    required List<GroupNoteModel> notes,
    required List<GroupEventModel> events,
    GroupSessionModel? activeSession,
  }) {
    bool hasChanges = false;
    final sessionMap = <String, GroupSessionModel>{
      for (final s in sessions)
        if (s.sessionId.isNotEmpty) s.sessionId: s,
    };

    if (activeSession != null &&
        activeSession.sessionId.isNotEmpty &&
        !sessionMap.containsKey(activeSession.sessionId)) {
      sessionMap[activeSession.sessionId] = activeSession.copyWith(gid: gid);
      hasChanges = true;
    }

    // Urutkan event dari terlama ke terbaru untuk merekonstruksi sesi historis
    final chronologicalEvents = List<GroupEventModel>.from(events)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    String? currentOpenSessionId;
    for (final evt in chronologicalEvents) {
      final isGameOrSpin = (evt.type == GroupEventType.gameResult &&
              evt.payload['valid'] != false) ||
          evt.type == GroupEventType.spin ||
          evt.type == GroupEventType.sessionStart;

      if (isGameOrSpin) {
        final sid = evt.sessionId.isNotEmpty
            ? evt.sessionId
            : 'sess_${evt.createdAt.millisecondsSinceEpoch}';
        final budget =
            ((evt.payload['amount'] ?? evt.payload['budget']) as num?)?.toInt() ??
                0;
        final game = evt.payload['game']?.toString() ??
            (evt.type == GroupEventType.sessionStart ? 'fixed' : 'wheel');
        final detail = evt.payload['detail'];

        if (budget > 0) {
          final existing = sessionMap[sid];
          if (existing == null) {
            sessionMap[sid] = GroupSessionModel(
              sessionId: sid,
              gid: gid,
              budget: budget,
              game: game,
              startedByUid: evt.actorUid,
              startedByName: evt.actorName,
              startedAt: evt.createdAt,
              budgetByUid: evt.actorUid,
              budgetByName: evt.actorName,
              detail: detail,
              status: 'running',
            );
            hasChanges = true;
          } else if (existing.budget != budget || existing.detail == null) {
            sessionMap[sid] = existing.copyWith(
              budget: budget,
              game: game,
              budgetByUid: evt.actorUid,
              budgetByName: evt.actorName,
              detail: detail ?? existing.detail,
            );
          }
          currentOpenSessionId = sid;
        }
      } else if (evt.type == GroupEventType.sessionEnd ||
          (evt.type == GroupEventType.custom &&
              evt.payload['action'] == 'end_session')) {
        final targetSid = evt.sessionId.isNotEmpty
            ? evt.sessionId
            : (currentOpenSessionId ?? '');
        if (targetSid.isNotEmpty && sessionMap.containsKey(targetSid)) {
          final existing = sessionMap[targetSid]!;
          if (existing.endedAt == null) {
            sessionMap[targetSid] = existing.copyWith(
              endedAt: evt.createdAt,
              endedByUid: evt.actorUid,
              endedByName: evt.actorName,
              status: existing.totalSpent <= existing.budget ? 'lolos' : 'lewat',
            );
            hasChanges = true;
          }
          if (currentOpenSessionId == targetSid) {
            currentOpenSessionId = null;
          }
        }
      }
    }

    // Urutkan sesi berdasarkan startedAt ascending untuk menentukan batas rentang waktu
    final sortedSessions = sessionMap.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    // Jika sebuah sesi lama diikuti sesi berikutnya tetapi belum punya endedAt,
    // bekukan tepat sebelum sesi berikutnya dimulai
    for (var i = 0; i < sortedSessions.length - 1; i++) {
      final curr = sortedSessions[i];
      final next = sortedSessions[i + 1];
      if (curr.endedAt == null && curr.sessionId != activeSession?.sessionId) {
        final inferredEnd = next.startedAt.subtract(const Duration(seconds: 1));
        sortedSessions[i] = curr.copyWith(
          endedAt: inferredEnd.isAfter(curr.startedAt)
              ? inferredEnd
              : curr.startedAt,
          endedByUid: curr.startedByUid,
          endedByName: curr.startedByName,
          status: curr.totalSpent <= curr.budget ? 'lolos' : 'lewat',
        );
        hasChanges = true;
      }
    }

    String? matchSessionByTimestamp(DateTime timestamp) {
      if (sortedSessions.isEmpty) return null;
      for (var i = sortedSessions.length - 1; i >= 0; i--) {
        final s = sortedSessions[i];
        final startBound = s.startedAt.subtract(const Duration(seconds: 5));
        final endBound = s.endedAt != null
            ? s.endedAt!.add(const Duration(seconds: 5))
            : (i + 1 < sortedSessions.length
                ? sortedSessions[i + 1].startedAt
                : null);

        final afterStart = !timestamp.isBefore(startBound);
        final beforeEnd = endBound == null || !timestamp.isAfter(endBound);
        if (afterStart && beforeEnd) {
          return s.sessionId;
        }
      }
      return null;
    }

    // 2. Migrasi sessionId pada catatan yang belum punya sessionId
    final migratedNotes = <GroupNoteModel>[];
    for (final note in notes) {
      if (note.sessionId.trim().isEmpty) {
        final matchedSid = matchSessionByTimestamp(note.createdAt);
        if (matchedSid != null && matchedSid.isNotEmpty) {
          migratedNotes.add(note.copyWith(sessionId: matchedSid));
          hasChanges = true;
          continue;
        }
      }
      migratedNotes.add(note);
    }

    // 3. Migrasi sessionId pada event timeline yang belum punya sessionId
    final migratedEvents = <GroupEventModel>[];
    for (final evt in events) {
      final needsSessionId = evt.type == GroupEventType.gameResult ||
          evt.type == GroupEventType.spin ||
          evt.type == GroupEventType.expense ||
          evt.type == GroupEventType.expenseDeleted ||
          evt.type == GroupEventType.sessionStart ||
          evt.type == GroupEventType.sessionEnd ||
          (evt.type == GroupEventType.custom &&
              evt.payload['action'] == 'end_session');

      if (needsSessionId && evt.sessionId.isEmpty) {
        final matchedSid = matchSessionByTimestamp(evt.createdAt);
        if (matchedSid != null && matchedSid.isNotEmpty) {
          migratedEvents.add(evt.withSessionId(matchedSid));
          hasChanges = true;
          continue;
        }
      }
      migratedEvents.add(evt);
    }

    // 4. Hitung ulang totalSpent dan status untuk tiap sesi berdasarkan catatan yang sudah dimigrasi
    final finalSessions = <GroupSessionModel>[];
    for (final s in sortedSessions) {
      final sNotes =
          migratedNotes.where((n) => n.sessionId == s.sessionId).toList();
      final recalculated = recalculateSession(
        session: s,
        sessionNotes: sNotes,
      );
      if (recalculated.totalSpent != s.totalSpent ||
          recalculated.status != s.status) {
        hasChanges = true;
      }
      finalSessions.add(recalculated);
    }

    // Urutkan sesi terbaru di atas (startedAt descending)
    finalSessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return MigratedGroupHistoryData(
      sessions: finalSessions,
      notes: migratedNotes,
      events: migratedEvents,
      hasChanges: hasChanges,
    );
  }
}

/// Emulator evaluator untuk Security Rules (`firestore.rules`) pada koleksi
/// `/groups/{gid}/notes/{noteId}` dan `/groups/{gid}/sessions/{sessionId}`.
class GroupSecurityRulesEmulator {
  const GroupSecurityRulesEmulator._();

  static bool isMember({
    required String? authUid,
    required Set<String> memberUids,
  }) {
    return authUid != null && authUid.isNotEmpty && memberUids.contains(authUid);
  }

  static bool isOwner({
    required String? authUid,
    required String ownerUid,
  }) {
    return authUid != null && authUid.isNotEmpty && authUid == ownerUid;
  }

  /// Evaluasi rule `allow create` pada `/groups/{gid}/notes/{noteId}`
  static bool canCreateNote({
    required String? authUid,
    required Set<String> memberUids,
    required GroupNoteModel newNote,
  }) {
    return isMember(authUid: authUid, memberUids: memberUids) &&
        newNote.authorUid == authUid &&
        newNote.amount > 0;
  }

  /// Evaluasi rule `allow update` pada `/groups/{gid}/notes/{noteId}`:
  /// Hanya pembuat catatan (`authorUid`) atau pemilik grup (`ownerUid`) yang boleh mengubah;
  /// `authorUid` tidak boleh diubah dan `amount > 0`.
  static bool canUpdateNote({
    required String? authUid,
    required String ownerUid,
    required Set<String> memberUids,
    required GroupNoteModel existingNote,
    required GroupNoteModel updatedNote,
  }) {
    if (!isMember(authUid: authUid, memberUids: memberUids)) return false;
    final allowedActor = existingNote.authorUid == authUid ||
        isOwner(authUid: authUid, ownerUid: ownerUid);
    if (!allowedActor) return false;
    if (updatedNote.authorUid != existingNote.authorUid) return false;
    if (updatedNote.amount <= 0) return false;
    return true;
  }

  /// Evaluasi rule `allow delete` pada `/groups/{gid}/notes/{noteId}`:
  /// Hanya pembuat catatan (`authorUid`) atau pemilik grup (`ownerUid`) yang boleh menghapus.
  static bool canDeleteNote({
    required String? authUid,
    required String ownerUid,
    required Set<String> memberUids,
    required GroupNoteModel existingNote,
  }) {
    if (!isMember(authUid: authUid, memberUids: memberUids)) return false;
    return existingNote.authorUid == authUid ||
        isOwner(authUid: authUid, ownerUid: ownerUid);
  }

  /// Evaluasi rule `allow update` pada `/groups/{gid}/sessions/{sessionId}`:
  /// Sesi yang sudah berakhir (`endedAt != null`) tidak boleh diubah kecuali oleh pemilik grup.
  static bool canUpdateSession({
    required String? authUid,
    required String ownerUid,
    required Set<String> memberUids,
    required GroupSessionModel existingSession,
  }) {
    if (!isMember(authUid: authUid, memberUids: memberUids)) return false;
    return existingSession.endedAt == null ||
        isOwner(authUid: authUid, ownerUid: ownerUid);
  }

  /// Evaluasi rule `allow delete` pada `/groups/{gid}/sessions/{sessionId}`:
  /// Dokumen sesi tidak pernah boleh dihapus (`allow delete: if false`).
  static bool canDeleteSession() => false;
}


