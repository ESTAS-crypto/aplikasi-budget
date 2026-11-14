/// Model Catatan Pengeluaran Grup: /groups/{gid}/notes/{noteId}
/// Sifat append-only idempotent (dua HP yang mencatat tidak saling menimpa).
class GroupNoteModel {
  final String noteId; // UUID client-side
  final String sessionId;
  final String authorUid;
  final String authorName;
  final String title;
  final int amount;
  final DateTime createdAt;
  final bool deleted; // Tombstone soft-delete
  final bool hasPendingWrites; // True jika masih dalam antrean offline

  const GroupNoteModel({
    required this.noteId,
    required this.sessionId,
    required this.authorUid,
    required this.authorName,
    required this.title,
    required this.amount,
    required this.createdAt,
    this.deleted = false,
    this.hasPendingWrites = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'sessionId': sessionId,
      'authorUid': authorUid,
      'authorName': authorName,
      'title': title,
      'amount': amount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'deleted': deleted,
      if (hasPendingWrites) 'hasPendingWrites': true,
    };
  }

  factory GroupNoteModel.fromMap(
    String noteId,
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    DateTime parseDate(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      return DateTime.now();
    }

    final parsedId = noteId.isNotEmpty ? noteId : ((map['id'] as String?) ?? '');
    final pendingFromMap = map['hasPendingWrites'] as bool? ?? false;
    return GroupNoteModel(
      noteId: parsedId,
      sessionId: (map['sessionId'] ?? map['session_id']) as String? ?? '',
      authorUid: (map['authorUid'] ?? map['author_uid']) as String? ?? '',
      authorName: ((map['authorName'] ?? map['author_name']) as String?)?.trim() ?? 'Anggota',
      title: (map['title'] as String?)?.trim() ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      deleted: map['deleted'] as bool? ?? false,
      hasPendingWrites: hasPendingWrites || pendingFromMap,
    );
  }

  GroupNoteModel copyWith({
    String? sessionId,
    String? title,
    int? amount,
    bool? deleted,
    bool? hasPendingWrites,
  }) {
    return GroupNoteModel(
      noteId: noteId,
      sessionId: sessionId ?? this.sessionId,
      authorUid: authorUid,
      authorName: authorName,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      createdAt: createdAt,
      deleted: deleted ?? this.deleted,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }
}

