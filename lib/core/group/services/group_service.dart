import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/group_note_model.dart';
import '../models/group_event_model.dart';
import '../models/invite_code_model.dart';
import '../../utils/rupiah_formatter.dart';
import 'group_auth_service.dart';

/// Service untuk Operasi Grup Bersama (Local-First dengan Supabase PostgreSQL)
class GroupService {
  static const String keyActiveGroupId = 'active_group_id';

  final dynamic firestore;
  final SupabaseClient? supabase;
  final GroupAuthService authService;
  final SharedPreferences prefs;

  ValueChanged<String?>? onActiveGroupIdChanged;

  RealtimeChannel? _realtimeChannel;
  String? _subscribedChannelGid;
  Completer<void>? _channelSubscribeCompleter;
  bool _isChannelSubscribed = false;

  GroupService({
    this.firestore,
    this.supabase,
    required this.authService,
    required this.prefs,
  });

  final List<void Function(Map<String, dynamic>)> _onBroadcastCallbacks = [];

  final Map<String, List<StreamController<List<GroupEventModel>>>> _eventsControllers = {};
  final Map<String, List<StreamController<List<GroupMemberModel>>>> _membersControllers = {};
  final Map<String, List<StreamController<List<GroupNoteModel>>>> _notesControllers = {};
  final Map<String, List<StreamController<GroupModel?>>> _groupControllers = {};
  final Map<String, List<StreamController<Map<String, dynamic>>>> _liveSpinControllers = {};

  void _notifyLiveSpin(String gid, Map<String, dynamic> data) {
    final controllers = _liveSpinControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(Map<String, dynamic>.from(data));
      }
    }
  }

  void _notifyEventsChanged(String gid, List<GroupEventModel> events) {
    final controllers = _eventsControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(List.from(events));
      }
    }
  }

  void _notifyMembersChanged(String gid, List<GroupMemberModel> members) {
    final controllers = _membersControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(List.from(members));
      }
    }
  }

  void _notifyNotesChanged(String gid, List<GroupNoteModel> notes) {
    final controllers = _notesControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(List.from(notes));
      }
    }
  }

  void _notifyGroupChanged(String gid, GroupModel? group) {
    final controllers = _groupControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(group);
      }
    }
  }

  // Pelacak putaran roda yang baru saja mendarat agar notifikasi instan 0ms tidak berulang
  String? _lastShownSpinSessionId;
  DateTime? _lastShownSpinTime;

  void markSpinAsShown(String sessionId) {
    if (sessionId.isEmpty) return;
    _lastShownSpinSessionId = sessionId;
    _lastShownSpinTime = DateTime.now();
  }

  bool wasSpinRecentlyShown(String sessionId) {
    if (sessionId.isEmpty) return false;
    if (_lastShownSpinSessionId == sessionId && _lastShownSpinTime != null) {
      if (DateTime.now().difference(_lastShownSpinTime!).inSeconds < 10) {
        return true;
      }
    }
    return false;
  }

  void _handlePresencePulse(String gid, Map<String, dynamic> data) {
    try {
      final pulseUid = data['uid']?.toString() ?? '';
      if (pulseUid.isEmpty) return;
      final curMembers = _getLocalMembers(gid);
      final index = curMembers.indexWhere((m) => m.uid == pulseUid);
      if (index != -1) {
        final m = curMembers[index];
        final updated = curMembers.toList();
        updated[index] = GroupMemberModel(
          uid: m.uid,
          name: m.name,
          colorIndex: m.colorIndex,
          role: m.role,
          joinedAt: m.joinedAt,
          lastReadAt: m.lastReadAt,
          lastSeenAt: DateTime.now(),
        );
        _saveLocalMembers(gid, updated);
        _notifyMembersChanged(gid, updated);
      }
    } catch (_) {}
  }

  /// Memastikan channel realtime untuk grup aktif dan tersambung
  Future<RealtimeChannel?> ensureChannelSubscribed(String gid, {void Function(Map<String, dynamic>)? onBroadcastEvent}) async {
    final ch = _ensureChannel(gid, onBroadcastEvent: onBroadcastEvent);
    if (ch == null) return null;
    if (_isChannelSubscribed && _subscribedChannelGid == gid) return ch;
    if (_channelSubscribeCompleter != null && !_channelSubscribeCompleter!.isCompleted) {
      await _channelSubscribeCompleter!.future.timeout(const Duration(milliseconds: 3000), onTimeout: () {});
    }
    return ch;
  }

  /// Mengaktifkan koneksi realtime grup sedini mungkin
  void ensureRealtimeActive(String gid) {
    _ensureChannel(gid);
  }

  RealtimeChannel? _ensureChannel(String gid, {void Function(Map<String, dynamic>)? onBroadcastEvent}) {
    if (supabase == null) return null;
    if (onBroadcastEvent != null && !_onBroadcastCallbacks.contains(onBroadcastEvent)) {
      _onBroadcastCallbacks.add(onBroadcastEvent);
    }
    if (_realtimeChannel != null && _subscribedChannelGid == gid) {
      return _realtimeChannel;
    }
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    _subscribedChannelGid = gid;
    _isChannelSubscribed = false;
    _channelSubscribeCompleter = Completer<void>();

    final ch = supabase!.channel('realtime_group_$gid');
    ch.onBroadcast(
      event: 'group_event',
      callback: (payload) {
        final data = Map<String, dynamic>.from(payload);
        _handleIncomingRealtimeBroadcast(gid, data);
        for (final cb in List.of(_onBroadcastCallbacks)) {
          cb(data);
        }
      },
    );
    ch.onBroadcast(
      event: 'wheel_spin_live',
      callback: (payload) {
        _notifyLiveSpin(gid, Map<String, dynamic>.from(payload));
      },
    );
    ch.onBroadcast(
      event: 'presence_pulse',
      callback: (payload) {
        _handlePresencePulse(gid, Map<String, dynamic>.from(payload));
      },
    );

    ch.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isChannelSubscribed = true;
        if (!(_channelSubscribeCompleter?.isCompleted ?? true)) {
          _channelSubscribeCompleter?.complete();
        }
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        _isChannelSubscribed = false;
      }
    });

    _realtimeChannel = ch;
    return _realtimeChannel;
  }

  /// Menonton putaran roda live untuk spectator (anggota grup)
  Stream<Map<String, dynamic>> watchLiveSpin(String gid) {
    _ensureChannel(gid);
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _liveSpinControllers.putIfAbsent(gid, () => []).add(controller);

    controller.onCancel = () {
      _liveSpinControllers[gid]?.remove(controller);
    };

    return controller.stream;
  }

  /// Menyiarkan animasi putaran roda secara realtime ke seluruh anggota yang menonton
  Future<void> broadcastLiveSpin({
    required String gid,
    double? targetNormalizedAngle,
    double? targetDegree,
    required int winningIndex,
    required int budget,
    int turns = 5,
    int durationMs = 5000,
    String? actorUid,
    String? actorName,
    String? sessionId,
    String? eventId,
  }) async {
    final uid = actorUid ?? authService.currentUid ?? '';
    final name = actorName ?? authService.displayName ?? 'Pemilik Grup';
    final normalized = targetNormalizedAngle ?? (((targetDegree ?? 1800.0) % 360.0 + 360.0) % 360.0);
    final payload = {
      'type': 'wheel_spin_live',
      'gid': gid,
      'actor_uid': uid,
      'actor_name': name,
      'target_normalized_angle': normalized,
      'target_degree': targetDegree ?? normalized,
      'winning_index': winningIndex,
      'budget': budget,
      'turns': turns,
      'duration_ms': durationMs,
      'session_id': sessionId,
      'event_id': eventId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 1. Kirim ke listener stream lokal
    _notifyLiveSpin(gid, payload);

    // 2. Broadcast ke semua perangkat melalui Supabase Realtime channel WebSocket
    if (supabase != null) {
      try {
        final ch = await ensureChannelSubscribed(gid);
        await ch?.sendBroadcastMessage(
          event: 'wheel_spin_live',
          payload: payload,
        );
      } catch (e) {
        debugPrint('[GroupService] Broadcast live spin error: $e');
      }
    }

    // 3. Fallback Firestore liveSpin field jika ada
    if (firestore != null) {
      try {
        await firestore!.collection('groups').doc(gid).update({
          'liveSpin': payload,
        });
      } catch (_) {}
    }
  }

  Future<void> _broadcastGroupEvent(String gid, Map<String, dynamic> eventMap) async {
    if (supabase == null) return;
    try {
      final ch = await ensureChannelSubscribed(gid);
      await ch?.sendBroadcastMessage(
        event: 'group_event',
        payload: eventMap,
      );
    } catch (e) {
      debugPrint('[GroupService] Broadcast error: $e');
    }
  }

  // Kunci Cache Lokal SharedPreferences
  String _keyLocalGroup(String gid) => 'local_group_$gid';
  String _keyLocalMembers(String gid) => 'local_members_$gid';
  String _keyLocalNotes(String gid) => 'local_notes_$gid';
  String _keyLocalEvents(String gid) => 'local_events_$gid';
  String _keyStoredGroupSlots(String gid) => 'group_wheel_slots_$gid';

  Future<void> _saveStoredGroupSlots(String gid, List<int> slots) async {
    try {
      await prefs.setString(_keyStoredGroupSlots(gid), jsonEncode(slots));
    } catch (_) {}
  }

  List<int>? _getStoredGroupSlots(String gid) {
    final str = prefs.getString(_keyStoredGroupSlots(gid));
    if (str == null) return null;
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalGroup(GroupModel group) async {
    try {
      final currentStr = prefs.getString(_keyLocalGroup(group.id));
      final newStr = jsonEncode(group.toMap());
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalGroup(group.id), newStr);
      _notifyGroupChanged(group.id, group);
    } catch (_) {}
  }

  GroupModel? _getLocalGroup(String gid) {
    final str = prefs.getString(_keyLocalGroup(gid));
    if (str == null) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return GroupModel.fromMap(gid, map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalMembers(String gid, List<GroupMemberModel> members) async {
    try {
      final seenUids = <String>{};
      final uniqueMembers = <GroupMemberModel>[];
      for (final m in members) {
        if (m.uid.isNotEmpty && !seenUids.contains(m.uid)) {
          seenUids.add(m.uid);
          uniqueMembers.add(m);
        }
      }
      final currentStr = prefs.getString(_keyLocalMembers(gid));
      final list = uniqueMembers.map((m) => m.toMap()).toList();
      final newStr = jsonEncode(list);
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalMembers(gid), newStr);
      _notifyMembersChanged(gid, uniqueMembers);
    } catch (_) {}
  }

  List<GroupMemberModel> _getLocalMembers(String gid) {
    final str = prefs.getString(_keyLocalMembers(gid));
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return GroupMemberModel.fromMap(map['uid']?.toString() ?? '', map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalNotes(String gid, List<GroupNoteModel> notes) async {
    try {
      final currentStr = prefs.getString(_keyLocalNotes(gid));
      final list = notes.map((n) => n.toMap()).toList();
      final newStr = jsonEncode(list);
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalNotes(gid), newStr);
      _notifyNotesChanged(gid, notes);
    } catch (_) {}
  }

  List<GroupNoteModel> _getLocalNotes(String gid) {
    final str = prefs.getString(_keyLocalNotes(gid));
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return GroupNoteModel.fromMap(map['noteId']?.toString() ?? '', map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalEvents(String gid, List<GroupEventModel> events) async {
    try {
      final currentStr = prefs.getString(_keyLocalEvents(gid));
      final list = events.map((e) => e.toMap()).toList();
      final newStr = jsonEncode(list);
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalEvents(gid), newStr);
      _notifyEventsChanged(gid, events);
    } catch (_) {}
  }

  List<GroupEventModel> _getLocalEvents(String gid) {
    final str = prefs.getString(_keyLocalEvents(gid));
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final eventId = (map['id'] ?? map['eventId'])?.toString() ?? '';
        return GroupEventModel.fromMap(eventId, map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Mengambil ID grup yang sedang aktif
  String? getActiveGroupId() {
    return prefs.getString(keyActiveGroupId);
  }

  /// Mengambil data grup lokal secara sinkron (Cache Local-First)
  GroupModel? getLocalGroup(String gid) {
    return _getLocalGroup(gid);
  }

  /// Menyimpan data grup lokal secara eksplisit
  Future<void> saveLocalGroup(GroupModel group) => _saveLocalGroup(group);

  /// Mengambil log aktivitas grup lokal secara sinkron
  List<GroupEventModel> getLocalEvents(String gid) => _getLocalEvents(gid);

  /// Mengirim notifikasi event bahwa sesi grup telah dimulai oleh pemilik
  Future<void> notifySessionStarted(String gid) async {
    final uid = await authService.ensureSignedIn();
    final actorName = authService.displayName ?? 'Pemilik Grup';
    final now = DateTime.now();

    final eventMap = {
      'id': 'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}',
      'gid': gid,
      'actor_uid': uid,
      'actor_name': actorName,
      'type': GroupEventType.sessionStart.value,
      'summary': '$actorName memulai sesi grup',
      'payload': {},
      'created_at': now.toIso8601String(),
    };

    if (supabase != null) {
      try {
        await supabase!.from('group_events').insert(eventMap);
        _broadcastGroupEvent(gid, eventMap);
      } catch (e) {
        debugPrint('[GroupService] notifySessionStarted error: $e');
      }
    }
  }

  /// Menyimpan ID grup yang sedang aktif
  Future<void> setActiveGroupId(String? gid) async {
    if (gid == null) {
      await prefs.remove(keyActiveGroupId);
    } else {
      await prefs.setString(keyActiveGroupId, gid);
    }
    onActiveGroupIdChanged?.call(gid);
  }

  /// Membuat grup baru dengan kode 6 karakter acak (Local-First)
  Future<String> createGroup({
    required String groupName,
    required String creatorName,
    required int colorIndex,
  }) async {
    final cleanName = groupName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Nama grup tidak boleh kosong.');
    }
    if (cleanName.length > 30) {
      throw ArgumentError('Nama grup maksimal 30 karakter.');
    }

    final uid = await authService.ensureSignedIn();
    await authService.setDisplayName(creatorName);
    await authService.setColorIndex(colorIndex);

    final code = InviteCodeGenerator.generate();
    final gid = 'grp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final now = DateTime.now();

    final localGroup = GroupModel(
      id: gid,
      name: cleanName,
      ownerUid: uid,
      code: code,
      createdAt: now,
      memberCount: 1,
      activeSession: null,
    );

    final localMember = GroupMemberModel(
      uid: uid,
      name: creatorName.trim(),
      colorIndex: colorIndex,
      role: 'owner',
      joinedAt: now,
      lastReadAt: now,
    );

    final localEvt = GroupEventModel(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      type: GroupEventType.memberJoin,
      actorUid: uid,
      actorName: creatorName.trim(),
      summary: '${creatorName.trim()} membuat grup "$cleanName"',
      payload: {},
      createdAt: now,
    );

    // 1. Simpan ke local persistence SharedPreferences segera
    await _saveLocalGroup(localGroup);
    await _saveLocalMembers(gid, [localMember]);
    await _saveLocalEvents(gid, [localEvt]);
    await setActiveGroupId(gid);

    // 2. Sinkronkan ke Supabase jika tersedia
    if (supabase != null) {
      try {
        await supabase!.from('groups').insert({
          'id': gid,
          'name': cleanName,
          'owner_uid': uid,
          'code': code,
          'created_at': now.toIso8601String(),
          'member_count': 1,
          'active_session': null,
        });

        await supabase!.from('group_members').insert({
          'gid': gid,
          'uid': uid,
          'name': creatorName.trim(),
          'color_index': colorIndex,
          'role': 'owner',
          'joined_at': now.toIso8601String(),
          'last_read_at': now.toIso8601String(),
        });

        await supabase!.from('invite_codes').insert({
          'code': code,
          'gid': gid,
        });

        final eventMap = {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'gid': gid,
          'actor_uid': uid,
          'actor_name': creatorName.trim(),
          'type': GroupEventType.memberJoin.value,
          'summary': '${creatorName.trim()} membuat grup "$cleanName"',
          'payload': {},
          'created_at': now.toIso8601String(),
        };

        await supabase!.from('group_events').insert(eventMap);
        _broadcastGroupEvent(gid, eventMap);
      } catch (e) {
        debugPrint('[GroupService] Supabase sync deferred: $e');
      }
    } else if (firestore != null) {
      // 3. Dukungan Firestore
      try {
        final batch = firestore!.batch();

        final groupRef = firestore!.collection('groups').doc(gid);
        batch.set(groupRef, {
          'name': cleanName,
          'ownerUid': uid,
          'code': code,
          'createdAt': now.millisecondsSinceEpoch,
          'memberCount': 1,
          'activeSession': null,
        });

        final memberRef = groupRef.collection('members').doc(uid);
        batch.set(memberRef, {
          'name': creatorName.trim(),
          'colorIndex': colorIndex,
          'role': 'owner',
          'joinedAt': now.millisecondsSinceEpoch,
          'lastReadAt': now.millisecondsSinceEpoch,
        });

        final inviteRef = firestore!.collection('inviteCodes').doc(code);
        batch.set(inviteRef, {
          'gid': gid,
          'createdAt': now.millisecondsSinceEpoch,
        });

        final eventRef = groupRef.collection('events').doc('evt_${now.millisecondsSinceEpoch}');
        batch.set(eventRef, {
          'actorUid': uid,
          'actorName': creatorName.trim(),
          'type': GroupEventType.memberJoin.name,
          'summary': '${creatorName.trim()} membuat grup "$cleanName"',
          'timestamp': now.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (e) {
        debugPrint('[GroupService] Firestore sync deferred: $e');
      }
    }

    return gid;
  }

  /// Bergabung ke grup menggunakan 6 digit kode undangan
  Future<String> joinGroupByCode({
    required String rawCode,
    required String memberName,
    required int colorIndex,
  }) async {
    final code = InviteCodeGenerator.normalize(rawCode);
    if (!InviteCodeGenerator.isValidFormat(code)) {
      throw const FormatException('Kode undangan tidak valid (harus 6 karakter huruf/angka).');
    }

    final uid = await authService.ensureSignedIn();
    await authService.setDisplayName(memberName);
    await authService.setColorIndex(colorIndex);

    // 1. Dukungan Supabase Backend
    SupabaseClient? client = supabase;
    if (client == null) {
      try {
        client = Supabase.instance.client;
      } catch (_) {}
    }

    if (client != null) {
      String? gid;
      Object? networkError;
      try {
        final codeRes = await client
            .from('invite_codes')
            .select('gid')
            .eq('code', code)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (codeRes != null && codeRes['gid'] != null) {
          gid = codeRes['gid'] as String;
        }

        // Fallback: periksa langsung di tabel groups berdasarkan kolom 'code'
        if (gid == null) {
          final groupDirect = await client
              .from('groups')
              .select('id')
              .eq('code', code)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));
          if (groupDirect != null && groupDirect['id'] != null) {
            gid = groupDirect['id'] as String;
          }
        }
      } catch (e) {
        debugPrint('[GroupService] Supabase code lookup error: $e');
        networkError = e;
      }

      if (gid == null) {
        if (networkError != null) {
          throw Exception(
            'Gagal terhubung ke server Supabase. Pastikan koneksi internet ponsel aktif dan coba lagi.\n(Detail: $networkError)',
          );
        }
        throw Exception('Kode undangan "$code" tidak ditemukan. Pastikan 6 karakter kode sudah sesuai.');
      }

      final groupRes = await client
          .from('groups')
          .select('*')
          .eq('id', gid)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (groupRes == null) {
        throw Exception('Grup dengan kode "$code" sudah tidak ditemukan atau dihapus.');
      }

      final memberCount = (groupRes['member_count'] as num?)?.toInt() ?? 1;

      // Cek apakah anggota sudah ada di grup ini berdasarkan UID atau nama tampilan
      final existingByUid = await client
          .from('group_members')
          .select('*')
          .eq('gid', gid)
          .eq('uid', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      final existingByName = existingByUid != null
          ? null
          : await client
              .from('group_members')
              .select('*')
              .eq('gid', gid)
              .ilike('name', memberName.trim())
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

      final existingMember = existingByUid ?? existingByName;

      final now = DateTime.now();

      if (existingMember == null) {
        if (memberCount >= 10) {
          throw Exception('Grup sudah penuh (maksimal 10 anggota).');
        }

        await client.from('group_members').insert({
          'gid': gid,
          'uid': uid,
          'name': memberName.trim(),
          'color_index': colorIndex,
          'role': 'member',
          'joined_at': now.toIso8601String(),
          'last_read_at': now.toIso8601String(),
        }).timeout(const Duration(seconds: 10));

        // Hitung jumlah unik anggota
        try {
          final countRes = await client
              .from('group_members')
              .select('uid')
              .eq('gid', gid)
              .timeout(const Duration(seconds: 10));
          final realMemberCount = (countRes as List)
              .map((m) => (m['uid'] ?? '').toString())
              .where((u) => u.isNotEmpty)
              .toSet()
              .length;
          await client.from('groups').update({
            'member_count': realMemberCount,
          }).eq('id', gid).timeout(const Duration(seconds: 10));
        } catch (_) {}

        final joinEvtMap = {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'gid': gid,
          'actor_uid': uid,
          'actor_name': memberName.trim(),
          'type': GroupEventType.memberJoin.value,
          'summary': '${memberName.trim()} bergabung ke grup',
          'payload': {
            'uid': uid,
            'name': memberName.trim(),
            'color_index': colorIndex,
            'role': 'member',
          },
          'created_at': now.toIso8601String(),
        };

        try {
          await client.from('group_events').insert(joinEvtMap).timeout(const Duration(seconds: 10));
        } catch (_) {}
        await _broadcastGroupEvent(gid, joinEvtMap);

        final localJoinEvt = GroupEventModel.fromMap(joinEvtMap['id'].toString(), joinEvtMap);
        final currentEvts = _getLocalEvents(gid);
        final updatedEvts = [localJoinEvt, ...currentEvts];
        await _saveLocalEvents(gid, updatedEvts);
        _notifyEventsChanged(gid, updatedEvts);
      } else {
        // Anggota sudah pernah terdaftar, perbarui data profil & UID-nya
        try {
          final targetId = existingMember['id'];
          if (targetId != null) {
            await client.from('group_members').update({
              'uid': uid,
              'name': memberName.trim(),
              'color_index': colorIndex,
              'last_seen_at': now.toIso8601String(),
            }).eq('id', targetId).timeout(const Duration(seconds: 10));
          } else {
            await client.from('group_members').update({
              'name': memberName.trim(),
              'color_index': colorIndex,
              'last_seen_at': now.toIso8601String(),
            }).eq('gid', gid).eq('uid', uid).timeout(const Duration(seconds: 10));
          }
        } catch (_) {}

        final rejoinEvtMap = {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'gid': gid,
          'actor_uid': uid,
          'actor_name': memberName.trim(),
          'type': GroupEventType.memberJoin.value,
          'summary': '${memberName.trim()} bergabung kembali ke grup',
          'payload': {
            'uid': uid,
            'name': memberName.trim(),
            'color_index': colorIndex,
            'role': 'member',
          },
          'created_at': now.toIso8601String(),
        };
        try {
          await client.from('group_events').insert(rejoinEvtMap).timeout(const Duration(seconds: 10));
        } catch (_) {}
        await _broadcastGroupEvent(gid, rejoinEvtMap);

        final localJoinEvt = GroupEventModel.fromMap(rejoinEvtMap['id'].toString(), rejoinEvtMap);
        final currentEvts = _getLocalEvents(gid);
        final updatedEvts = [localJoinEvt, ...currentEvts];
        await _saveLocalEvents(gid, updatedEvts);
        _notifyEventsChanged(gid, updatedEvts);
      }

      // Simpan grup dan anggota ke local storage segera agar UI tidak menampilkan layar kosong
      try {
        final updatedGroupRes = await client
            .from('groups')
            .select('*')
            .eq('id', gid)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (updatedGroupRes != null) {
          final groupModel = GroupModel.fromMap(gid, updatedGroupRes);
          await _saveLocalGroup(groupModel);
        }
      } catch (_) {}

      try {
        final membersRes = await client
            .from('group_members')
            .select('*')
            .eq('gid', gid)
            .order('joined_at', ascending: true)
            .timeout(const Duration(seconds: 10));
        final membersList = _cleanAndDeduplicate(
            gid,
            (membersRes as List)
                .map((m) => GroupMemberModel.fromMap((m['uid'] ?? '').toString(), m))
                .toList());
        await _saveLocalMembers(gid, membersList);
        _notifyMembersChanged(gid, membersList);
      } catch (_) {}

      await setActiveGroupId(gid);
      ensureRealtimeActive(gid);
      return gid;
    }

    // 2. Dukungan Firestore
    if (firestore != null) {
      try {
        final inviteDoc = await firestore!.collection('inviteCodes').doc(code).get();
        if (inviteDoc.exists) {
          final gid = inviteDoc.data()?['gid'] as String?;
          if (gid != null && gid.isNotEmpty) {
            final groupRef = firestore!.collection('groups').doc(gid);
            final groupDoc = await groupRef.get();
            if (groupDoc.exists) {
              final memberCount = (groupDoc.data()?['memberCount'] as num?)?.toInt() ?? 0;
              final memberRef = groupRef.collection('members').doc(uid);
              final existingMemberDoc = await memberRef.get();

              final now = DateTime.now();

              if (!existingMemberDoc.exists) {
                if (memberCount >= 10) {
                  throw Exception('Grup sudah penuh (maksimal 10 anggota).');
                }

                final batch = firestore!.batch();
                batch.set(memberRef, {
                  'name': memberName.trim(),
                  'colorIndex': colorIndex,
                  'role': 'member',
                  'joinedAt': now.millisecondsSinceEpoch,
                  'lastReadAt': now.millisecondsSinceEpoch,
                });
                batch.update(groupRef, {'memberCount': 1});

                final eventRef = groupRef.collection('events').doc('evt_${now.millisecondsSinceEpoch}');
                final localJoinEvt = GroupEventModel(
                  eventId: 'evt_${now.millisecondsSinceEpoch}',
                  type: GroupEventType.memberJoin,
                  actorUid: uid,
                  actorName: memberName.trim(),
                  summary: '${memberName.trim()} bergabung ke grup',
                  payload: {},
                  createdAt: now,
                );
                batch.set(eventRef, {
                  'actorUid': uid,
                  'actorName': memberName.trim(),
                  'type': GroupEventType.memberJoin.name,
                  'summary': '${memberName.trim()} bergabung ke grup',
                  'timestamp': now.millisecondsSinceEpoch,
                });

                await batch.commit();

                final currentEvts = _getLocalEvents(gid);
                final updatedEvts = [localJoinEvt, ...currentEvts];
                await _saveLocalEvents(gid, updatedEvts);
                _notifyEventsChanged(gid, updatedEvts);

                final localMembers = _getLocalMembers(gid);
                final newMember = GroupMemberModel(
                  uid: uid,
                  name: memberName.trim(),
                  colorIndex: colorIndex,
                  role: 'member',
                  joinedAt: now,
                  lastReadAt: now,
                );
                final updatedMembers = [...localMembers, newMember];
                await _saveLocalMembers(gid, updatedMembers);
                _notifyMembersChanged(gid, updatedMembers);
              }

              await setActiveGroupId(gid);
              return gid;
            }
          }
        }
      } catch (e) {
        debugPrint('[GroupService] Firestore joinGroupByCode error: $e');
      }
    }

    // Fallback Mock/Testing/Local
    final mockGid = 'grp_mock_$code';
    final now = DateTime.now();
    final localFallback = GroupModel(
      id: mockGid,
      name: 'Grup $code',
      ownerUid: uid,
      code: code,
      createdAt: now,
      memberCount: 1,
    );
    await _saveLocalGroup(localFallback);

    final mockMember = GroupMemberModel(
      uid: uid,
      name: memberName.trim(),
      colorIndex: colorIndex,
      role: 'owner',
      joinedAt: now,
      lastReadAt: now,
    );
    await _saveLocalMembers(mockGid, [mockMember]);
    _notifyMembersChanged(mockGid, [mockMember]);

    final mockJoinEvt = GroupEventModel(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      type: GroupEventType.memberJoin,
      actorUid: uid,
      actorName: memberName.trim(),
      summary: '${memberName.trim()} bergabung ke grup',
      payload: {},
      createdAt: now,
    );
    await _saveLocalEvents(mockGid, [mockJoinEvt]);
    _notifyEventsChanged(mockGid, [mockJoinEvt]);

    await setActiveGroupId(mockGid);
    return mockGid;
  }

  /// Memantau dokumen grup realtime (Local-First + Stream + Polling)
  Stream<GroupModel?> watchGroup(String gid) async* {
    var local = _getLocalGroup(gid);
    if (local != null) {
      yield local;
    }

    if (supabase != null) {
      _ensureChannel(gid);
      final controller = StreamController<GroupModel?>.broadcast();
      _groupControllers.putIfAbsent(gid, () => []).add(controller);

      try {
        final row = await supabase!.from('groups').select('*').eq('id', gid).maybeSingle();
        if (row != null) {
          final group = GroupModel.fromMap(gid, row);
          final currentLocal = _getLocalGroup(gid);
          final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
          local = group.copyWith(wheelSlots: slots);
          await _saveLocalGroup(local);
          _notifyGroupChanged(gid, local);
          yield local;
        }
      } catch (_) {}

      final timer = Timer.periodic(const Duration(seconds: 4), (_) async {
        try {
          final row = await supabase!.from('groups').select('*').eq('id', gid).maybeSingle();
          if (row != null) {
            final group = GroupModel.fromMap(gid, row);
            final currentLocal = _getLocalGroup(gid);
            final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
            final merged = group.copyWith(wheelSlots: slots);
            await _saveLocalGroup(merged);
            _notifyGroupChanged(gid, merged);
          }
        } catch (_) {}
      });

      StreamSubscription? sub;
      try {
        sub = supabase!
            .from('groups')
            .stream(primaryKey: ['id'])
            .eq('id', gid)
            .listen((rows) {
              if (rows.isNotEmpty) {
                final group = GroupModel.fromMap(gid, rows.first);
                final currentLocal = _getLocalGroup(gid);
                final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
                final merged = group.copyWith(wheelSlots: slots);
                _saveLocalGroup(merged);
              }
            }, onError: (_) {});
      } catch (_) {}

      controller.onCancel = () {
        _groupControllers[gid]?.remove(controller);
        timer.cancel();
        sub?.cancel();
      };

      yield* controller.stream;
      return;
    }

    if (firestore != null) {
      try {
        await for (final doc in firestore!.collection('groups').doc(gid).snapshots()) {
          if (doc.exists && doc.data() != null) {
            final group = GroupModel.fromMap(doc.id, doc.data()!);
            final currentLocal = _getLocalGroup(gid);
            final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
            final merged = group.copyWith(wheelSlots: slots);
            await _saveLocalGroup(merged);
            yield merged;
          }
        }
        return;
      } catch (_) {
        if (local != null) yield local;
        return;
      }
    }

    if (local != null) {
      yield local;
    } else {
      yield null;
    }
  }

  List<GroupMemberModel> _cleanAndDeduplicate(String gid, List<GroupMemberModel> list) {
    final seenUids = <String>{};
    final seenMemberNames = <String>{};
    final uniqueList = <GroupMemberModel>[];
    for (final m in list) {
      final lowerName = m.name.toLowerCase().trim();
      if (m.uid.isNotEmpty && !seenUids.contains(m.uid)) {
        if (m.isOwner || !seenMemberNames.contains(lowerName)) {
          seenUids.add(m.uid);
          if (!m.isOwner) seenMemberNames.add(lowerName);
          uniqueList.add(m);
        }
      }
    }

    final group = _getLocalGroup(gid);
    if (group != null && authService.isCurrentUser(group.ownerUid)) {
      if (!uniqueList.any((m) => authService.isCurrentUser(m.uid))) {
        final local = _getLocalMembers(gid);
        final ownerMember = local.firstWhere(
          (m) => authService.isCurrentUser(m.uid),
          orElse: () => GroupMemberModel(
            uid: group.ownerUid,
            name: authService.displayName ?? 'Pemilik',
            colorIndex: authService.colorIndex,
            role: 'owner',
            joinedAt: group.createdAt,
            lastReadAt: DateTime.now(),
          ),
        );
        return [ownerMember, ...uniqueList];
      }
    }
    return uniqueList;
  }

  /// Memantau daftar anggota realtime (Local-First + Stream + Polling)
  Stream<List<GroupMemberModel>> watchMembers(String gid) async* {
    var local = _getLocalMembers(gid);
    local = _cleanAndDeduplicate(gid, local);
    if (local.isNotEmpty) {
      yield local;
    }

    if (supabase != null) {
      final controller = StreamController<List<GroupMemberModel>>.broadcast();
      _membersControllers.putIfAbsent(gid, () => []).add(controller);

      // 1. Dengarkan WebSocket Broadcast Realtime (< 50ms)
      void broadcastCb(Map<String, dynamic> payload) {
        final type = payload['type']?.toString();
        if (type == GroupEventType.memberJoin.value ||
            type == GroupEventType.memberLeave.value) {
          final cur = _getLocalMembers(gid);
          final clean = _cleanAndDeduplicate(gid, cur);
          if (!controller.isClosed) controller.add(clean);
          _notifyMembersChanged(gid, clean);
        }
      }
      _ensureChannel(gid, onBroadcastEvent: broadcastCb);

      // 2. Initial query from Supabase
      try {
        final rows = await supabase!.from('group_members').select('*').eq('gid', gid).order('joined_at', ascending: true);
        final members = (rows as List).map((r) => GroupMemberModel.fromMap((r['uid'] ?? '').toString(), r)).toList();
        final clean = _cleanAndDeduplicate(gid, members);
        await _saveLocalMembers(gid, clean);
        _notifyMembersChanged(gid, clean);
        yield clean;
      } catch (_) {}

      // 3. Fallback Periodic Polling (setiap 3 detik untuk latensi rendah)
      final timer = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final rows = await supabase!.from('group_members').select('*').eq('gid', gid).order('joined_at', ascending: true);
          final members = (rows as List).map((r) => GroupMemberModel.fromMap((r['uid'] ?? '').toString(), r)).toList();
          final clean = _cleanAndDeduplicate(gid, members);
          await _saveLocalMembers(gid, clean);
          _notifyMembersChanged(gid, clean);
        } catch (_) {}
      });

      // 4. Postgres stream
      StreamSubscription? sub;
      try {
        sub = supabase!
            .from('group_members')
            .stream(primaryKey: ['id'])
            .eq('gid', gid)
            .order('joined_at', ascending: true)
            .listen((rows) {
              final members = rows.map((r) => GroupMemberModel.fromMap(r['uid']?.toString() ?? '', r)).toList();
              final clean = _cleanAndDeduplicate(gid, members);
              _saveLocalMembers(gid, clean);
              _notifyMembersChanged(gid, clean);
            }, onError: (_) {});
      } catch (_) {}

      controller.onCancel = () {
        _membersControllers[gid]?.remove(controller);
        _onBroadcastCallbacks.remove(broadcastCb);
        timer.cancel();
        sub?.cancel();
      };

      yield* controller.stream;
      return;
    }

    if (firestore != null) {
      try {
        await for (final snapshot in firestore!
            .collection('groups')
            .doc(gid)
            .collection('members')
            .orderBy('joinedAt', descending: false)
            .snapshots()) {
          final members = snapshot.docs
              .map((doc) => GroupMemberModel.fromMap(doc.id, doc.data()))
              .toList();
          await _saveLocalMembers(gid, members);
          yield members;
        }
        return;
      } catch (_) {
        if (local.isNotEmpty) yield local;
        return;
      }
    }

    yield local;
  }

  /// Memperbarui daftar pilihan nominal roda grup (Khusus Pemilik Grup)
  Future<void> updateGroupSlots(String gid, List<int> slots) async {
    if (slots.length < 2 || slots.length > 12) {
      throw ArgumentError('Nominal roda harus berjumlah antara 2 hingga 12');
    }

    final local = _getLocalGroup(gid);
    if (local != null) {
      final updated = local.copyWith(wheelSlots: slots);
      await _saveLocalGroup(updated);
    }
    await _saveStoredGroupSlots(gid, slots);

    final now = DateTime.now();
    final uid = authService.currentUid ?? '';
    final actorName = authService.displayName ?? 'Pemilik Grup';

    final evtId = 'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final localEvt = GroupEventModel(
      eventId: evtId,
      type: GroupEventType.custom,
      actorUid: uid,
      actorName: actorName,
      summary: '$actorName memperbarui nominal roda (${slots.length} pilihan)',
      payload: {
        'action': 'update_slots',
        'wheelSlots': slots,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final eventMap = {
        'id': evtId,
        'gid': gid,
        'actor_uid': uid,
        'actor_name': actorName,
        'type': GroupEventType.custom.value,
        'summary': '$actorName memperbarui nominal roda (${slots.length} pilihan)',
        'payload': {
          'action': 'update_slots',
          'wheelSlots': slots,
        },
        'created_at': now.toIso8601String(),
      };

      // 1. Broadcast langsung via WebSocket (< 5ms) ke semua spectator / anggota online
      _broadcastGroupEvent(gid, eventMap);

      // 2. Simpan ke group_events terlebih dahulu agar riwayat & sinkronisasi anggota tersimpan
      try {
        await supabase!.from('group_events').insert(eventMap);
      } catch (e) {
        debugPrint('[GroupService] Supabase insert group_events error: $e');
      }

      // 3. Update kolom wheel_slots pada tabel groups jika kolom sudah dimigrasi
      try {
        await supabase!.from('groups').update({
          'wheel_slots': slots,
        }).eq('id', gid);
      } catch (e) {
        debugPrint('[GroupService] Supabase updateGroupSlots column error: $e');
      }
      return;
    }

    if (firestore != null) {
      try {
        await firestore!.collection('groups').doc(gid).update({
          'wheelSlots': slots,
        });

        final eventMap = {
          'eventId': evtId,
          'gid': gid,
          'actorUid': uid,
          'actorName': actorName,
          'type': GroupEventType.custom.value,
          'summary': '$actorName memperbarui nominal roda (${slots.length} pilihan)',
          'payload': {
            'action': 'update_slots',
            'wheelSlots': slots,
          },
          'createdAt': now.millisecondsSinceEpoch,
        };

        await firestore!.collection('groups').doc(gid).collection('events').doc(evtId).set(eventMap);
      } catch (e) {
        debugPrint('[GroupService] Firestore updateGroupSlots error: $e');
      }
    }
  }

  /// Memperbarui pengaturan budget & permainan grup (Khusus Pemilik Grup, Layar 53 & 54)
  Future<void> updateGroupBudgetSettings({
    required String gid,
    required String budgetMode,
    required int fixedBudget,
    required String spinPolicy,
    List<int>? wheelSlots,
  }) async {
    final local = _getLocalGroup(gid);
    if (local != null) {
      final updated = local.copyWith(
        budgetMode: budgetMode,
        fixedBudget: fixedBudget,
        spinPolicy: spinPolicy,
        wheelSlots: wheelSlots ?? local.wheelSlots,
      );
      await _saveLocalGroup(updated);
      _notifyGroupChanged(gid, updated);
    }

    if (wheelSlots != null && wheelSlots.length >= 2 && wheelSlots.length <= 12) {
      await _saveStoredGroupSlots(gid, wheelSlots);
    }

    final now = DateTime.now();
    final uid = authService.currentUid ?? '';
    final actorName = authService.displayName ?? 'Pemilik Grup';

    final evtId = 'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final summaryText = budgetMode == 'fixed'
        ? '$actorName mengubah budget grup: Angka Tetap ${RupiahFormatter.format(fixedBudget)}'
        : '$actorName mengubah mode budget: Dari Permainan (Roda)';

    final localEvt = GroupEventModel(
      eventId: evtId,
      type: GroupEventType.budgetChanged,
      actorUid: uid,
      actorName: actorName,
      summary: summaryText,
      payload: {
        'action': 'update_budget_settings',
        'budgetMode': budgetMode,
        'fixedBudget': fixedBudget,
        'spinPolicy': spinPolicy,
        'wheelSlots': ?wheelSlots,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final eventMap = {
        'id': evtId,
        'gid': gid,
        'actor_uid': uid,
        'actor_name': actorName,
        'type': GroupEventType.budgetChanged.value,
        'summary': summaryText,
        'payload': {
          'action': 'update_budget_settings',
          'budgetMode': budgetMode,
          'fixedBudget': fixedBudget,
          'spinPolicy': spinPolicy,
          'wheelSlots': ?wheelSlots,
        },
        'created_at': now.toIso8601String(),
      };

      // 1. Broadcast langsung via WebSocket (< 5ms) ke semua anggota
      _broadcastGroupEvent(gid, eventMap);

      // 2. Simpan ke group_events
      try {
        await supabase!.from('group_events').insert(eventMap);
      } catch (e) {
        debugPrint('[GroupService] insert group_events error: $e');
      }

      // 3. Update tabel groups
      try {
        final updateMap = <String, dynamic>{
          'budget_mode': budgetMode,
          'fixed_budget': fixedBudget,
          'spin_policy': spinPolicy,
          'wheel_slots': ?wheelSlots,
        };
        await supabase!.from('groups').update(updateMap).eq('id', gid);
      } catch (e) {
        debugPrint('[GroupService] Supabase updateGroupBudgetSettings columns error: $e');
        if (wheelSlots != null) {
          try {
            await supabase!.from('groups').update({'wheel_slots': wheelSlots}).eq('id', gid);
          } catch (_) {}
        }
      }
      return;
    }

    if (firestore != null) {
      try {
        final updateMap = <String, dynamic>{
          'budgetMode': budgetMode,
          'fixedBudget': fixedBudget,
          'spinPolicy': spinPolicy,
          'wheelSlots': ?wheelSlots,
        };
        await firestore!.collection('groups').doc(gid).update(updateMap);

        final eventMap = {
          'eventId': evtId,
          'gid': gid,
          'actorUid': uid,
          'actorName': actorName,
          'type': GroupEventType.budgetChanged.value,
          'summary': summaryText,
          'payload': {
            'action': 'update_budget_settings',
            'budgetMode': budgetMode,
            'fixedBudget': fixedBudget,
            'spinPolicy': spinPolicy,
            'wheelSlots': ?wheelSlots,
          },
          'createdAt': now.millisecondsSinceEpoch,
        };

        await firestore!.collection('groups').doc(gid).collection('events').doc(evtId).set(eventMap);
      } catch (e) {
        debugPrint('[GroupService] Firestore updateGroupBudgetSettings error: $e');
      }
    }
  }

  /// Memulai sesi date baru dengan budget tetap (Mode Angka Tetap, Layar 18)
  Future<void> startFixedSession({
    required String gid,
    required int fixedBudget,
  }) async {
    final now = DateTime.now();
    final uid = authService.currentUid ?? '';
    final actorName = authService.displayName ?? 'Anggota';
    final sessionId = 'sess_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';

    final session = GroupSessionModel(
      sessionId: sessionId,
      budget: fixedBudget,
      startedByUid: uid,
      startedByName: actorName,
      startedAt: now,
    );

    final local = _getLocalGroup(gid);
    if (local != null) {
      final updated = local.copyWith(activeSession: session);
      await _saveLocalGroup(updated);
      _notifyGroupChanged(gid, updated);
    }

    final evtId = 'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';
    final summaryText = '$actorName memulai date dengan budget ${RupiahFormatter.format(fixedBudget)}';

    final localEvt = GroupEventModel(
      eventId: evtId,
      type: GroupEventType.sessionStart,
      actorUid: uid,
      actorName: actorName,
      summary: summaryText,
      payload: {
        'sessionId': sessionId,
        'budget': fixedBudget,
        'startedByUid': uid,
        'startedByName': actorName,
        'type': 'fixed',
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    final eventMap = {
      'id': evtId,
      'gid': gid,
      'actor_uid': uid,
      'actor_name': actorName,
      'type': GroupEventType.sessionStart.value,
      'summary': summaryText,
      'payload': {
        'sessionId': sessionId,
        'budget': fixedBudget,
        'startedByUid': uid,
        'startedByName': actorName,
        'type': 'fixed',
      },
      'created_at': now.toIso8601String(),
    };

    _broadcastGroupEvent(gid, eventMap);

    if (supabase != null) {
      try {
        await Future.wait([
          supabase!.from('groups').update({
            'active_session': session.toMap(),
          }).eq('id', gid),
          supabase!.from('group_events').insert(eventMap),
        ]);
      } catch (e) {
        debugPrint('[GroupService] Supabase startFixedSession error: $e');
      }
      return;
    }

    if (firestore != null) {
      try {
        final batch = firestore!.batch();
        batch.update(firestore!.collection('groups').doc(gid), {
          'activeSession': session.toMap(),
        });
        batch.set(firestore!.collection('groups').doc(gid).collection('events').doc(evtId), {
          'eventId': evtId,
          'gid': gid,
          'actorUid': uid,
          'actorName': actorName,
          'type': GroupEventType.sessionStart.value,
          'summary': summaryText,
          'payload': {
            'sessionId': sessionId,
            'budget': fixedBudget,
            'startedByUid': uid,
            'startedByName': actorName,
            'type': 'fixed',
          },
          'createdAt': now.millisecondsSinceEpoch,
        });
        await batch.commit();
      } catch (_) {}
    }
  }

  /// Mengambil dokumen grup dari Supabase / Firestore / cache lokal
  Future<GroupModel?> fetchGroup(String gid) async {
    if (supabase != null) {
      try {
        final row = await supabase!.from('groups').select('*').eq('id', gid).maybeSingle();
        if (row != null) {
          final group = GroupModel.fromMap(gid, row);
          await _saveLocalGroup(group);
          _notifyGroupChanged(gid, group);
          return group;
        }
      } catch (e) {
        debugPrint('[GroupService] fetchGroup Supabase error: $e');
      }
    }
    if (firestore != null) {
      try {
        final doc = await firestore!.collection('groups').doc(gid).get();
        if (doc.exists && doc.data() != null) {
          final group = GroupModel.fromMap(gid, doc.data()!);
          await _saveLocalGroup(group);
          _notifyGroupChanged(gid, group);
          return group;
        }
      } catch (e) {
        debugPrint('[GroupService] fetchGroup Firestore error: $e');
      }
    }
    return _getLocalGroup(gid);
  }

  /// Menyimpan sesi permainan dan mencatat event secara atomic (batch)
  Future<void> saveSessionAndEvent({
    required String gid,
    required GroupSessionModel session,
    required GroupEventModel event,
  }) async {
    final local = _getLocalGroup(gid);
    if (local != null) {
      final updatedGroup = local.copyWith(activeSession: session);
      await _saveLocalGroup(updatedGroup);
      _notifyGroupChanged(gid, updatedGroup);
    }

    final evts = _getLocalEvents(gid);
    evts.insert(0, event);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final eventMap = {
        'id': event.eventId,
        'gid': gid,
        'actor_uid': event.actorUid,
        'actor_name': event.actorName,
        'type': event.type.value,
        'summary': event.summary,
        'payload': event.payload,
        'created_at': event.createdAt.toIso8601String(),
      };
      _broadcastGroupEvent(gid, eventMap);

      try {
        await Future.wait([
          supabase!.from('groups').update({
            'active_session': session.toMap(),
          }).eq('id', gid),
          supabase!.from('group_events').insert(eventMap),
        ]);
      } catch (e) {
        debugPrint('[GroupService] saveSessionAndEvent Supabase error: $e');
      }
      return;
    }

    if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final eventRef = groupRef.collection('events').doc(event.eventId);
        final batch = firestore!.batch();

        batch.update(groupRef, {
          'activeSession': session.toMap(),
        });
        batch.set(eventRef, event.toMap());
        await batch.commit();
      } catch (e) {
        debugPrint('[GroupService] saveSessionAndEvent Firestore error: $e');
      }
    }
  }

  /// Memperbarui activeSession grup (misal untuk kunci giliran koin / unlock)
  Future<void> saveSessionOnly({
    required String gid,
    required GroupSessionModel session,
  }) async {
    final local = _getLocalGroup(gid);
    if (local != null) {
      final updatedGroup = local.copyWith(activeSession: session);
      await _saveLocalGroup(updatedGroup);
      _notifyGroupChanged(gid, updatedGroup);
    }

    if (supabase != null) {
      try {
        await supabase!.from('groups').update({
          'active_session': session.toMap(),
        }).eq('id', gid);
      } catch (e) {
        debugPrint('[GroupService] saveSessionOnly Supabase error: $e');
      }
    }

    if (firestore != null) {
      try {
        await firestore!.collection('groups').doc(gid).update({
          'activeSession': session.toMap(),
        });
      } catch (e) {
        debugPrint('[GroupService] saveSessionOnly Firestore error: $e');
      }
    }
  }

  /// Mengakhiri / menutup sesi grup aktif (membuka kembali kunci date grup)
  Future<void> endSession({required String gid}) async {
    final local = _getLocalGroup(gid);
    if (local != null) {
      final updatedGroup = local.copyWith(clearActiveSession: true);
      await _saveLocalGroup(updatedGroup);
      _notifyGroupChanged(gid, updatedGroup);
    }

    if (supabase != null) {
      try {
        await supabase!.from('groups').update({
          'active_session': null,
        }).eq('id', gid);
      } catch (e) {
        debugPrint('[GroupService] endSession Supabase error: $e');
      }
    }

    if (firestore != null) {
      try {
        await firestore!.collection('groups').doc(gid).update({
          'activeSession': null,
        });
      } catch (e) {
        debugPrint('[GroupService] endSession Firestore error: $e');
      }
    }
  }

  /// Mencatat event tanpa mengubah activeSession (misal event race condition invalid)
  Future<void> recordEventOnly(String gid, GroupEventModel event) async {
    final evts = _getLocalEvents(gid);
    evts.insert(0, event);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final eventMap = {
        'id': event.eventId,
        'gid': gid,
        'actor_uid': event.actorUid,
        'actor_name': event.actorName,
        'type': event.type.value,
        'summary': event.summary,
        'payload': event.payload,
        'created_at': event.createdAt.toIso8601String(),
      };
      _broadcastGroupEvent(gid, eventMap);
      try {
        await supabase!.from('group_events').insert(eventMap);
      } catch (e) {
        debugPrint('[GroupService] recordEventOnly Supabase error: $e');
      }
      return;
    }

    if (firestore != null) {
      try {
        await firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .doc(event.eventId)
            .set(event.toMap());
      } catch (e) {
        debugPrint('[GroupService] recordEventOnly Firestore error: $e');
      }
    }
  }

  /// Memperbarui kode undangan (Khusus Pemilik Grup)
  Future<String> regenerateInviteCode(String gid) async {
    final newCode = InviteCodeGenerator.generate();
    final now = DateTime.now();
    final uid = authService.currentUid ?? '';
    final actorName = authService.displayName ?? 'Pemilik';

    final local = _getLocalGroup(gid);
    if (local != null) {
      final updated = local.copyWith(code: newCode);
      await _saveLocalGroup(updated);
      _notifyGroupChanged(gid, updated);
    }

    final codeEvtMap = {
      'id': 'evt_${now.millisecondsSinceEpoch}',
      'gid': gid,
      'actor_uid': uid,
      'actor_name': actorName,
      'type': GroupEventType.codeChanged.value,
      'summary': '$actorName memperbarui kode undangan grup',
      'payload': {
        'code': newCode,
      },
      'created_at': now.toIso8601String(),
    };
    _broadcastGroupEvent(gid, codeEvtMap);

    if (supabase != null) {
      try {
        final groupRes = await supabase!.from('groups').select('code').eq('id', gid).maybeSingle();
        final oldCode = groupRes?['code'] as String?;
        if (oldCode != null && oldCode.isNotEmpty) {
          await supabase!.from('invite_codes').delete().eq('code', oldCode);
        }
        await supabase!.from('invite_codes').insert({'code': newCode, 'gid': gid});
        await supabase!.from('groups').update({'code': newCode}).eq('id', gid);
        await supabase!.from('group_events').insert(codeEvtMap);
      } catch (e) {
        debugPrint('[GroupService] Supabase regenerateInviteCode error: $e');
      }
      return newCode;
    }

    if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final groupDoc = await groupRef.get();
        if (groupDoc.exists) {
          final oldCode = groupDoc.data()?['code'] as String?;
          final now = DateTime.now();

          final batch = firestore!.batch();
          if (oldCode != null && oldCode.isNotEmpty) {
            batch.delete(firestore!.collection('inviteCodes').doc(oldCode));
          }
          batch.set(firestore!.collection('inviteCodes').doc(newCode), {
            'gid': gid,
            'createdAt': now.millisecondsSinceEpoch,
          });
          batch.update(groupRef, {'code': newCode});
          await batch.commit();
        }
      } catch (_) {}
    }

    return newCode;
  }

  /// Mengeluarkan anggota (Khusus Pemilik Grup)
  Future<void> removeMember({
    required String gid,
    required String memberUid,
    required String memberName,
  }) async {
    final now = DateTime.now();

    final members = _getLocalMembers(gid)..removeWhere((m) => m.uid == memberUid);
    await _saveLocalMembers(gid, members);

    final localGroup = _getLocalGroup(gid);
    if (localGroup != null) {
      final newCount = (localGroup.memberCount - 1).clamp(0, 10);
      await _saveLocalGroup(localGroup.copyWith(memberCount: newCount));
    }

    final localEvt = GroupEventModel(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      type: GroupEventType.memberLeave,
      actorUid: authService.currentUid ?? '',
      actorName: authService.displayName ?? 'Pemilik',
      summary: '$memberName telah dikeluarkan dari grup',
      payload: {
        'kicked': true,
        'kickedUid': memberUid,
        'kickedName': memberName,
      },
      createdAt: now,
    );
    final events = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, events);

    _notifyMembersChanged(gid, members);
    _notifyEventsChanged(gid, events);

    if (supabase != null) {
      try {
        await supabase!.from('group_members').delete().eq('gid', gid).eq('uid', memberUid);
        if (memberName.trim().isNotEmpty) {
          try {
            await supabase!.from('group_members').delete().eq('gid', gid).ilike('name', memberName.trim());
          } catch (_) {}
        }
        final gRes = await supabase!.from('groups').select('member_count').eq('id', gid).maybeSingle();
        final count = (gRes?['member_count'] as num?)?.toInt() ?? 1;
        await supabase!.from('groups').update({'member_count': count > 1 ? count - 1 : 1}).eq('id', gid);

        final removeEvtMap = {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'gid': gid,
          'actor_uid': authService.currentUid ?? '',
          'actor_name': authService.displayName ?? 'Pemilik',
          'type': GroupEventType.memberLeave.value,
          'summary': '$memberName telah dikeluarkan dari grup',
          'payload': {
            'kicked': true,
            'kickedUid': memberUid,
            'kickedName': memberName,
          },
          'created_at': now.toIso8601String(),
        };
        await supabase!.from('group_events').insert(removeEvtMap);
        await _broadcastGroupEvent(gid, removeEvtMap);
      } catch (_) {}
    } else if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final batch = firestore!.batch();

        batch.delete(groupRef.collection('members').doc(memberUid));
        batch.update(groupRef, {'memberCount': 0});

        final eventRef = groupRef.collection('events').doc('evt_${now.millisecondsSinceEpoch}');
        batch.set(eventRef, {
          'actorUid': authService.currentUid ?? '',
          'actorName': authService.displayName ?? 'Pemilik',
          'type': GroupEventType.memberLeave.name,
          'summary': '$memberName telah dikeluarkan dari grup',
          'payload': {
            'kicked': true,
            'kickedUid': memberUid,
            'kickedName': memberName,
          },
          'timestamp': now.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (_) {}
    }

    if (getActiveGroupId() == gid && authService.isCurrentUser(memberUid)) {
      await setActiveGroupId(null);
    }
  }

  /// Perbarui nama tampilan anggota di grup yang sedang aktif
  Future<void> updateMyMemberName(String newName) async {
    final myUid = authService.currentUid;
    final gid = getActiveGroupId();
    if (myUid == null || gid == null) return;

    final members = _getLocalMembers(gid);
    final idx = members.indexWhere((m) => m.uid == myUid);
    if (idx != -1) {
      members[idx] = members[idx].copyWith(name: newName);
      await _saveLocalMembers(gid, members);
      _notifyMembersChanged(gid, members);
    }

    if (supabase != null) {
      try {
        await supabase!
            .from('group_members')
            .update({'name': newName})
            .eq('gid', gid)
            .eq('uid', myUid);
      } catch (_) {}
    }

    if (firestore != null) {
      try {
        await firestore!
            .collection('groups')
            .doc(gid)
            .collection('members')
            .doc(myUid)
            .update({'name': newName});
      } catch (_) {}
    }
  }

  /// Anggota keluar dari grup secara sukarela
  Future<void> leaveGroup(String gid) async {
    final myUid = authService.currentUid;
    if (myUid == null) return;
    final now = DateTime.now();
    final myName = authService.displayName ?? 'Anggota';

    final members = _getLocalMembers(gid)..removeWhere((m) => m.uid == myUid);
    await _saveLocalMembers(gid, members);

    final localGroup = _getLocalGroup(gid);
    if (localGroup != null) {
      final newCount = (localGroup.memberCount - 1).clamp(0, 10);
      await _saveLocalGroup(localGroup.copyWith(memberCount: newCount));
    }

    final localLeaveEvt = GroupEventModel(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      type: GroupEventType.memberLeave,
      actorUid: myUid,
      actorName: myName,
      summary: '$myName keluar dari grup',
      payload: {
        'kicked': false,
        'leaverUid': myUid,
        'leaverName': myName,
      },
      createdAt: now,
    );
    final currentEvts = _getLocalEvents(gid)..insert(0, localLeaveEvt);
    await _saveLocalEvents(gid, currentEvts);

    _notifyMembersChanged(gid, members);
    _notifyEventsChanged(gid, currentEvts);

    if (supabase != null) {
      try {
        await supabase!.from('group_members').delete().eq('gid', gid).eq('uid', myUid);
        if (myName.trim().isNotEmpty) {
          try {
            await supabase!.from('group_members').delete().eq('gid', gid).ilike('name', myName.trim());
          } catch (_) {}
        }
        final gRes = await supabase!.from('groups').select('member_count').eq('id', gid).maybeSingle();
        final count = (gRes?['member_count'] as num?)?.toInt() ?? 1;
        await supabase!.from('groups').update({'member_count': count > 1 ? count - 1 : 1}).eq('id', gid);

        final leaveEvtMap = {
          'id': localLeaveEvt.eventId,
          'gid': gid,
          'actor_uid': myUid,
          'actor_name': myName,
          'type': GroupEventType.memberLeave.value,
          'summary': '$myName keluar dari grup',
          'payload': {
            'kicked': false,
            'leaverUid': myUid,
            'leaverName': myName,
          },
          'created_at': now.toIso8601String(),
        };
        await supabase!.from('group_events').insert(leaveEvtMap);
        await _broadcastGroupEvent(gid, leaveEvtMap);
      } catch (_) {}
    } else if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final batch = firestore!.batch();

        batch.delete(groupRef.collection('members').doc(myUid));
        batch.update(groupRef, {'memberCount': 0});

        final eventRef = groupRef.collection('events').doc(localLeaveEvt.eventId);
        batch.set(eventRef, {
          'actorUid': myUid,
          'actorName': myName,
          'type': GroupEventType.memberLeave.name,
          'summary': '$myName keluar dari grup',
          'payload': {
            'kicked': false,
            'leaverUid': myUid,
            'leaverName': myName,
          },
          'timestamp': now.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (_) {}
    }

    if (getActiveGroupId() == gid) {
      await setActiveGroupId(null);
    }
  }

  /// Menambah catatan pengeluaran grup (Append-only)
  Future<String> addNote({
    required String gid,
    required String sessionId,
    required String title,
    required int amount,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Nama barang tidak boleh kosong.');
    }
    if (amount <= 0) {
      throw ArgumentError('Nominal harus lebih dari 0.');
    }

    final uid = await authService.ensureSignedIn();
    final authorName = authService.displayName ?? 'Anggota';
    final noteId = 'note_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final now = DateTime.now();

    final localNote = GroupNoteModel(
      noteId: noteId,
      sessionId: sessionId,
      authorUid: uid,
      authorName: authorName,
      title: cleanTitle,
      amount: amount,
      createdAt: now,
      deleted: false,
    );

    final notes = _getLocalNotes(gid)..insert(0, localNote);
    await _saveLocalNotes(gid, notes);

    final group = _getLocalGroup(gid);
    final totalBudget = group?.activeSession?.budget ?? 0;
    final currentNotes = _getLocalNotes(gid).where((n) => n.sessionId == sessionId && !n.deleted).toList();
    final currentSpent = currentNotes.fold<int>(0, (total, n) => total + n.amount);
    final remaining = (totalBudget - currentSpent).clamp(0, totalBudget);

    final localEvt = GroupEventModel(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      type: GroupEventType.expense,
      actorUid: uid,
      actorName: authorName,
      summary: '$authorName mencatat "$cleanTitle" (${RupiahFormatter.format(amount)})',
      payload: {
        'title': cleanTitle,
        'amount': amount,
        'remaining': remaining,
        'sessionId': sessionId,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);

    _notifyNotesChanged(gid, notes);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      try {
        await supabase!.from('group_notes').insert({
          'id': noteId,
          'gid': gid,
          'session_id': sessionId,
          'author_uid': uid,
          'author_name': authorName,
          'title': cleanTitle,
          'amount': amount,
          'created_at': now.toIso8601String(),
          'deleted': false,
        });

        final evtMap = {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'gid': gid,
          'actor_uid': uid,
          'actor_name': authorName,
          'type': GroupEventType.expense.value,
          'summary': '$authorName mencatat "$cleanTitle" (${RupiahFormatter.format(amount)})',
          'payload': {
            'noteId': noteId,
            'title': cleanTitle,
            'amount': amount,
            'remaining': remaining,
            'sessionId': sessionId,
          },
          'created_at': now.toIso8601String(),
        };

        await supabase!.from('group_events').insert(evtMap);
        _broadcastGroupEvent(gid, evtMap);
      } catch (e) {
        debugPrint('[GroupService] Supabase addNote error: $e');
      }

      return noteId;
    }

    if (firestore != null) {
      try {
        final batch = firestore!.batch();

        final noteRef = firestore!
            .collection('groups')
            .doc(gid)
            .collection('notes')
            .doc(noteId);

        batch.set(noteRef, {
          'sessionId': sessionId,
          'authorUid': uid,
          'authorName': authorName,
          'title': cleanTitle,
          'amount': amount,
          'createdAt': now.millisecondsSinceEpoch,
          'deleted': false,
        });

        final eventRef = firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .doc('evt_${now.millisecondsSinceEpoch}');

        batch.set(eventRef, {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'actorUid': uid,
          'actorName': authorName,
          'type': GroupEventType.expense.value,
          'summary': '$authorName mencatat "$cleanTitle" (${RupiahFormatter.format(amount)})',
          'payload': {
            'title': cleanTitle,
            'amount': amount,
            'remaining': remaining,
            'sessionId': sessionId,
          },
          'timestamp': now.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (_) {}
    }

    return noteId;
  }

  /// Memantau catatan pengeluaran grup secara realtime (Local-First + Stream + Polling)
  Stream<List<GroupNoteModel>> watchNotes(String gid, String sessionId) async* {
    final local = _getLocalNotes(gid).where((n) => n.sessionId == sessionId).toList();
    if (local.isNotEmpty) {
      yield local;
    }

    if (supabase != null) {
      final controller = StreamController<List<GroupNoteModel>>.broadcast();
      _notesControllers.putIfAbsent(gid, () => []).add(controller);

      try {
        final rows = await supabase!
            .from('group_notes')
            .select('*')
            .eq('gid', gid)
            .order('created_at', ascending: false);
        final notes = (rows as List)
            .where((r) => r['session_id'] == sessionId)
            .map((r) => GroupNoteModel.fromMap(r['id']?.toString() ?? '', r))
            .toList();
        await _saveLocalNotes(gid, notes);
        yield notes;
      } catch (_) {}

      final timer = Timer.periodic(const Duration(seconds: 15), (_) async {
        try {
          final rows = await supabase!
              .from('group_notes')
              .select('*')
              .eq('gid', gid)
              .order('created_at', ascending: false);
          final notes = (rows as List)
              .where((r) => r['session_id'] == sessionId)
              .map((r) => GroupNoteModel.fromMap(r['id']?.toString() ?? '', r))
              .toList();
          await _saveLocalNotes(gid, notes);
        } catch (_) {}
      });

      StreamSubscription? sub;
      try {
        sub = supabase!
            .from('group_notes')
            .stream(primaryKey: ['id'])
            .eq('gid', gid)
            .order('created_at', ascending: false)
            .listen((rows) {
              final notes = rows
                  .where((r) => r['session_id'] == sessionId)
                  .map((r) => GroupNoteModel.fromMap(r['id']?.toString() ?? '', r))
                  .toList();
              _saveLocalNotes(gid, notes);
            }, onError: (_) {});
      } catch (_) {}

      controller.onCancel = () {
        _notesControllers[gid]?.remove(controller);
        timer.cancel();
        sub?.cancel();
      };

      yield* controller.stream;
      return;
    }

    if (firestore != null) {
      try {
        await for (final snapshot in firestore!
            .collection('groups')
            .doc(gid)
            .collection('notes')
            .where('sessionId', isEqualTo: sessionId)
            .snapshots(includeMetadataChanges: true)) {
          final notes = snapshot.docs.map((doc) {
            return GroupNoteModel.fromMap(
              doc.id,
              doc.data(),
              hasPendingWrites: doc.metadata.hasPendingWrites,
            );
          }).toList();

          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          await _saveLocalNotes(gid, notes);
          yield notes;
        }
        return;
      } catch (_) {
        if (local.isNotEmpty) yield local;
        return;
      }
    }

    yield local;
  }

  /// Menghapus catatan pengeluaran menggunakan Tombstone (deleted = true)
  Future<void> deleteNote({
    required String gid,
    required String noteId,
    required String title,
    required int amount,
  }) async {
    final myUid = authService.currentUid ?? '';
    final myName = authService.displayName ?? 'Anggota';
    final now = DateTime.now();

    final notes = _getLocalNotes(gid);
    final idx = notes.indexWhere((n) => n.noteId == noteId);
    if (idx != -1) {
      notes[idx] = notes[idx].copyWith(deleted: true);
      await _saveLocalNotes(gid, notes);
    }

    final group = _getLocalGroup(gid);
    final totalBudget = group?.activeSession?.budget ?? 0;
    final remainingNotes = notes.where((n) => !n.deleted).toList();
    final currentSpent = remainingNotes.fold<int>(0, (total, n) => total + n.amount);
    final remaining = (totalBudget - currentSpent).clamp(0, totalBudget);

    final localEvt = GroupEventModel(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      type: GroupEventType.expense,
      actorUid: myUid,
      actorName: myName,
      summary: '$myName menghapus pengeluaran "$title" (${RupiahFormatter.format(amount)})',
      payload: {
        'title': title,
        'amount': amount,
        'remaining': remaining,
        'deleted': true,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);

    _notifyNotesChanged(gid, notes);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      try {
        await supabase!.from('group_notes').update({'deleted': true}).eq('id', noteId);

        final evtMap = {
          'id': 'evt_${now.millisecondsSinceEpoch}',
          'gid': gid,
          'actor_uid': myUid,
          'actor_name': myName,
          'type': GroupEventType.expense.value,
          'summary': '$myName menghapus pengeluaran "$title" (${RupiahFormatter.format(amount)})',
          'payload': {
            'noteId': noteId,
            'title': title,
            'amount': amount,
            'remaining': remaining,
            'deleted': true,
          },
          'created_at': now.toIso8601String(),
        };

        await supabase!.from('group_events').insert(evtMap);
        _broadcastGroupEvent(gid, evtMap);
      } catch (_) {}
      return;
    }

    if (firestore != null) {
      try {
        final noteRef = firestore!
            .collection('groups')
            .doc(gid)
            .collection('notes')
            .doc(noteId);

        final batch = firestore!.batch();
        batch.update(noteRef, {'deleted': true});

        final eventRef = firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .doc('evt_${now.millisecondsSinceEpoch}');

        batch.set(eventRef, {
          'actorUid': myUid,
          'actorName': myName,
          'type': GroupEventType.expense.name,
          'summary': '$myName menghapus pengeluaran "$title" (${RupiahFormatter.format(amount)})',
          'timestamp': now.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (_) {}
    }
  }

  /// Mencatat putaran roda grup bersama (update activeSession & tambah event spin)
  Future<void> recordSpin({
    required String gid,
    required int budget,
    String? sessionId,
    String? eventId,
  }) async {
    final uid = await authService.ensureSignedIn();
    final actorName = authService.displayName ?? 'Anggota';
    final now = DateTime.now();
    final effectiveSessionId = sessionId ?? 'sess_${now.millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final spinEvtId = eventId ?? 'evt_${now.millisecondsSinceEpoch}_${Random().nextInt(999)}';

    // Tandai sesi ini agar tidak terjadi notifikasi ganda/delay
    markSpinAsShown(effectiveSessionId);

    final session = GroupSessionModel(
      sessionId: effectiveSessionId,
      budget: budget,
      startedByUid: uid,
      startedByName: actorName,
      startedAt: now,
    );

    final local = _getLocalGroup(gid);
    if (local != null) {
      await _saveLocalGroup(local.copyWith(activeSession: session));
    }

    final localSpinEvt = GroupEventModel(
      eventId: spinEvtId,
      type: GroupEventType.spin,
      actorUid: uid,
      actorName: actorName,
      summary: '$actorName memutar roda: ${RupiahFormatter.format(budget)}',
      payload: {
        'budget': budget,
        'sessionId': effectiveSessionId,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localSpinEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      try {
        final eventMap = {
          'id': spinEvtId,
          'gid': gid,
          'actor_uid': uid,
          'actor_name': actorName,
          'type': GroupEventType.spin.value,
          'summary': '$actorName memutar roda: ${RupiahFormatter.format(budget)}',
          'payload': {
            'budget': budget,
            'sessionId': effectiveSessionId,
          },
          'created_at': now.toIso8601String(),
        };

        // 1. Broadcast langsung via WebSocket channel DULUAN (< 5ms) tanpa menunggu database
        _broadcastGroupEvent(gid, eventMap);

        // 2. Simpan ke database Supabase secara paralel (mengurangi latensi jaringan)
        await Future.wait([
          supabase!.from('groups').update({
            'active_session': session.toMap(),
          }).eq('id', gid),
          supabase!.from('group_events').insert(eventMap),
        ]);
      } catch (e) {
        debugPrint('[GroupService] recordSpin Supabase error: $e');
      }
      return;
    }

    if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final batch = firestore!.batch();

        batch.update(groupRef, {
          'activeSession': session.toMap(),
        });

        final eventRef = groupRef.collection('events').doc(spinEvtId);
        batch.set(eventRef, {
          'type': GroupEventType.spin.value,
          'actorUid': uid,
          'actorName': actorName,
          'summary': '$actorName memutar roda: ${RupiahFormatter.format(budget)}',
          'payload': {
            'budget': budget,
            'sessionId': sessionId,
          },
          'createdAt': now.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (_) {}
    }
  }

  Future<void> _handleIncomingRealtimeBroadcast(String gid, Map<String, dynamic> rawPayload) async {
    try {
      Map<String, dynamic> evtMap = rawPayload;
      if (evtMap.containsKey('payload') && evtMap['payload'] is Map) {
        final inner = Map<String, dynamic>.from(evtMap['payload'] as Map);
        if (inner.containsKey('id') || inner.containsKey('type') || inner.containsKey('actor_uid')) {
          evtMap = inner;
        }
      }
      final evtId = (evtMap['id'] ?? evtMap['eventId'] ?? '').toString();
      final newEvt = GroupEventModel.fromMap(evtId, evtMap);

      // 1. Simpan ke riwayat event lokal & siarkan perubahan log aktivitas
      final currentEvents = _getLocalEvents(gid);
      if (!currentEvents.any((e) => e.eventId == newEvt.eventId)) {
        currentEvents.insert(0, newEvt);
        await _saveLocalEvents(gid, currentEvents);
        _notifyEventsChanged(gid, currentEvents);
      }

      // 2. Realtime Member Leave / Kick (< 50ms)
      if (newEvt.type == GroupEventType.memberLeave) {
        final targetUid = newEvt.payload['kickedUid']?.toString() ??
            newEvt.payload['leaverUid']?.toString() ??
            newEvt.actorUid;
        final targetName = (newEvt.payload['kickedName'] ??
                newEvt.payload['leaverName'] ??
                newEvt.actorName)
            ?.toString()
            .toLowerCase()
            .trim();

        final curMembers = _getLocalMembers(gid);
        final updatedMembers = curMembers.where((m) {
          if (m.isOwner) return true;
          if (targetUid.isNotEmpty && m.uid == targetUid) return false;
          if (targetName != null &&
              targetName.isNotEmpty &&
              m.name.toLowerCase().trim() == targetName) {
            return false;
          }
          return true;
        }).toList();

        if (updatedMembers.length != curMembers.length) {
          final clean = _cleanAndDeduplicate(gid, updatedMembers);
          await _saveLocalMembers(gid, clean);
          _notifyMembersChanged(gid, clean);
        }
        final curGroup = _getLocalGroup(gid);
        if (curGroup != null) {
          final newCount = updatedMembers.length.clamp(1, 10);
          if (curGroup.memberCount != newCount) {
            final updatedGroup = curGroup.copyWith(memberCount: newCount);
            await _saveLocalGroup(updatedGroup);
            _notifyGroupChanged(gid, updatedGroup);
          }
        }
      }

      // 3. Realtime Member Join (< 50ms)
      if (newEvt.type == GroupEventType.memberJoin) {
        final joinUid = newEvt.payload['uid']?.toString() ?? newEvt.actorUid;
        final joinName = (newEvt.payload['name']?.toString() ?? newEvt.actorName).trim();
        final joinColor = (newEvt.payload['color_index'] ?? newEvt.payload['colorIndex'] as num?)?.toInt() ?? 0;
        final joinRole = newEvt.payload['role']?.toString() ?? 'member';
        if (joinUid.isNotEmpty) {
          final curMembers = _getLocalMembers(gid);
          final existingIndex = curMembers.indexWhere(
            (m) =>
                m.uid == joinUid ||
                (m.role == 'member' && m.name.toLowerCase().trim() == joinName.toLowerCase()),
          );
          List<GroupMemberModel> updatedMembers;
          if (existingIndex != -1) {
            final existing = curMembers[existingIndex];
            updatedMembers = List<GroupMemberModel>.from(curMembers);
            updatedMembers[existingIndex] = GroupMemberModel(
              uid: joinUid,
              name: joinName,
              colorIndex: joinColor,
              role: existing.role,
              joinedAt: existing.joinedAt,
              lastReadAt: newEvt.createdAt,
            );
          } else {
            final newMember = GroupMemberModel(
              uid: joinUid,
              name: joinName,
              colorIndex: joinColor,
              role: joinRole,
              joinedAt: newEvt.createdAt,
              lastReadAt: newEvt.createdAt,
            );
            updatedMembers = [...curMembers, newMember];
          }

          final cleanMembers = _cleanAndDeduplicate(gid, updatedMembers);
          await _saveLocalMembers(gid, cleanMembers);
          _notifyMembersChanged(gid, cleanMembers);

          final curGroup = _getLocalGroup(gid);
          if (curGroup != null) {
            final newCount = cleanMembers.length.clamp(1, 10);
            if (curGroup.memberCount != newCount) {
              final updatedGroup = curGroup.copyWith(memberCount: newCount);
              await _saveLocalGroup(updatedGroup);
              _notifyGroupChanged(gid, updatedGroup);
            }
          }
        }
      }

      // 4. Realtime Expense Added (< 50ms)
      if (newEvt.type == GroupEventType.expense && newEvt.payload['deleted'] != true) {
        final noteId = newEvt.payload['noteId']?.toString();
        final sessId = newEvt.payload['sessionId']?.toString() ?? '';
        final title = newEvt.payload['title']?.toString() ?? '';
        final amount = (newEvt.payload['amount'] as num?)?.toInt() ?? 0;
        if (noteId != null && noteId.isNotEmpty && amount > 0) {
          final curNotes = _getLocalNotes(gid);
          if (!curNotes.any((n) => n.noteId == noteId)) {
            final newNote = GroupNoteModel(
              noteId: noteId,
              sessionId: sessId,
              authorUid: newEvt.actorUid,
              authorName: newEvt.actorName,
              title: title,
              amount: amount,
              createdAt: newEvt.createdAt,
              deleted: false,
            );
            final updatedNotes = [newNote, ...curNotes];
            await _saveLocalNotes(gid, updatedNotes);
            _notifyNotesChanged(gid, updatedNotes);
          }
        }
      }

      // 5. Realtime Expense Deleted (< 50ms)
      if (newEvt.type == GroupEventType.expense && newEvt.payload['deleted'] == true) {
        final noteId = newEvt.payload['noteId']?.toString();
        if (noteId != null && noteId.isNotEmpty) {
          final curNotes = _getLocalNotes(gid);
          final idx = curNotes.indexWhere((n) => n.noteId == noteId);
          if (idx != -1 && !curNotes[idx].deleted) {
            curNotes[idx] = curNotes[idx].copyWith(deleted: true);
            await _saveLocalNotes(gid, curNotes);
            _notifyNotesChanged(gid, curNotes);
          }
        }
      }

      // 6. Realtime Session Start (< 50ms)
      if (newEvt.type == GroupEventType.sessionStart &&
          newEvt.payload['sessionId'] != null &&
          newEvt.payload['budget'] != null) {
        final sessId = newEvt.payload['sessionId'].toString();
        final budget = (newEvt.payload['budget'] as num).toInt();
        final startedByUid = newEvt.payload['startedByUid']?.toString() ?? newEvt.actorUid;
        final startedByName = newEvt.payload['startedByName']?.toString() ?? newEvt.actorName;
        final session = GroupSessionModel(
          sessionId: sessId,
          budget: budget,
          startedByUid: startedByUid,
          startedByName: startedByName,
          startedAt: newEvt.createdAt,
        );
        final cur = _getLocalGroup(gid);
        if (cur != null) {
          final updated = cur.copyWith(activeSession: session);
          await _saveLocalGroup(updated);
          _notifyGroupChanged(gid, updated);
        }
      }

      // 7. Realtime Budget Changed (< 50ms)
      if (newEvt.type == GroupEventType.budgetChanged ||
          (newEvt.type == GroupEventType.custom &&
              newEvt.payload['action'] == 'update_budget_settings')) {
        final cur = _getLocalGroup(gid);
        if (cur != null) {
          final budgetMode = newEvt.payload['budgetMode']?.toString() ?? cur.budgetMode;
          final fixedBudget = (newEvt.payload['fixedBudget'] as num?)?.toInt() ?? cur.fixedBudget;
          final spinPolicy = newEvt.payload['spinPolicy']?.toString() ?? cur.spinPolicy;
          List<int>? slots;
          if (newEvt.payload['wheelSlots'] is List) {
            slots = (newEvt.payload['wheelSlots'] as List).map((e) => (e as num).toInt()).toList();
            if (slots.length >= 2 && slots.length <= 12) {
              await _saveStoredGroupSlots(gid, slots);
            }
          }
          final updated = cur.copyWith(
            budgetMode: budgetMode,
            fixedBudget: fixedBudget,
            spinPolicy: spinPolicy,
            wheelSlots: slots ?? cur.wheelSlots,
          );
          await _saveLocalGroup(updated);
          _notifyGroupChanged(gid, updated);
        }
      }

      // 8. Realtime Code Changed (< 50ms)
      if (newEvt.type == GroupEventType.codeChanged) {
        final newCode = newEvt.payload['code']?.toString() ?? '';
        if (newCode.isNotEmpty) {
          final cur = _getLocalGroup(gid);
          if (cur != null && cur.code != newCode) {
            final updated = cur.copyWith(code: newCode);
            await _saveLocalGroup(updated);
            _notifyGroupChanged(gid, updated);
          }
        }
      }

      // 9. Realtime Wheel Slots Update (< 50ms)
      if (newEvt.type == GroupEventType.custom &&
          newEvt.payload['action'] == 'update_slots' &&
          newEvt.payload['wheelSlots'] is List) {
        final slots = (newEvt.payload['wheelSlots'] as List).map((e) => (e as num).toInt()).toList();
        if (slots.length >= 2 && slots.length <= 12) {
          await _saveStoredGroupSlots(gid, slots);
          final cur = _getLocalGroup(gid);
          if (cur != null && !listEquals(cur.wheelSlots, slots)) {
            final updated = cur.copyWith(wheelSlots: slots);
            await _saveLocalGroup(updated);
            _notifyGroupChanged(gid, updated);
          }
        }
      }

      // 10. Realtime Game Result (UPDATE 2D: Update sesi & budget tanpa animasi ulang)
      if (newEvt.type == GroupEventType.gameResult &&
          newEvt.payload['valid'] != false &&
          newEvt.payload['amount'] != null) {
        final amount = (newEvt.payload['amount'] as num).toInt();
        final game = newEvt.payload['game']?.toString() ?? 'wheel';
        final sessId = newEvt.payload['sessionId']?.toString() ??
            'sess_${newEvt.createdAt.millisecondsSinceEpoch}';
        final cur = _getLocalGroup(gid);
        if (cur != null) {
          final isLocked = cur.lockPolicy == 'lock';
          final newSession = GroupSessionModel(
            sessionId: sessId,
            budget: amount,
            game: game,
            startedByUid: newEvt.actorUid,
            startedByName: newEvt.actorName,
            startedAt: newEvt.createdAt,
            locked: isLocked,
          );
          final updated = cur.copyWith(activeSession: newSession);
          await _saveLocalGroup(updated);
          _notifyGroupChanged(gid, updated);
        }
      }
    } catch (e) {
      debugPrint('[GroupService] Broadcast handle error: $e');
    }
  }

  void _handleCustomEventPayload(String gid, GroupEventModel evt) {
    _handleIncomingRealtimeBroadcast(gid, evt.toMap());
  }

  /// Memantau log aktivitas grup realtime (Local-First + Broadcast + Polling)
  Stream<List<GroupEventModel>> watchEvents(String gid) async* {
    final local = _getLocalEvents(gid);
    if (local.isNotEmpty) {
      yield local;
    }

    final controller = StreamController<List<GroupEventModel>>.broadcast();
    _eventsControllers.putIfAbsent(gid, () => []).add(controller);

    // 1. Initial query from Supabase
    if (supabase != null) {
      try {
        final rows = await supabase!
            .from('group_events')
            .select('*')
            .eq('gid', gid)
            .order('created_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          final events = (rows as List)
              .map((r) => GroupEventModel.fromMap(r['id']?.toString() ?? '', r))
              .toList();
          await _saveLocalEvents(gid, events);
          yield events;
        }
      } catch (_) {}
    }

    // 2. Realtime Broadcast Listener (< 50ms)
    void Function(Map<String, dynamic>)? broadcastCb;
    if (supabase != null) {
      try {
        broadcastCb = (payload) async {
          try {
            Map<String, dynamic> evtMap = Map<String, dynamic>.from(payload);
            if (evtMap.containsKey('payload') && evtMap['payload'] is Map) {
              final inner = Map<String, dynamic>.from(evtMap['payload'] as Map);
              if (inner.containsKey('id') || inner.containsKey('type') || inner.containsKey('actor_uid')) {
                evtMap = inner;
              }
            }
            final evtId = (evtMap['id'] ?? evtMap['eventId'] ?? '').toString();
            final newEvt = GroupEventModel.fromMap(evtId, evtMap);
            _handleCustomEventPayload(gid, newEvt);
            final current = _getLocalEvents(gid);
            if (!current.any((e) => e.eventId == newEvt.eventId)) {
              current.insert(0, newEvt);
              await _saveLocalEvents(gid, current);
              _notifyEventsChanged(gid, current);
            }
          } catch (e) {
            debugPrint('[GroupService] Broadcast receive error: $e');
          }
        };
        _ensureChannel(gid, onBroadcastEvent: broadcastCb);
      } catch (_) {}
    }

    // 3. Fallback Periodic Polling (every 15 seconds)
    Timer? pollTimer;
    if (supabase != null) {
      pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        try {
          final rows = await supabase!
              .from('group_events')
              .select('*')
              .eq('gid', gid)
              .order('created_at', ascending: false)
              .limit(50);
          if (rows.isNotEmpty) {
            final events = (rows as List)
                .map((r) => GroupEventModel.fromMap(r['id']?.toString() ?? '', r))
                .toList();
            await _saveLocalEvents(gid, events);
          }
        } catch (_) {}
      });
    }

    // 4. Supabase Postgres table stream
    StreamSubscription? subSubscription;
    if (supabase != null) {
      try {
        subSubscription = supabase!
            .from('group_events')
            .stream(primaryKey: ['id'])
            .eq('gid', gid)
            .order('created_at', ascending: false)
            .listen((rows) {
              final events = rows.map((r) => GroupEventModel.fromMap(r['id']?.toString() ?? '', r)).toList();
              _saveLocalEvents(gid, events);
            }, onError: (_) {});
      } catch (_) {}
    }

    // 5. Firestore fallback
    StreamSubscription? firestoreSub;
    if (firestore != null) {
      try {
        firestoreSub = firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
              final events = snapshot.docs.map((doc) => GroupEventModel.fromMap(doc.id, doc.data())).toList();
              events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _saveLocalEvents(gid, events);
              if (!controller.isClosed) controller.add(events);
            });
      } catch (_) {}
    }

    controller.onCancel = () {
      _eventsControllers[gid]?.remove(controller);
      if (broadcastCb != null) {
        _onBroadcastCallbacks.remove(broadcastCb);
      }
      pollTimer?.cancel();
      subSubscription?.cancel();
      firestoreSub?.cancel();
    };

    yield* controller.stream;
  }

  /// Menandai bahwa pengguna telah membaca aktivitas terkini di grup
  Future<void> markActivityAsRead(String gid) async {
    final myUid = authService.currentUid;
    if (myUid == null) return;
    final now = DateTime.now();

    if (supabase != null) {
      try {
        await supabase!
            .from('group_members')
            .update({'last_read_at': now.toIso8601String()})
            .eq('gid', gid)
            .eq('uid', myUid);
      } catch (_) {}
      return;
    }

    if (firestore != null) {
      try {
        await firestore!
            .collection('groups')
            .doc(gid)
            .collection('members')
            .doc(myUid)
            .update({'lastReadAt': now.millisecondsSinceEpoch});
      } catch (_) {}
    }
  }

  /// Memperbarui timestamp kehadiran pengguna (lastSeenAt)
  Future<void> updatePresence(String gid) async {
    final myUid = authService.currentUid;
    if (myUid == null) return;
    final now = DateTime.now();

    if (supabase != null) {
      try {
        await supabase!
            .from('group_members')
            .update({'last_seen_at': now.toIso8601String()})
            .eq('gid', gid)
            .eq('uid', myUid);
      } catch (_) {}

      try {
        final ch = _ensureChannel(gid);
        ch?.sendBroadcastMessage(
          event: 'presence_pulse',
          payload: {'uid': myUid, 'timestamp': now.millisecondsSinceEpoch},
        );
      } catch (_) {}
      return;
    }

    if (firestore != null) {
      try {
        await firestore!
            .collection('groups')
            .doc(gid)
            .collection('members')
            .doc(myUid)
            .update({'lastSeenAt': now.millisecondsSinceEpoch});
      } catch (_) {}
    }
  }
}

/// Provider GroupService
final groupServiceProvider = Provider<GroupService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final authService = ref.watch(groupAuthServiceProvider);

  SupabaseClient? supabase;
  try {
    supabase = Supabase.instance.client;
  } catch (_) {
    supabase = null;
  }

  final service = GroupService(
    firestore: null,
    supabase: supabase,
    authService: authService,
    prefs: prefs,
  );

  service.onActiveGroupIdChanged = (gid) {
    ref.read(activeGroupIdProvider.notifier).state = gid;
  };

  return service;
});

/// StateProvider untuk ID grup aktif yang reaktif
final activeGroupIdProvider = StateProvider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(GroupService.keyActiveGroupId);
});

/// StreamProvider untuk memantau grup aktif
final activeGroupStreamProvider = StreamProvider<GroupModel?>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty) {
    return Stream.value(null);
  }
  return groupService.watchGroup(activeGid);
});

/// StreamProvider untuk memantau anggota grup aktif
final activeGroupMembersStreamProvider = StreamProvider<List<GroupMemberModel>>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty) {
    return Stream.value([]);
  }
  return groupService.watchMembers(activeGid);
});

/// StreamProvider untuk memantau catatan sesi grup aktif
final activeGroupNotesStreamProvider = StreamProvider<List<GroupNoteModel>>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGroupAsync = ref.watch(activeGroupStreamProvider);
  final group = activeGroupAsync.valueOrNull;
  if (group == null || group.activeSession == null) {
    return Stream.value([]);
  }
  return groupService.watchNotes(group.id, group.activeSession!.sessionId);
});

/// StreamProvider untuk memantau log aktivitas grup aktif
final activeGroupEventsStreamProvider = StreamProvider<List<GroupEventModel>>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty) {
    return Stream.value([]);
  }
  return groupService.watchEvents(activeGid);
});

/// Provider menghitung jumlah aktivitas belum dibaca oleh anggota saat ini
final unreadActivityCountProvider = Provider<int>((ref) {
  final authService = ref.watch(groupAuthServiceProvider);
  final myUid = authService.currentUid;
  if (myUid == null) return 0;

  final membersAsync = ref.watch(activeGroupMembersStreamProvider);
  final eventsAsync = ref.watch(activeGroupEventsStreamProvider);

  final members = membersAsync.valueOrNull ?? [];
  final events = eventsAsync.valueOrNull ?? [];

  final myMember = members.firstWhere(
    (m) => m.uid == myUid,
    orElse: () => GroupMemberModel(
      uid: myUid,
      name: authService.displayName ?? '',
      colorIndex: 0,
      role: 'member',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
      lastReadAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  return events.where((e) {
    return e.actorUid != myUid && e.createdAt.isAfter(myMember.lastReadAt);
  }).length;
});
