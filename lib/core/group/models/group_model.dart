import 'dart:convert';
import 'group_note_model.dart';

/// Model Sesi Aktif & Riwayat Sesi (Date) Grup: /groups/{gid}/sessions/{sessionId}
class GroupSessionModel {
  final String sessionId;
  final String gid;
  final int budget;
  final String game; // 'wheel' | 'dice' | 'capsule' | 'envelope' | 'coin' | 'fixed'
  final String startedByUid;
  final String startedByName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? endedByUid;
  final String? endedByName;
  final String budgetByUid;
  final String budgetByName;
  final dynamic detail; // rincian hasil permainan: dadu, irisan, kapsul, amplop, koin, atau kosong untuk fixed
  final String status; // 'running' | 'lolos' | 'lewat'
  final int totalSpent;
  final bool locked;
  final String? turnLockedByUid; // untuk Lempar Koin turn-lock
  final String? turnLockedByName;
  final DateTime? turnLockedAt;

  const GroupSessionModel({
    required this.sessionId,
    this.gid = '',
    required this.budget,
    this.game = 'wheel',
    required this.startedByUid,
    required this.startedByName,
    required this.startedAt,
    this.endedAt,
    this.endedByUid,
    this.endedByName,
    String? budgetByUid,
    String? budgetByName,
    this.detail,
    this.status = 'running',
    this.totalSpent = 0,
    this.locked = true,
    this.turnLockedByUid,
    this.turnLockedByName,
    this.turnLockedAt,
  })  : budgetByUid = budgetByUid ?? startedByUid,
        budgetByName = budgetByName ?? startedByName;

  bool get isEnded =>
      endedAt != null || status == 'lolos' || status == 'lewat';

  bool get isRunning => !isEnded;

  /// Status: Lolos bila totalSpent <= budget, selain itu Lewat
  bool get isLolos => totalSpent <= budget;

  bool get isLewat => totalSpent > budget;

  /// Hemat = budget - totalSpent
  int get hemat => budget - totalSpent;

  /// Selisih bila lewat (totalSpent - budget), 0 bila lolos
  int get overBudgetAmount => totalSpent > budget ? totalSpent - budget : 0;

  bool get isTurnLocked {
    if (turnLockedByUid == null || turnLockedByUid!.isEmpty) return false;
    // Safety auto-unlock bila terkunci lebih dari 90 detik tanpa aktivitas
    if (turnLockedAt != null &&
        DateTime.now().difference(turnLockedAt!).inSeconds > 90) {
      return false;
    }
    return true;
  }

  bool isTurnLockedBy(String uid) {
    if (!isTurnLocked) return false;
    return turnLockedByUid == uid;
  }

  GroupSessionModel copyWith({
    String? sessionId,
    String? gid,
    int? budget,
    String? game,
    String? startedByUid,
    String? startedByName,
    DateTime? startedAt,
    DateTime? endedAt,
    String? endedByUid,
    String? endedByName,
    String? budgetByUid,
    String? budgetByName,
    dynamic detail,
    String? status,
    int? totalSpent,
    bool? locked,
    String? turnLockedByUid,
    String? turnLockedByName,
    DateTime? turnLockedAt,
    bool clearTurnLock = false,
    bool clearEnded = false,
  }) {
    return GroupSessionModel(
      sessionId: sessionId ?? this.sessionId,
      gid: gid ?? this.gid,
      budget: budget ?? this.budget,
      game: game ?? this.game,
      startedByUid: startedByUid ?? this.startedByUid,
      startedByName: startedByName ?? this.startedByName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEnded ? null : (endedAt ?? this.endedAt),
      endedByUid: clearEnded ? null : (endedByUid ?? this.endedByUid),
      endedByName: clearEnded ? null : (endedByName ?? this.endedByName),
      budgetByUid: budgetByUid ?? this.budgetByUid,
      budgetByName: budgetByName ?? this.budgetByName,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      totalSpent: totalSpent ?? this.totalSpent,
      locked: locked ?? this.locked,
      turnLockedByUid:
          clearTurnLock ? null : (turnLockedByUid ?? this.turnLockedByUid),
      turnLockedByName:
          clearTurnLock ? null : (turnLockedByName ?? this.turnLockedByName),
      turnLockedAt:
          clearTurnLock ? null : (turnLockedAt ?? this.turnLockedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': sessionId,
      'sessionId': sessionId,
      'session_id': sessionId,
      if (gid.isNotEmpty) 'gid': gid,
      'budget': budget,
      'game': game,
      'startedByUid': startedByUid,
      'started_by_uid': startedByUid,
      'startedByName': startedByName,
      'started_by_name': startedByName,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.millisecondsSinceEpoch,
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      if (endedByUid != null) 'endedByUid': endedByUid,
      if (endedByUid != null) 'ended_by_uid': endedByUid,
      if (endedByName != null) 'endedByName': endedByName,
      if (endedByName != null) 'ended_by_name': endedByName,
      'budgetByUid': budgetByUid,
      'budget_by_uid': budgetByUid,
      'budgetByName': budgetByName,
      'budget_by_name': budgetByName,
      if (detail != null) 'detail': detail,
      'status': status,
      'totalSpent': totalSpent,
      'total_spent': totalSpent,
      'locked': locked,
      if (turnLockedByUid != null) 'turnLockedByUid': turnLockedByUid,
      if (turnLockedByUid != null) 'turn_locked_by_uid': turnLockedByUid,
      if (turnLockedByName != null) 'turnLockedByName': turnLockedByName,
      if (turnLockedByName != null) 'turn_locked_by_name': turnLockedByName,
      if (turnLockedAt != null)
        'turnLockedAt': turnLockedAt!.millisecondsSinceEpoch,
      if (turnLockedAt != null)
        'turn_locked_at': turnLockedAt!.toIso8601String(),
    };
  }

  factory GroupSessionModel.fromMap(Map<String, dynamic> map) {
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

    final turnLockedAt =
        parseNullableDate(map['turnLockedAt'] ?? map['turn_locked_at']);
    final endedAt = parseNullableDate(map['endedAt'] ?? map['ended_at']);

    final rawLocked = map['locked'];
    final locked = rawLocked is bool ? rawLocked : true;

    final startedByUid =
        (map['startedByUid'] ?? map['started_by_uid']) as String? ?? '';
    final startedByName =
        ((map['startedByName'] ?? map['started_by_name']) as String?)?.trim() ??
            'Anggota';
    final budgetByUid =
        (map['budgetByUid'] ?? map['budget_by_uid']) as String? ?? startedByUid;
    final budgetByName =
        ((map['budgetByName'] ?? map['budget_by_name']) as String?)?.trim() ??
            startedByName;

    final budget = (map['budget'] as num?)?.toInt() ?? 0;
    final totalSpent =
        (map['totalSpent'] ?? map['total_spent'] as num?)?.toInt() ?? 0;
    final rawStatus = (map['status'] as String?)?.trim().toLowerCase();
    final String status;
    if (rawStatus == 'lolos' || rawStatus == 'lewat' || rawStatus == 'running') {
      status = rawStatus!;
    } else if (endedAt != null) {
      status = totalSpent <= budget ? 'lolos' : 'lewat';
    } else {
      status = 'running';
    }

    return GroupSessionModel(
      sessionId:
          (map['sessionId'] ?? map['session_id'] ?? map['id']) as String? ?? '',
      gid: (map['gid'] as String?) ?? '',
      budget: budget,
      game: (map['game'] as String?)?.trim() ?? 'wheel',
      startedByUid: startedByUid,
      startedByName: startedByName,
      startedAt: parseDate(map['startedAt'] ?? map['started_at']),
      endedAt: endedAt,
      endedByUid: (map['endedByUid'] ?? map['ended_by_uid']) as String?,
      endedByName:
          ((map['endedByName'] ?? map['ended_by_name']) as String?)?.trim(),
      budgetByUid: budgetByUid,
      budgetByName: budgetByName,
      detail: map['detail'],
      status: status,
      totalSpent: totalSpent,
      locked: locked,
      turnLockedByUid:
          (map['turnLockedByUid'] ?? map['turn_locked_by_uid']) as String?,
      turnLockedByName:
          (map['turnLockedByName'] ?? map['turn_locked_by_name']) as String?,
      turnLockedAt: turnLockedAt,
    );
  }
}

/// Model Grup di Firestore / Supabase: /groups/{gid}
class GroupModel {
  final String id;
  final String name;
  final String ownerUid;
  final String code; // 6 karakter unik
  final DateTime createdAt;
  final int memberCount; // Maksimum 10
  final GroupSessionModel? activeSession;
  final String budgetMode; // 'game' (default) | 'fixed'
  final int fixedBudget; // default 200000, rentang 10.000 - 10.000.000
  final String playPolicy; // 'all' (default) | 'owner'
  final String lockPolicy; // 'lock' (default) | 'free'
  final List<String> enabledGames; // subset dari ['wheel', 'dice', 'capsule', 'envelope', 'coin']
  final Map<String, List<int>> pools; // {wheel: [int], capsule: [int], envelope: [int]}
  final Map<String, int> diceConfig; // {count: 1..3, multiplier: int}
  final int coinBase; // default 50000

  // Fallback default slots & pools
  static const List<int> defaultSlots = [
    20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000
  ];

  static const List<int> defaultCapsulePool = [
    20000, 30000, 40000, 50000, 60000, 75000, 100000, 150000
  ];

  static const List<int> defaultEnvelopePool = [
    25000, 50000, 75000, 100000, 150000, 200000
  ];

  static const List<String> defaultAllGames = [
    'wheel', 'dice', 'capsule', 'envelope', 'coin'
  ];

  static const Map<String, int> defaultDiceConfig = {
    'count': 2,
    'multiplier': 10000,
  };

  // Backward compatibility getter
  List<int>? get wheelSlots => pools['wheel'] ?? defaultSlots;
  List<int> get effectiveSlots => getWheelPool();
  String get spinPolicy => playPolicy;

  List<int> getWheelPool() {
    final list = pools['wheel'];
    if (list != null && list.length >= 2) return list;
    return defaultSlots;
  }

  List<int> getCapsulePool() {
    final list = pools['capsule'];
    if (list != null && list.length >= 2) return list;
    return defaultCapsulePool;
  }

  List<int> getEnvelopePool() {
    final list = pools['envelope'];
    if (list != null && list.length >= 3) return list;
    return defaultEnvelopePool;
  }

  int get diceCount => (diceConfig['count'] ?? 2).clamp(1, 3);
  int get diceMultiplier => (diceConfig['multiplier'] ?? 10000);

  bool isGameEnabled(String gameKey) {
    return enabledGames.contains(gameKey.toLowerCase().trim());
  }

  /// Evaluasi izin bermain grup sesuai aturan F1:
  /// canPlay(group, session, uid)
  bool canUserPlay(String uid, [GroupSessionModel? session]) {
    return canPlay(this, session ?? activeSession, uid);
  }

  /// Cek apakah pengguna saat ini adalah pemilik grup.
  /// Aturan F1: isOwner = group.ownerUid == uid. Tidak ada sumber lain.
  bool isOwner(String uid) => ownerUid.isNotEmpty && ownerUid == uid;

  bool get isSessionLocked {
    return activeSession != null && activeSession!.locked && lockPolicy == 'lock';
  }

  const GroupModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.code,
    required this.createdAt,
    this.memberCount = 1,
    this.activeSession,
    this.budgetMode = 'game',
    this.fixedBudget = 200000,
    this.playPolicy = 'all',
    this.lockPolicy = 'lock',
    this.enabledGames = defaultAllGames,
    this.pools = const {
      'wheel': defaultSlots,
      'capsule': defaultCapsulePool,
      'envelope': defaultEnvelopePool,
    },
    this.diceConfig = defaultDiceConfig,
    this.coinBase = 50000,
    List<int>? wheelSlots,
    String? spinPolicy,
  });

  /// Menghitung total pengeluaran untuk sesi aktif yang tidak berstatus deleted
  static int calculateTotalSpent(
    String sessionId,
    List<GroupNoteModel> notes,
  ) {
    return notes
        .where((n) => n.sessionId == sessionId && !n.deleted)
        .fold(0, (sum, item) => sum + item.amount);
  }

  /// Menghitung sisa budget sesi secara deterministik (append-only)
  /// Sisa budget TIDAK disimpan sebagai angka bersama di server
  static int calculateRemainingBudget({
    required int sessionBudget,
    required String sessionId,
    required List<GroupNoteModel> notes,
  }) {
    final spent = calculateTotalSpent(sessionId, notes);
    return sessionBudget - spent;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'owner_uid': ownerUid,
      'code': code,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'created_at': createdAt.toIso8601String(),
      'memberCount': memberCount,
      'member_count': memberCount,
      if (activeSession != null) 'activeSession': activeSession!.toMap(),
      if (activeSession != null) 'active_session': activeSession!.toMap(),
      'budgetMode': budgetMode,
      'budget_mode': budgetMode,
      'fixedBudget': fixedBudget,
      'fixed_budget': fixedBudget,
      'playPolicy': playPolicy,
      'play_policy': playPolicy,
      'spinPolicy': playPolicy,
      'spin_policy': playPolicy,
      'lockPolicy': lockPolicy,
      'lock_policy': lockPolicy,
      'enabledGames': enabledGames,
      'enabled_games': enabledGames,
      'pools': pools,
      'wheelSlots': getWheelPool(),
      'wheel_slots': getWheelPool(),
      'diceConfig': diceConfig,
      'dice_config': diceConfig,
      'coinBase': coinBase,
      'coin_base': coinBase,
    };
  }

  static List<int> _sanitizeIntList(
    dynamic raw, {
    required int minItems,
    required List<int> fallback,
  }) {
    if (raw is! List) return List.from(fallback);
    final sanitized = raw
        .map((e) => (e as num).toInt())
        .where((v) => v >= 1000 && v <= 10000000)
        .take(12)
        .toList();
    if (sanitized.length < minItems) return List.from(fallback);
    return sanitized;
  }

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final sessionData = map['activeSession'] ?? map['active_session'];

    // Parse enabled games
    final rawEnabled = map['enabledGames'] ?? map['enabled_games'];
    List<String> enabledGames = defaultAllGames;
    if (rawEnabled is List) {
      enabledGames = rawEnabled
          .map((e) => e.toString().toLowerCase().trim())
          .where((k) => defaultAllGames.contains(k))
          .toList();
      if (enabledGames.isEmpty) {
        enabledGames = defaultAllGames;
      }
    }

    // Parse pools
    final rawPools = map['pools'];
    Map<String, List<int>> pools = {};
    if (rawPools is Map) {
      pools['wheel'] = _sanitizeIntList(
        rawPools['wheel'],
        minItems: 2,
        fallback: defaultSlots,
      );
      pools['capsule'] = _sanitizeIntList(
        rawPools['capsule'],
        minItems: 2,
        fallback: defaultCapsulePool,
      );
      pools['envelope'] = _sanitizeIntList(
        rawPools['envelope'],
        minItems: 3,
        fallback: defaultEnvelopePool,
      );
    } else {
      // Backward compatibility: cek wheelSlots / wheel_slots
      final legacyWheel = map['wheelSlots'] ?? map['wheel_slots'];
      final wheelPool = _sanitizeIntList(
        legacyWheel,
        minItems: 2,
        fallback: defaultSlots,
      );
      pools = {
        'wheel': wheelPool,
        'capsule': defaultCapsulePool,
        'envelope': defaultEnvelopePool,
      };
    }

    // Parse diceConfig
    final rawDice = map['diceConfig'] ?? map['dice_config'];
    Map<String, int> diceConfig = defaultDiceConfig;
    if (rawDice is Map) {
      diceConfig = {
        'count': ((rawDice['count'] as num?)?.toInt() ?? 2).clamp(1, 3),
        'multiplier': (rawDice['multiplier'] as num?)?.toInt() ?? 10000,
      };
    }

    // Parse coinBase
    final rawCoinBase = map['coinBase'] ?? map['coin_base'];
    final coinBase = ((rawCoinBase as num?)?.toInt() ?? 50000).clamp(1000, 10000000);

    final rawBudgetMode = map['budgetMode'] ?? map['budget_mode'];
    final budgetMode = rawBudgetMode == 'fixed' ? 'fixed' : 'game';

    final rawFixedBudget = map['fixedBudget'] ?? map['fixed_budget'];
    final fixedBudget = ((rawFixedBudget as num?)?.toInt() ?? 200000).clamp(10000, 10000000);

    // Parse playPolicy / spinPolicy
    final rawPlayPolicy = map['playPolicy'] ??
        map['play_policy'] ??
        map['spinPolicy'] ??
        map['spin_policy'];
    final playPolicy = rawPlayPolicy == 'owner' ? 'owner' : 'all';

    final rawLockPolicy = map['lockPolicy'] ?? map['lock_policy'];
    final lockPolicy = rawLockPolicy == 'free' ? 'free' : 'lock';

    GroupSessionModel? parsedSession;
    if (sessionData is Map) {
      parsedSession = GroupSessionModel.fromMap(Map<String, dynamic>.from(sessionData));
    } else if (sessionData is String && sessionData.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(sessionData);
        if (decoded is Map) {
          parsedSession = GroupSessionModel.fromMap(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return GroupModel(
      id: id,
      name: (map['name'] as String?)?.trim() ?? 'Grup',
      ownerUid: (map['ownerUid'] ?? map['owner_uid']) as String? ?? '',
      code: map['code'] as String? ?? '',
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      memberCount: ((map['memberCount'] ?? map['member_count']) as num?)?.toInt() ?? 1,
      activeSession: parsedSession,
      budgetMode: budgetMode,
      fixedBudget: fixedBudget,
      playPolicy: playPolicy,
      lockPolicy: lockPolicy,
      enabledGames: enabledGames,
      pools: pools,
      diceConfig: diceConfig,
      coinBase: coinBase,
    );
  }

  GroupModel copyWith({
    String? name,
    String? code,
    int? memberCount,
    GroupSessionModel? activeSession,
    bool clearActiveSession = false,
    String? budgetMode,
    int? fixedBudget,
    String? playPolicy,
    String? spinPolicy,
    String? lockPolicy,
    List<String>? enabledGames,
    Map<String, List<int>>? pools,
    List<int>? wheelSlots,
    Map<String, int>? diceConfig,
    int? coinBase,
  }) {
    Map<String, List<int>> updatedPools = pools != null
        ? Map.from(pools)
        : Map.from(this.pools);

    if (wheelSlots != null && wheelSlots.length >= 2) {
      updatedPools['wheel'] = wheelSlots;
    }

    final effectivePlayPolicy = playPolicy ?? spinPolicy ?? this.playPolicy;

    return GroupModel(
      id: id,
      name: name ?? this.name,
      ownerUid: ownerUid,
      code: code ?? this.code,
      createdAt: createdAt,
      memberCount: memberCount ?? this.memberCount,
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      budgetMode: budgetMode ?? this.budgetMode,
      fixedBudget: fixedBudget ?? this.fixedBudget,
      playPolicy: effectivePlayPolicy,
      lockPolicy: lockPolicy ?? this.lockPolicy,
      enabledGames: enabledGames ?? this.enabledGames,
      pools: updatedPools,
      diceConfig: diceConfig ?? this.diceConfig,
      coinBase: coinBase ?? this.coinBase,
    );
  }
}

/// Alasan penolakan izin bermain grup sesuai spesifikasi F1:
/// PlayDenied {notOwner, sessionLocked, notMember, offlineNoGroup, other}
enum PlayDenied {
  none,
  notOwner,
  sessionLocked,
  notMember,
  offlineNoGroup,
  other;

  String get message {
    switch (this) {
      case PlayDenied.none:
        return '';
      case PlayDenied.notOwner:
        return 'Hanya pemilik yang bisa memutar';
      case PlayDenied.sessionLocked:
        return 'Date berjalan, budget sudah ditentukan';
      case PlayDenied.notMember:
        return 'Anda bukan anggota grup ini';
      case PlayDenied.offlineNoGroup:
        return 'Grup tidak ditemukan';
      case PlayDenied.other:
        return 'Permainan tidak tersedia';
    }
  }

  /// Format pesan kontekstual jika nama penentu budget diketahui
  String messageWithAuthor(String? authorName) {
    if (this == PlayDenied.sessionLocked) {
      final name = (authorName != null && authorName.trim().isNotEmpty)
          ? authorName.trim()
          : 'anggota';
      return 'Date berjalan, budget sudah ditentukan oleh $name';
    }
    return message;
  }
}

/// Hasil evaluasi izin bermain grup
class PlayPermissionResult {
  final bool allowed;
  final PlayDenied deniedReason;
  final String message;

  const PlayPermissionResult({
    required this.allowed,
    this.deniedReason = PlayDenied.none,
    this.message = '',
  });

  static const ok = PlayPermissionResult(allowed: true, deniedReason: PlayDenied.none);
}

/// Evaluasi mendalam hak bermain grup sesuai aturan F1:
/// - isOwner = group.ownerUid == uid. Tidak ada sumber lain.
/// - Pemilik SELALU boleh memutar atau mengulang, kapan pun, termasuk saat sesi terkunci.
/// - Anggota mengikuti kebijakan grup:
///   playPolicy == owner -> anggota tidak boleh ("Hanya pemilik yang bisa memutar")
///   lockPolicy == lock dan sesi sudah punya budget -> terkunci ("Date berjalan, budget sudah ditentukan oleh {nama}")
PlayPermissionResult evaluateCanPlay({
  required GroupModel? group,
  GroupSessionModel? session,
  required String uid,
  bool isCurrentUserOwner = false,
}) {
  if (group == null) {
    return const PlayPermissionResult(
      allowed: false,
      deniedReason: PlayDenied.offlineNoGroup,
      message: 'Grup tidak ditemukan',
    );
  }

  if (uid.isEmpty) {
    return const PlayPermissionResult(
      allowed: false,
      deniedReason: PlayDenied.notMember,
      message: 'Anda bukan anggota grup ini',
    );
  }

  // isOwner = group.ownerUid == uid atau diakui sebagai owner via AuthService/role
  final isOwner = group.ownerUid == uid || isCurrentUserOwner;

  // Pemilik SELALU boleh memutar atau mengulang, kapan pun, termasuk saat sesi terkunci.
  if (isOwner) {
    return PlayPermissionResult.ok;
  }

  // Anggota mengikuti kebijakan grup:
  // playPolicy == owner -> anggota tidak boleh (pesan "Hanya pemilik yang bisa memutar")
  if (group.playPolicy == 'owner') {
    return const PlayPermissionResult(
      allowed: false,
      deniedReason: PlayDenied.notOwner,
      message: 'Hanya pemilik yang bisa memutar',
    );
  }

  // lockPolicy == lock dan sesi sudah punya budget -> terkunci
  final effSession = session ?? group.activeSession;
  final hasBudget = effSession != null &&
      effSession.sessionId.isNotEmpty &&
      effSession.budget > 0;
  final isLocked = (effSession != null && effSession.locked) ||
      (group.lockPolicy == 'lock' && hasBudget);

  if (isLocked) {
    final authorName = effSession.startedByName;
    return PlayPermissionResult(
      allowed: false,
      deniedReason: PlayDenied.sessionLocked,
      message: PlayDenied.sessionLocked.messageWithAuthor(authorName),
    );
  }

  return PlayPermissionResult.ok;
}

/// Fungsi canPlay sesuai spesifikasi F1: canPlay(group, session, uid)
bool canPlay(GroupModel? group, GroupSessionModel? session, String uid) {
  return evaluateCanPlay(group: group, session: session, uid: uid).allowed;
}
