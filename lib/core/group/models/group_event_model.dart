import 'dart:convert';
import '../../utils/rupiah_formatter.dart';

/// Jenis aktivitas grup di Firestore: /groups/{gid}/events/{eventId}
enum GroupEventType {
  spin('spin'),
  gameResult('game_result'),
  expense('expense'),
  expenseDeleted('expense_deleted'),
  memberJoin('member_join'),
  memberLeave('member_leave'),
  sessionStart('session_start'),
  sessionEnd('session_end'),
  budgetChanged('budget_changed'),
  codeChanged('code_changed'),
  custom('custom');

  final String value;
  const GroupEventType(this.value);

  static GroupEventType fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'spin':
        return GroupEventType.spin;
      case 'game_result':
      case 'gameresult':
        return GroupEventType.gameResult;
      case 'expense':
        return GroupEventType.expense;
      case 'expense_deleted':
      case 'expensedeleted':
        return GroupEventType.expenseDeleted;
      case 'member_join':
      case 'memberjoin':
        return GroupEventType.memberJoin;
      case 'member_leave':
      case 'memberleave':
        return GroupEventType.memberLeave;
      case 'session_start':
      case 'sessionstart':
        return GroupEventType.sessionStart;
      case 'session_end':
      case 'sessionend':
        return GroupEventType.sessionEnd;
      case 'budget_changed':
      case 'budgetchanged':
        return GroupEventType.budgetChanged;
      case 'code_changed':
      case 'codechanged':
        return GroupEventType.codeChanged;
      case 'custom':
        return GroupEventType.custom;
      default:
        return GroupEventType.custom;
    }
  }
}

/// Model log aktivitas immutable grup
class GroupEventModel {
  final String eventId;
  final GroupEventType type;
  final String actorUid;
  final String actorName;
  final String? summary;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const GroupEventModel({
    required this.eventId,
    required this.type,
    required this.actorUid,
    required this.actorName,
    this.summary,
    required this.payload,
    required this.createdAt,
  });

  static String formatGameName(String gameKey) {
    switch (gameKey.toLowerCase().trim()) {
      case 'wheel':
        return 'Roda Putar';
      case 'dice':
        return 'Kocok Dadu';
      case 'capsule':
        return 'Gacha Kapsul';
      case 'envelope':
        return 'Pilih Amplop';
      case 'coin':
        return 'Lempar Koin';
      case 'fixed':
        return 'Budget Tetap';
      default:
        return 'Permainan';
    }
  }

  String get formattedSummary {
    if (summary != null && summary!.trim().isNotEmpty) {
      return summary!;
    }
    switch (type) {
      case GroupEventType.gameResult:
        final game = payload['game'] ?? 'permainan';
        final amount = (payload['amount'] as num?)?.toInt() ?? 0;
        final isValid = payload['valid'] != false;
        final gameName = formatGameName(game.toString());
        final formattedAmount = RupiahFormatter.format(amount);
        if (!isValid) {
          return '$actorName memainkan $gameName: $formattedAmount (tidak berlaku)';
        }
        return '$actorName memainkan $gameName: $formattedAmount';
      case GroupEventType.spin:
        final b = payload['budget'] ?? 0;
        final formatted = RupiahFormatter.format((b as num).toInt());
        return '$actorName memutar roda: $formatted';
      case GroupEventType.expense:
        final t = payload['title'] ?? 'pengeluaran';
        return '$actorName mencatat "$t"';
      case GroupEventType.expenseDeleted:
        final t = payload['title'] ?? 'pengeluaran';
        return '$actorName menghapus catatan "$t"';
      case GroupEventType.memberJoin:
        return '$actorName bergabung ke grup.';
      case GroupEventType.memberLeave:
        return '$actorName keluar dari grup.';
      case GroupEventType.sessionStart:
        return '$actorName memulai sesi date grup.';
      case GroupEventType.sessionEnd:
        final status = payload['status']?.toString().toLowerCase() ?? 'lolos';
        final statusLabel = status == 'lewat' ? 'Lewat' : 'Lolos';
        return '$actorName menyelesaikan date: $statusLabel';
      case GroupEventType.budgetChanged:
        return summary ?? '$actorName mengubah pengaturan budget grup.';
      case GroupEventType.codeChanged:
        return summary ?? '$actorName memperbarui kode undangan grup.';
      case GroupEventType.custom:
        return summary ?? '$actorName memperbarui pengaturan grup.';
    }
  }

  /// Mendapatkan sessionId dari payload event bila ada
  String get sessionId {
    final raw = payload['sessionId'] ??
        payload['session_id'] ??
        payload['endedSessionId'];
    return raw?.toString().trim() ?? '';
  }

  /// Mengembalikan salinan GroupEventModel dengan sessionId yang dilengkapi (migrasi aman)
  GroupEventModel withSessionId(String newSessionId) {
    if (newSessionId.isEmpty) return this;
    final updatedPayload = Map<String, dynamic>.from(payload);
    updatedPayload['sessionId'] = newSessionId;
    return GroupEventModel(
      eventId: eventId,
      type: type,
      actorUid: actorUid,
      actorName: actorName,
      summary: summary,
      payload: updatedPayload,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': eventId,
      'eventId': eventId,
      'type': type.value,
      'actorUid': actorUid,
      'actor_uid': actorUid,
      'actorName': actorName,
      'actor_name': actorName,
      if (summary != null) 'summary': summary,
      'payload': payload,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GroupEventModel.fromMap(String eventId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final parsedId = eventId.isNotEmpty
        ? eventId
        : ((map['id'] ?? map['eventId']) as String? ?? '');

    Map<String, dynamic> parsedPayload = {};
    final rawPayload = map['payload'];
    if (rawPayload is Map) {
      parsedPayload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          parsedPayload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return GroupEventModel(
      eventId: parsedId,
      type: GroupEventType.fromString(map['type'] as String? ?? 'custom'),
      actorUid: (map['actorUid'] ?? map['actor_uid']) as String? ?? '',
      actorName: ((map['actorName'] ?? map['actor_name']) as String?)?.trim() ?? 'Anggota',
      summary: map['summary'] as String?,
      payload: parsedPayload,
      createdAt: parseDate(map['createdAt'] ?? map['created_at'] ?? map['timestamp']),
    );
  }
}
