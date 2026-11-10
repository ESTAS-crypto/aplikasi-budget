import 'group_note_model.dart';

/// Model Sesi Aktif Permainan & Budget Grup
class GroupSessionModel {
  final String sessionId;
  final int budget;
  final String game; // 'wheel' | 'dice' | 'capsule' | 'envelope' | 'coin' | 'fixed'
  final String startedByUid;
  final String startedByName;
  final DateTime startedAt;
  final bool locked;
  final String? turnLockedByUid; // untuk Lempar Koin turn-lock
  final String? turnLockedByName;
  final DateTime? turnLockedAt;

  const GroupSessionModel({
    required this.sessionId,
    required this.budget,
    this.game = 'wheel',
    required this.startedByUid,
    required this.startedByName,
    required this.startedAt,
    this.locked = true,
    this.turnLockedByUid,
    this.turnLockedByName,
    this.turnLockedAt,
  });

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
    int? budget,
    String? game,
    String? startedByUid,
    String? startedByName,
    DateTime? startedAt,
    bool? locked,
    String? turnLockedByUid,
    String? turnLockedByName,
    DateTime? turnLockedAt,
    bool clearTurnLock = false,
  }) {
    return GroupSessionModel(
      sessionId: sessionId ?? this.sessionId,
      budget: budget ?? this.budget,
      game: game ?? this.game,
      startedByUid: startedByUid ?? this.startedByUid,
      startedByName: startedByName ?? this.startedByName,
      startedAt: startedAt ?? this.startedAt,
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
      'sessionId': sessionId,
      'session_id': sessionId,
      'budget': budget,
      'game': game,
      'startedByUid': startedByUid,
      'started_by_uid': startedByUid,
      'startedByName': startedByName,
      'started_by_name': startedByName,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'started_at': startedAt.toIso8601String(),
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

    final rawTurnLockedAt = map['turnLockedAt'] ?? map['turn_locked_at'];
    DateTime? turnLockedAt;
    if (rawTurnLockedAt != null) {
      if (rawTurnLockedAt is int) {
        turnLockedAt = DateTime.fromMillisecondsSinceEpoch(rawTurnLockedAt);
      } else if (rawTurnLockedAt is String) {
        turnLockedAt = DateTime.tryParse(rawTurnLockedAt);
      }
    }

    final rawLocked = map['locked'];
    final locked = rawLocked is bool ? rawLocked : true;

    return GroupSessionModel(
      sessionId: (map['sessionId'] ?? map['session_id']) as String? ?? '',
      budget: (map['budget'] as num?)?.toInt() ?? 0,
      game: (map['game'] as String?)?.trim() ?? 'wheel',
      startedByUid:
          (map['startedByUid'] ?? map['started_by_uid']) as String? ?? '',
      startedByName:
          ((map['startedByName'] ?? map['started_by_name']) as String?)?.trim() ??
              'Anggota',
      startedAt: parseDate(map['startedAt'] ?? map['started_at']),
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

  bool canUserPlay(String uid) {
    if (playPolicy == 'owner') {
      return ownerUid == uid;
    }
    return true;
  }

  /// Cek apakah pengguna saat ini adalah pemilik grup
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

    return GroupModel(
      id: id,
      name: (map['name'] as String?)?.trim() ?? 'Grup',
      ownerUid: (map['ownerUid'] ?? map['owner_uid']) as String? ?? '',
      code: map['code'] as String? ?? '',
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      memberCount: ((map['memberCount'] ?? map['member_count']) as num?)?.toInt() ?? 1,
      activeSession: sessionData is Map
          ? GroupSessionModel.fromMap(Map<String, dynamic>.from(sessionData))
          : null,
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
