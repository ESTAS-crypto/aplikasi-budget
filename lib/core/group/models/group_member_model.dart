/// Model Anggota Grup di Firestore: /groups/{gid}/members/{uid}
class GroupMemberModel {
  final String uid;
  final String name;
  final int colorIndex; // 0 sampai 7 dari palet tema Putar Jajan
  final String role; // 'owner' atau 'member'
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final DateTime? lastSeenAt;

  const GroupMemberModel({
    required this.uid,
    required this.name,
    required this.colorIndex,
    required this.role,
    required this.joinedAt,
    required this.lastReadAt,
    this.lastSeenAt,
  });

  bool get isOwner => role == 'owner';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'colorIndex': colorIndex,
      'role': role,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastReadAt': lastReadAt.millisecondsSinceEpoch,
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.millisecondsSinceEpoch,
    };
  }

  factory GroupMemberModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final parsedUid = uid.isNotEmpty ? uid : ((map['uid'] as String?) ?? '');
    return GroupMemberModel(
      uid: parsedUid,
      name: (map['name'] as String?)?.trim() ?? 'Anggota',
      colorIndex: ((map['colorIndex'] ?? map['color_index']) as num?)?.toInt() ?? 0,
      role: map['role'] as String? ?? 'member',
      joinedAt: parseDate(map['joinedAt'] ?? map['joined_at']),
      lastReadAt: parseDate(map['lastReadAt'] ?? map['last_read_at']),
      lastSeenAt: parseNullableDate(map['lastSeenAt'] ?? map['last_seen_at']),
    );
  }

  GroupMemberModel copyWith({
    String? name,
    int? colorIndex,
    String? role,
    DateTime? joinedAt,
    DateTime? lastReadAt,
    DateTime? lastSeenAt,
  }) {
    return GroupMemberModel(
      uid: uid,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

