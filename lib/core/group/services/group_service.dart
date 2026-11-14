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
import '../models/group_history_models.dart';
import '../models/invite_code_model.dart';
import '../models/live_play_model.dart';
import '../../utils/rupiah_formatter.dart';
import 'group_auth_service.dart';

/// Service untuk Operasi Grup Bersama (Local-First dengan Supabase PostgreSQL)
class GroupService {
  static const String keyActiveGroupId = 'active_group_id';

  /// Generator ID event grup unik deterministik dengan proteksi anti-tabrakan
  static String generateEventId() => 'evt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

  final dynamic firestore;
  final SupabaseClient? _supabaseOverride;
  final bool resolveLiveSupabase;
  final GroupAuthService authService;
  final SharedPreferences prefs;

  /// Mengembalikan instance Supabase aktif (atau override pengujian jika disetel).
  SupabaseClient? get supabase {
    if (_supabaseOverride != null) return _supabaseOverride;
    if (!resolveLiveSupabase) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  ValueChanged<String?>? onActiveGroupIdChanged;

  RealtimeChannel? _realtimeChannel;
  String? _subscribedChannelGid;
  Completer<void>? _channelSubscribeCompleter;
  bool _isChannelSubscribed = false;
  bool _channelNeedsReconnect = false;
  Timer? _channelReconnectTimer;
  int _channelReconnectAttempt = 0;
  bool _disposed = false;
  final Map<String, Future<void>> _eventWriteChains = {};

  int _lastReadRevision = 0;
  final StreamController<int> _lastReadRevisionController =
      StreamController<int>.broadcast();

  GroupService({
    this.firestore,
    SupabaseClient? supabase,
    this.resolveLiveSupabase = false,
    required this.authService,
    required this.prefs,
  }) : _supabaseOverride = supabase;

  final List<void Function(Map<String, dynamic>)> _onBroadcastCallbacks = [];

  final Map<String, List<StreamController<List<GroupEventModel>>>> _eventsControllers = {};
  final Map<String, List<StreamController<List<GroupMemberModel>>>> _membersControllers = {};
  final Map<String, List<StreamController<List<GroupNoteModel>>>> _notesControllers = {};
  final Map<String, List<StreamController<List<GroupSessionModel>>>> _sessionsControllers = {};
  final Map<String, List<StreamController<GroupModel?>>> _groupControllers = {};
  final Map<String, GroupModel> _latestGroups = {};
  final Map<String, Future<GroupSessionModel?>> _inFlightEndSessions = {};
  final Map<String, List<StreamController<Map<String, dynamic>>>> _liveSpinControllers = {};
  final Map<String, List<StreamController<LivePlayModel?>>> _livePlayControllers = {};

  void _notifySessionsChanged(String gid, List<GroupSessionModel> sessions) {
    final controllers = _sessionsControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(List.from(sessions));
      }
    }
  }

  void _notifyLivePlay(String gid, LivePlayModel? play) {
    final controllers = _livePlayControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(play);
      }
    }
  }

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
    if (group != null) {
      _latestGroups[gid] = group;
    } else {
      _latestGroups.remove(gid);
    }
    final controllers = _groupControllers[gid];
    if (controllers != null) {
      for (final c in List.of(controllers)) {
        if (!c.isClosed) c.add(group);
      }
    }
  }

  /// Memancarkan perubahan model grup ke seluruh stream listener aktif
  void notifyGroupChanged(String gid, GroupModel? group) => _notifyGroupChanged(gid, group);

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

  /// Memaksa penyambungan ulang channel realtime & tarik ulang event setelah aplikasi resume
  void reconnectAndRefresh(String gid) {
    if (_disposed || supabase == null || gid.isEmpty) return;
    _channelNeedsReconnect = true;
    _ensureChannel(gid);
    unawaited(refreshEvents(gid));
  }

  /// Melepaskan resource channel realtime & timer saat service dibuang
  void dispose() {
    _disposed = true;
    _channelReconnectTimer?.cancel();
    _channelReconnectTimer = null;
    _isChannelSubscribed = false;
    _channelNeedsReconnect = false;
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    _realtimeChannel = null;
    _subscribedChannelGid = null;
    _onBroadcastCallbacks.clear();
  }

  bool _hasActiveListenersFor(String gid) {
    bool hasOpen<T>(Map<String, List<StreamController<T>>> map) =>
        map[gid]?.any((c) => !c.isClosed) ?? false;
    return hasOpen(_eventsControllers) ||
        hasOpen(_membersControllers) ||
        hasOpen(_notesControllers) ||
        hasOpen(_sessionsControllers) ||
        hasOpen(_groupControllers) ||
        hasOpen(_liveSpinControllers) ||
        hasOpen(_livePlayControllers);
  }

  void _scheduleChannelReconnect(String gid) {
    if (_disposed || supabase == null) return;
    if (_subscribedChannelGid != gid || !_hasActiveListenersFor(gid)) return;
    if (_channelReconnectTimer?.isActive ?? false) return;

    const backoffSeconds = [1, 2, 4, 8, 15];
    final delaySec = backoffSeconds[_channelReconnectAttempt.clamp(0, backoffSeconds.length - 1)];
    _channelReconnectAttempt = (_channelReconnectAttempt + 1).clamp(0, backoffSeconds.length);

    _channelReconnectTimer = Timer(Duration(seconds: delaySec), () {
      _channelReconnectTimer = null;
      if (_disposed || _subscribedChannelGid != gid || !_hasActiveListenersFor(gid)) return;
      _channelNeedsReconnect = true;
      _ensureChannel(gid);
    });
  }

  Future<void> _enqueueEventWrite(String gid, Future<void> Function() action) {
    final prev = _eventWriteChains[gid];
    Future<void> next;
    if (prev == null) {
      next = Future<void>.sync(action);
    } else {
      next = prev.then((_) => action(), onError: (_) => action());
    }
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_eventWriteChains[gid], tracked)) {
        _eventWriteChains.remove(gid);
      }
    });
    _eventWriteChains[gid] = tracked;
    return tracked;
  }

  /// Membuka bungkus payload broadcast Supabase Realtime tanpa kehilangan
  /// tipe asli event (`type`) maupun saat payload dibungkus di `event_record`/`payload`.
  static Map<String, dynamic> unwrapBroadcastEventPayload(Map<String, dynamic> rawPayload) {
    Map<String, dynamic> current = Map<String, dynamic>.from(rawPayload);
    for (var depth = 0; depth < 3; depth++) {
      if (current['event_record'] is Map) {
        current = Map<String, dynamic>.from(current['event_record'] as Map);
        continue;
      }
      if (current['payload'] is Map) {
        final inner = Map<String, dynamic>.from(current['payload'] as Map);
        if (inner.containsKey('event_record') ||
            inner.containsKey('id') ||
            inner.containsKey('eventId') ||
            inner.containsKey('type') ||
            inner.containsKey('actor_uid') ||
            inner.containsKey('actorUid')) {
          current = inner;
          continue;
        }
      }
      break;
    }
    if (current['type'] == 'broadcast' && current['event_type'] != null) {
      current['type'] = current['event_type'];
    }
    return current;
  }

  RealtimeChannel? _ensureChannel(String gid, {void Function(Map<String, dynamic>)? onBroadcastEvent}) {
    if (supabase == null || _disposed) return null;
    if (onBroadcastEvent != null && !_onBroadcastCallbacks.contains(onBroadcastEvent)) {
      _onBroadcastCallbacks.add(onBroadcastEvent);
    }
    if (_realtimeChannel != null && _subscribedChannelGid == gid && !_channelNeedsReconnect) {
      return _realtimeChannel;
    }
    _channelReconnectTimer?.cancel();
    _channelReconnectTimer = null;
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    _subscribedChannelGid = gid;
    _isChannelSubscribed = false;
    _channelNeedsReconnect = false;
    _channelSubscribeCompleter = Completer<void>();

    final ch = supabase!.channel('realtime_group_$gid');
    ch.onBroadcast(
      event: 'group_event',
      callback: (payload) {
        final data = unwrapBroadcastEventPayload(Map<String, dynamic>.from(payload));
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
      event: 'live_play_current',
      callback: (payload) {
        final play = LivePlayModel.fromMap(Map<String, dynamic>.from(payload));
        _saveLocalLivePlay(gid, play);
        _notifyLivePlay(gid, play);
      },
    );
    ch.onBroadcast(
      event: 'presence_pulse',
      callback: (payload) {
        _handlePresencePulse(gid, Map<String, dynamic>.from(payload));
      },
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'group_events',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'gid',
        value: gid,
      ),
      callback: (pgPayload) {
        if (pgPayload.newRecord.isNotEmpty) {
          _handleIncomingRealtimeBroadcast(
            gid,
            Map<String, dynamic>.from(pgPayload.newRecord),
          );
        }
      },
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'group_events',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'gid',
        value: gid,
      ),
      callback: (pgPayload) {
        if (pgPayload.newRecord.isNotEmpty) {
          _handleIncomingRealtimeBroadcast(
            gid,
            Map<String, dynamic>.from(pgPayload.newRecord),
          );
        }
      },
    );

    ch.subscribe((status, error) {
      if (_disposed || _realtimeChannel != ch) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isChannelSubscribed = true;
        _channelNeedsReconnect = false;
        _channelReconnectAttempt = 0;
        _channelReconnectTimer?.cancel();
        _channelReconnectTimer = null;
        if (!(_channelSubscribeCompleter?.isCompleted ?? true)) {
          _channelSubscribeCompleter?.complete();
        }
        if (_hasActiveListenersFor(gid)) {
          unawaited(refreshEvents(gid));
        }
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        _isChannelSubscribed = false;
        _channelNeedsReconnect = true;
        if (!(_channelSubscribeCompleter?.isCompleted ?? true)) {
          _channelSubscribeCompleter?.complete();
        }
        _scheduleChannelReconnect(gid);
      }
    });

    _realtimeChannel = ch;
    return _realtimeChannel;
  }

  String _keyLocalLivePlay(String gid) => 'local_live_play_$gid';

  LivePlayModel? getLocalLivePlay(String gid) {
    try {
      final jsonStr = prefs.getString(_keyLocalLivePlay(gid));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return LivePlayModel.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  void _saveLocalLivePlay(String gid, LivePlayModel play) {
    try {
      prefs.setString(_keyLocalLivePlay(gid), jsonEncode(play.toMap()));
    } catch (_) {}
  }

  /// Menonton siaran permainan langsung realtime (F2: groups/{gid}/live/current)
  Stream<LivePlayModel?> watchLivePlay(String gid) {
    _ensureChannel(gid);
    final controller = StreamController<LivePlayModel?>.broadcast();
    _livePlayControllers.putIfAbsent(gid, () => []).add(controller);

    final cached = getLocalLivePlay(gid);
    if (cached != null) {
      controller.add(cached);
    }

    StreamSubscription? firestoreSub;
    if (firestore != null) {
      try {
        firestoreSub = firestore!
            .collection('groups')
            .doc(gid)
            .collection('live')
            .doc('current')
            .snapshots()
            .listen((doc) {
          if (doc != null && doc.exists && doc.data() != null) {
            final data = Map<String, dynamic>.from(doc.data()!);
            final play = LivePlayModel.fromMap(data);
            _saveLocalLivePlay(gid, play);
            controller.add(play);
          }
        }, onError: (e) {
          debugPrint('[GroupService] watchLivePlay Firestore error: $e');
        });
      } catch (e) {
        debugPrint('[GroupService] watchLivePlay Firestore listener error: $e');
      }
    }

    controller.onCancel = () {
      firestoreSub?.cancel();
      _livePlayControllers[gid]?.remove(controller);
    };

    return controller.stream;
  }

  /// Menyiarkan putaran permainan langsung realtime ke seluruh anggota (F2)
  Future<bool> broadcastLivePlay(String gid, LivePlayModel play) async {
    // 1. Simpan ke cache lokal & beri tahu listener lokal
    _saveLocalLivePlay(gid, play);
    _notifyLivePlay(gid, play);

    // 2. Siarkan via Supabase Realtime channel WebSocket
    if (supabase != null) {
      try {
        final ch = await ensureChannelSubscribed(gid);
        await ch?.sendBroadcastMessage(
          event: 'live_play_current',
          payload: play.toMap(),
        );
      } catch (e) {
        debugPrint('[GroupService] Supabase broadcastLivePlay error: $e');
      }
    }

    // 3. Tulis dokumen ke Firestore: groups/{gid}/live/current
    if (firestore != null) {
      try {
        await firestore!
            .collection('groups')
            .doc(gid)
            .collection('live')
            .doc('current')
            .set(play.toMap());
      } catch (e) {
        debugPrint('[GroupService] Firestore broadcastLivePlay error: $e');
      }
    }

    return true;
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

    final livePlay = LivePlayModel(
      spinId: eventId ?? 'spin_${DateTime.now().millisecondsSinceEpoch}',
      game: 'wheel',
      startAtMs: DateTime.now().millisecondsSinceEpoch,
      durationMs: durationMs,
      laps: turns,
      resultIndex: winningIndex,
      finalAngle: normalized,
      amount: budget,
      startedByUid: uid,
      startedByName: name,
      params: {
        'winningIndex': winningIndex,
        'budget': budget,
      },
    );
    _saveLocalLivePlay(gid, livePlay);
    _notifyLivePlay(gid, livePlay);

    // 2. Broadcast ke semua perangkat melalui Supabase Realtime channel WebSocket
    if (supabase != null) {
      try {
        final ch = await ensureChannelSubscribed(gid);
        await ch?.sendBroadcastMessage(
          event: 'wheel_spin_live',
          payload: Map<String, dynamic>.from(payload),
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
      final snapshot = Map<String, dynamic>.from(eventMap);
      await ch?.sendBroadcastMessage(
        event: 'group_event',
        payload: <String, dynamic>{'event_record': snapshot},
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
  String _keyLocalSessions(String gid) => 'local_sessions_$gid';
  String _keyStoredGroupSlots(String gid) => 'group_wheel_slots_$gid';
  String _keyLastEndedSessionId(String gid) => 'group_last_ended_sid_$gid';
  String _keyLastEndedAt(String gid) => 'group_last_ended_at_$gid';
  String _keyShownResultSessionIds(String gid) => 'group_shown_result_sids_$gid';

  /// Mengecek apakah Layar Hasil (68/69) sudah pernah ditampilkan pada perangkat ini untuk sessionId tertentu.
  bool hasShownResultForSession(String gid, String sessionId) {
    if (gid.isEmpty || sessionId.isEmpty) return false;
    try {
      final shown = prefs.getStringList(_keyShownResultSessionIds(gid));
      return shown != null && shown.contains(sessionId);
    } catch (_) {
      return false;
    }
  }

  /// Menyimpan secara lokal bahwa Layar Hasil (68/69) sudah ditampilkan untuk sessionId ini
  /// agar tidak muncul berulang kali saat restart aplikasi.
  Future<void> markResultAsShown(String gid, String sessionId) async {
    if (gid.isEmpty || sessionId.isEmpty) return;
    try {
      final key = _keyShownResultSessionIds(gid);
      final current = List<String>.from(prefs.getStringList(key) ?? const []);
      if (current.contains(sessionId)) return;
      current.insert(0, sessionId);
      if (current.length > 100) {
        current.removeRange(100, current.length);
      }
      await prefs.setStringList(key, current);
    } catch (_) {}
  }

  /// Ringkasan sesi aktif saat ini (budget, total terpakai, jumlah catatan aktif).
  ({
    int budget,
    int totalSpent,
    int itemCount,
    String sessionId,
    GroupSessionModel? session,
  }) getActiveSessionSummary(String gid) {
    final activeSess = getEffectiveActiveSession(gid);
    if (activeSess == null) {
      return (
        budget: 0,
        totalSpent: 0,
        itemCount: 0,
        sessionId: '',
        session: null,
      );
    }
    final activeNotes = GroupHistoryCalculator.sortActiveNotesChronologically(
      _getLocalNotes(gid)
          .where((n) => n.sessionId == activeSess.sessionId || n.sessionId.isEmpty)
          .toList(),
    );
    final totalSpent = GroupHistoryCalculator.computeTotalSpent(activeNotes);
    return (
      budget: activeSess.budget,
      totalSpent: totalSpent,
      itemCount: activeNotes.length,
      sessionId: activeSess.sessionId,
      session: activeSess,
    );
  }

  GroupSessionModel? _findLocalSessionById(String gid, String sessionId) {
    if (sessionId.isEmpty) return null;
    final sessions = _getLocalSessions(gid);
    final idx = sessions.indexWhere((s) => s.sessionId == sessionId);
    if (idx != -1) return sessions[idx];
    final localGroup = _getLocalGroup(gid);
    if (localGroup?.activeSession?.sessionId == sessionId) {
      return localGroup!.activeSession;
    }
    return null;
  }

  Future<void> clearEndedSessionMarker(String gid) =>
      _clearEndedSessionMarker(gid);

  Future<void> _clearEndedSessionMarker(String gid) async {
    try {
      await prefs.remove(_keyLastEndedSessionId(gid));
      await prefs.remove(_keyLastEndedAt(gid));
    } catch (_) {}
  }

  /// Mendapatkan sesi aktif yang valid saat ini untuk grup
  GroupSessionModel? getEffectiveActiveSession(
    String gid, [
    GroupModel? group,
  ]) {
    final local = _getLocalGroup(gid);
    return resolveEffectiveSession(
      gid,
      group?.activeSession,
      local?.activeSession,
    );
  }

  /// Mengecek apakah grup saat ini memiliki sesi aktif dengan budget > 0
  bool hasActiveBudgetSession(String gid, [GroupModel? group]) {
    final eff = getEffectiveActiveSession(gid, group);
    return eff != null && eff.budget > 0;
  }

  Future<void> _markSessionEnded(String gid, String endedSessionId, DateTime endedAt) async {
    try {
      if (endedSessionId.isNotEmpty) {
        await prefs.setString(_keyLastEndedSessionId(gid), endedSessionId);
      }
      await prefs.setInt(_keyLastEndedAt(gid), endedAt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Mengecek apakah suatu sesi grup sudah diakhiri secara lokal/remote
  bool isSessionEnded(String gid, GroupSessionModel? session) {
    if (session == null || session.sessionId.isEmpty) return true;
    final lastEndedSid = prefs.getString(_keyLastEndedSessionId(gid));
    if (lastEndedSid != null && lastEndedSid.isNotEmpty && session.sessionId == lastEndedSid) {
      return true;
    }
    final lastEndedAtMs = prefs.getInt(_keyLastEndedAt(gid));
    if (lastEndedAtMs != null && session.startedAt.millisecondsSinceEpoch <= lastEndedAtMs) {
      return true;
    }
    final evts = _getLocalEvents(gid);
    for (final evt in evts) {
      if (evt.payload['action'] == 'end_session') {
        final endedSid = evt.payload['endedSessionId']?.toString();
        if (endedSid == session.sessionId) return true;
        if (!session.startedAt.isAfter(evt.createdAt)) return true;
        break;
      }
      if (evt.payload['sessionId'] == session.sessionId &&
          (evt.type == GroupEventType.gameResult ||
              evt.type == GroupEventType.spin ||
              evt.type == GroupEventType.sessionStart)) {
        return false;
      }
    }
    return false;
  }

  /// Menyelesaikan konflik antara sesi remote dan lokal secara deterministik:
  /// - Mengabaikan sesi yang sudah berstatus diakhiri (`end_session`).
  /// - Memilih sesi dengan waktu mulai (`startedAt`) paling baru agar putaran roda baru
  ///   tidak pernah tertimpa oleh sesi lama dari polling database.
  GroupSessionModel? resolveEffectiveSession(
    String gid,
    GroupSessionModel? remoteSession,
    GroupSessionModel? localSession,
  ) {
    final validRemote = isSessionEnded(gid, remoteSession) ? null : remoteSession;
    final validLocal = isSessionEnded(gid, localSession) ? null : localSession;
    if (validRemote == null && validLocal == null) return null;
    if (validRemote == null) return validLocal;
    if (validLocal == null) return validRemote;
    if (validRemote.sessionId == validLocal.sessionId) return validRemote;
    return validLocal.startedAt.isAfter(validRemote.startedAt) ? validLocal : validRemote;
  }

  int? _recoverSessionBudgetFromEvents(String gid, String sessionId) {
    final evts = _getLocalEvents(gid);
    for (final evt in evts) {
      if (evt.payload['action'] == 'end_session') break;
      if (sessionId.isNotEmpty && evt.payload['sessionId']?.toString() == sessionId) {
        final b = evt.payload['amount'] ?? evt.payload['budget'];
        if (b is num && b.toInt() > 0) return b.toInt();
      }
    }
    for (final evt in evts) {
      if (evt.payload['action'] == 'end_session') break;
      if ((evt.type == GroupEventType.gameResult ||
              evt.type == GroupEventType.spin ||
              evt.type == GroupEventType.sessionStart) &&
          evt.payload['valid'] != false) {
        final b = evt.payload['amount'] ?? evt.payload['budget'];
        if (b is num && b.toInt() > 0) return b.toInt();
      }
    }
    return null;
  }

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
      _latestGroups[group.id] = group;
      final currentStr = prefs.getString(_keyLocalGroup(group.id));
      final newStr = jsonEncode(group.toMap());
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalGroup(group.id), newStr);
      _notifyGroupChanged(group.id, group);
    } catch (_) {}
  }

  GroupModel? _getLocalGroup(String gid) {
    final cached = _latestGroups[gid];
    if (cached != null) return cached;
    final str = prefs.getString(_keyLocalGroup(gid));
    if (str == null) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      final parsed = GroupModel.fromMap(gid, map);
      _latestGroups[gid] = parsed;
      return parsed;
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

  /// Mendapatkan daftar catatan lokal grup yang tersimpan di memori perangkat
  List<GroupNoteModel> getLocalNotes(String gid) => _getLocalNotes(gid);

  /// Menyimpan daftar catatan lokal grup secara langsung
  Future<void> saveLocalNotes(String gid, List<GroupNoteModel> notes) =>
      _saveLocalNotes(gid, notes);

  Future<void> _saveLocalEvents(String gid, List<GroupEventModel> events) async {
    try {
      final seenIds = <String>{};
      final deduped = <GroupEventModel>[];
      for (final evt in events) {
        if (evt.eventId.isNotEmpty) {
          if (!seenIds.add(evt.eventId)) continue;
        }
        deduped.add(evt);
      }
      deduped.sort((a, b) {
        final cmp = b.createdAt.compareTo(a.createdAt);
        if (cmp != 0) return cmp;
        return b.eventId.compareTo(a.eventId);
      });
      final currentStr = prefs.getString(_keyLocalEvents(gid));
      final list = deduped.map((e) => e.toMap()).toList();
      final newStr = jsonEncode(list);
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalEvents(gid), newStr);
      _notifyEventsChanged(gid, deduped);
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

  Future<void> _saveLocalSessions(
    String gid,
    List<GroupSessionModel> sessions,
  ) async {
    try {
      final byId = <String, GroupSessionModel>{};
      for (final s in sessions) {
        if (s.sessionId.isNotEmpty) {
          byId[s.sessionId] = s.copyWith(gid: gid);
        }
      }
      final sorted = byId.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final currentStr = prefs.getString(_keyLocalSessions(gid));
      final list = sorted.map((s) => s.toMap()).toList();
      final newStr = jsonEncode(list);
      if (currentStr == newStr) return;
      await prefs.setString(_keyLocalSessions(gid), newStr);
      _notifySessionsChanged(gid, sorted);
    } catch (_) {}
  }

  List<GroupSessionModel> _getLocalSessions(String gid) {
    final str = prefs.getString(_keyLocalSessions(gid));
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      final sessions = list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return GroupSessionModel.fromMap(map).copyWith(gid: gid);
      }).toList();
      sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  /// Mendapatkan daftar sesi (riwayat date) lokal untuk grup
  List<GroupSessionModel> getLocalSessions(String gid) => _getLocalSessions(gid);

  /// Menyimpan atau memperbarui satu dokumen sesi pada cache lokal (tanpa menghapus sesi lama)
  Future<GroupSessionModel> upsertLocalSession(
    String gid,
    GroupSessionModel session,
  ) async {
    final sessions = _getLocalSessions(gid);
    final notes = _getLocalNotes(gid);
    final recalculated = GroupHistoryCalculator.recalculateSession(
      session: session.copyWith(gid: gid),
      sessionNotes: notes,
    );
    final idx = sessions.indexWhere((s) => s.sessionId == recalculated.sessionId);
    if (idx != -1) {
      sessions[idx] = recalculated;
    } else {
      sessions.insert(0, recalculated);
    }
    await _saveLocalSessions(gid, sessions);
    return recalculated;
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

  /// Mengambil daftar anggota grup lokal secara sinkron
  List<GroupMemberModel> getLocalMembers(String gid) => _getLocalMembers(gid);

  static const String _keyLocalLastReadPrefix = 'group_last_read_at_';

  /// Mengambil timestamp terakhir kali user membuka halaman notifikasi/aktivitas grup (lokal)
  DateTime? getLocalLastReadAt(String gid) {
    final ms = prefs.getInt('$_keyLocalLastReadPrefix$gid');
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Stream<int> watchLastReadRevision() async* {
    yield _lastReadRevision;
    yield* _lastReadRevisionController.stream;
  }

  Future<void> _setLocalLastReadAt(String gid, DateTime timestamp) async {
    try {
      await prefs.setInt(
        '$_keyLocalLastReadPrefix$gid',
        timestamp.millisecondsSinceEpoch,
      );
    } catch (_) {}
    _lastReadRevision++;
    if (!_disposed && !_lastReadRevisionController.isClosed) {
      _lastReadRevisionController.add(_lastReadRevision);
      // Beri 1 microtask agar StreamProvider penerima segera memicu rebuild sebelum method kembali.
      await Future<void>.value();
    }
  }

  /// Menentukan apakah [event] dihitung sebagai notifikasi belum dibaca di badge & seksi BARU.
  bool isUnreadEligibleEvent(GroupEventModel event, DateTime threshold) {
    // Aksi milik diri sendiri cukup diinformasikan di dalam aplikasi & langsung dianggap terbaca.
    if (authService.isCurrentUser(event.actorUid)) {
      return false;
    }
    // Hasil permainan tidak berlaku (saat budget sesi sudah terkunci) tidak memicu badge belum dibaca.
    if (event.type == GroupEventType.gameResult &&
        event.payload['valid'] == false) {
      return false;
    }
    return event.createdAt.isAfter(threshold);
  }

  /// Mengirim notifikasi event bahwa sesi grup telah dimulai oleh pemilik
  Future<void> notifySessionStarted(String gid) async {
    final uid = await authService.ensureSignedIn();
    final actorName = authService.displayName ?? 'Pemilik Grup';
    final now = DateTime.now();
    final evtId = generateEventId();

    final localEvt = GroupEventModel(
      eventId: evtId,
      type: GroupEventType.sessionStart,
      actorUid: uid,
      actorName: actorName,
      summary: '$actorName memulai sesi grup',
      payload: const {},
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);

    final eventMap = {
      'id': evtId,
      'gid': gid,
      'actor_uid': uid,
      'actor_name': actorName,
      'type': GroupEventType.sessionStart.value,
      'summary': '$actorName memulai sesi grup',
      'payload': {},
      'created_at': now.toUtc().toIso8601String(),
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
      eventId: generateEventId(),
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
    await _setLocalLastReadAt(gid, now);
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
          'created_at': now.toUtc().toIso8601String(),
          'member_count': 1,
          'active_session': null,
        });

        await supabase!.from('group_members').insert({
          'gid': gid,
          'uid': uid,
          'name': creatorName.trim(),
          'color_index': colorIndex,
          'role': 'owner',
          'joined_at': now.toUtc().toIso8601String(),
          'last_read_at': now.toUtc().toIso8601String(),
        });

        await supabase!.from('invite_codes').insert({
          'code': code,
          'gid': gid,
        });

        final eventMap = {
          'id': localEvt.eventId,
          'gid': gid,
          'actor_uid': uid,
          'actor_name': creatorName.trim(),
          'type': GroupEventType.memberJoin.value,
          'summary': '${creatorName.trim()} membuat grup "$cleanName"',
          'payload': {},
          'created_at': now.toUtc().toIso8601String(),
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

        final eventRef = groupRef.collection('events').doc(localEvt.eventId);
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
          'joined_at': now.toUtc().toIso8601String(),
          'last_read_at': now.toUtc().toIso8601String(),
        }).timeout(const Duration(seconds: 10));
        await _setLocalLastReadAt(gid, now);

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
          'id': generateEventId(),
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
          'created_at': now.toUtc().toIso8601String(),
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
              'last_seen_at': now.toUtc().toIso8601String(),
            }).eq('id', targetId).timeout(const Duration(seconds: 10));
          } else {
            await client.from('group_members').update({
              'name': memberName.trim(),
              'color_index': colorIndex,
              'last_seen_at': now.toUtc().toIso8601String(),
            }).eq('gid', gid).eq('uid', uid).timeout(const Duration(seconds: 10));
          }
        } catch (_) {}

        final rejoinEvtMap = {
          'id': generateEventId(),
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
          'created_at': now.toUtc().toIso8601String(),
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

                final eventRef = groupRef.collection('events').doc(generateEventId());
                final localJoinEvt = GroupEventModel(
                  eventId: generateEventId(),
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
                await _setLocalLastReadAt(gid, now);
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
    await _setLocalLastReadAt(mockGid, now);
    _notifyMembersChanged(mockGid, [mockMember]);

    final mockJoinEvt = GroupEventModel(
      eventId: generateEventId(),
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
    } else if (supabase == null && firestore == null) {
      yield null;
    }

    if (supabase == null && firestore != null) {
      try {
        await for (final doc in firestore!.collection('groups').doc(gid).snapshots()) {
          if (doc.exists && doc.data() != null) {
            final group = GroupModel.fromMap(doc.id, doc.data()!);
            final currentLocal = _getLocalGroup(gid);
            final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
            final effSession = resolveEffectiveSession(gid, group.activeSession, currentLocal?.activeSession);
            final merged = group.copyWith(
              wheelSlots: slots,
              activeSession: effSession,
              clearActiveSession: effSession == null,
            );
            await _saveLocalGroup(merged);
            _notifyGroupChanged(gid, merged);
            yield merged;
          }
        }
        return;
      } catch (_) {
        if (local != null) yield local;
        return;
      }
    }

    final controller = StreamController<GroupModel?>.broadcast();
    _groupControllers.putIfAbsent(gid, () => []).add(controller);

    Timer? timer;
    StreamSubscription? sub;

    if (supabase != null) {
      _ensureChannel(gid);

      // Jalankan initial fetch secara non-blocking agar yield* controller.stream langsung terpasang
      // dan tidak ada event _notifyGroupChanged yang terlewat saat menunggu jaringan.
      unawaited(() async {
        try {
          final row = await supabase!.from('groups').select('*').eq('id', gid).maybeSingle();
          if (row != null) {
            final group = GroupModel.fromMap(gid, row);
            final currentLocal = _getLocalGroup(gid);
            final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
            final effSession = resolveEffectiveSession(gid, group.activeSession, currentLocal?.activeSession);
            local = group.copyWith(
              wheelSlots: slots,
              activeSession: effSession,
              clearActiveSession: effSession == null,
            );
            await _saveLocalGroup(local!);
            _notifyGroupChanged(gid, local);
          }
        } catch (_) {}
      }());

      timer = Timer.periodic(const Duration(seconds: 4), (_) async {
        try {
          final row = await supabase!.from('groups').select('*').eq('id', gid).maybeSingle();
          if (row != null) {
            final group = GroupModel.fromMap(gid, row);
            final currentLocal = _getLocalGroup(gid);
            final slots = group.wheelSlots ?? currentLocal?.wheelSlots ?? _getStoredGroupSlots(gid);
            final effSession = resolveEffectiveSession(gid, group.activeSession, currentLocal?.activeSession);
            final merged = group.copyWith(
              wheelSlots: slots,
              activeSession: effSession,
              clearActiveSession: effSession == null,
            );
            await _saveLocalGroup(merged);
            _notifyGroupChanged(gid, merged);
          }
        } catch (_) {}
      });

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
                final effSession = resolveEffectiveSession(gid, group.activeSession, currentLocal?.activeSession);
                final merged = group.copyWith(
                  wheelSlots: slots,
                  activeSession: effSession,
                  clearActiveSession: effSession == null,
                );
                _saveLocalGroup(merged);
                _notifyGroupChanged(gid, merged);
              }
            }, onError: (_) {});
      } catch (_) {}
    }

    controller.onCancel = () {
      _groupControllers[gid]?.remove(controller);
      timer?.cancel();
      sub?.cancel();
    };

    yield* controller.stream;
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
            lastReadAt: getLocalLastReadAt(gid) ?? group.createdAt,
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
    if (local.isNotEmpty || (supabase == null && firestore == null)) {
      yield local;
    }

    if (supabase == null && firestore != null) {
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

    final controller = StreamController<List<GroupMemberModel>>.broadcast();
    _membersControllers.putIfAbsent(gid, () => []).add(controller);

    void Function(Map<String, dynamic>)? broadcastCb;
    Timer? timer;
    StreamSubscription? sub;

    if (supabase != null) {
      // 1. Dengarkan WebSocket Broadcast Realtime (< 50ms)
      broadcastCb = (payload) {
        final type = unwrapBroadcastEventPayload(payload)['type']?.toString();
        if (type == GroupEventType.memberJoin.value ||
            type == GroupEventType.memberLeave.value) {
          final cur = _getLocalMembers(gid);
          final clean = _cleanAndDeduplicate(gid, cur);
          if (!controller.isClosed) controller.add(clean);
          _notifyMembersChanged(gid, clean);
        }
      };
      _ensureChannel(gid, onBroadcastEvent: broadcastCb);

      // 2. Initial query from Supabase (non-blocking agar controller.stream langsung terpasang)
      unawaited(() async {
        try {
          final rows = await supabase!.from('group_members').select('*').eq('gid', gid).order('joined_at', ascending: true);
          final members = (rows as List).map((r) => GroupMemberModel.fromMap((r['uid'] ?? '').toString(), r)).toList();
          final clean = _cleanAndDeduplicate(gid, members);
          await _saveLocalMembers(gid, clean);
          _notifyMembersChanged(gid, clean);
        } catch (_) {}
      }());

      // 3. Fallback Periodic Polling (setiap 3 detik untuk latensi rendah)
      timer = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final rows = await supabase!.from('group_members').select('*').eq('gid', gid).order('joined_at', ascending: true);
          final members = (rows as List).map((r) => GroupMemberModel.fromMap((r['uid'] ?? '').toString(), r)).toList();
          final clean = _cleanAndDeduplicate(gid, members);
          await _saveLocalMembers(gid, clean);
          _notifyMembersChanged(gid, clean);
        } catch (_) {}
      });

      // 4. Postgres stream
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
    }

    controller.onCancel = () {
      _membersControllers[gid]?.remove(controller);
      if (broadcastCb != null) {
        _onBroadcastCallbacks.remove(broadcastCb);
      }
      timer?.cancel();
      sub?.cancel();
    };

    yield* controller.stream;
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
        'created_at': now.toUtc().toIso8601String(),
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
        'created_at': now.toUtc().toIso8601String(),
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

    await _clearEndedSessionMarker(gid);

    final session = GroupSessionModel(
      sessionId: sessionId,
      gid: gid,
      budget: fixedBudget,
      game: 'fixed',
      startedByUid: uid,
      startedByName: actorName,
      startedAt: now,
      budgetByUid: uid,
      budgetByName: actorName,
      status: 'running',
    );

    await upsertLocalSession(gid, session);

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
      if (sessionId.isNotEmpty) 'session_id': sessionId,
      'payload': {
        'sessionId': sessionId,
        'budget': fixedBudget,
        'startedByUid': uid,
        'startedByName': actorName,
        'type': 'fixed',
      },
      'created_at': now.toUtc().toIso8601String(),
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
          final currentLocal = _getLocalGroup(gid);
          final effSession = resolveEffectiveSession(gid, group.activeSession, currentLocal?.activeSession);
          final effSlots = group.wheelSlots ?? currentLocal?.wheelSlots;
          final merged = group.copyWith(
            activeSession: effSession,
            clearActiveSession: effSession == null,
            wheelSlots: effSlots,
          );
          await _saveLocalGroup(merged);
          _notifyGroupChanged(gid, merged);
          return merged;
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
          final currentLocal = _getLocalGroup(gid);
          final effSession = resolveEffectiveSession(gid, group.activeSession, currentLocal?.activeSession);
          final merged = group.copyWith(
            activeSession: effSession,
            clearActiveSession: effSession == null,
          );
          await _saveLocalGroup(merged);
          _notifyGroupChanged(gid, merged);
          return merged;
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
    await _clearEndedSessionMarker(gid);
    final enrichedSession = await upsertLocalSession(gid, session);
    final local = _getLocalGroup(gid);
    if (local != null) {
      final updatedGroup = local.copyWith(activeSession: enrichedSession);
      await _saveLocalGroup(updatedGroup);
      _notifyGroupChanged(gid, updatedGroup);
    }

    final evts = _getLocalEvents(gid);
    evts.insert(0, event);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final sid = event.sessionId.isNotEmpty ? event.sessionId : enrichedSession.sessionId;
      final eventMap = {
        'id': event.eventId,
        'gid': gid,
        'actor_uid': event.actorUid,
        'actor_name': event.actorName,
        'type': event.type.value,
        'summary': event.summary,
        if (sid.isNotEmpty) 'session_id': sid,
        'payload': event.payload,
        'created_at': event.createdAt.toUtc().toIso8601String(),
      };
      _broadcastGroupEvent(gid, eventMap);

      try {
        await Future.wait([
          supabase!.from('groups').update({
            'active_session': enrichedSession.toMap(),
          }).eq('id', gid),
          supabase!.from('group_events').insert(eventMap),
        ]);
        try {
          await supabase!.from('group_sessions').upsert({
            'id': enrichedSession.sessionId,
            'gid': gid,
            'started_at': enrichedSession.startedAt.toUtc().toIso8601String(),
            'started_by_uid': enrichedSession.startedByUid,
            'started_by_name': enrichedSession.startedByName,
            'budget': enrichedSession.budget,
            'game': enrichedSession.game,
            'budget_by_uid': enrichedSession.budgetByUid,
            'budget_by_name': enrichedSession.budgetByName,
            'detail': enrichedSession.detail,
            'status': enrichedSession.status,
            'total_spent': enrichedSession.totalSpent,
          });
        } catch (_) {}
      } catch (e) {
        debugPrint('[GroupService] saveSessionAndEvent Supabase error: $e');
      }
      return;
    }

    if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final sessionRef = groupRef.collection('sessions').doc(enrichedSession.sessionId);
        final eventRef = groupRef.collection('events').doc(event.eventId);
        final batch = firestore!.batch();

        batch.update(groupRef, {
          'activeSession': enrichedSession.toMap(),
        });
        batch.set(sessionRef, enrichedSession.toMap());
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
    await _clearEndedSessionMarker(gid);
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

  /// Mengakhiri / menutup sesi grup aktif secara idempoten
  /// (membekukan sesi ke riwayat & membuka kunci date grup tanpa duplikasi event).
  Future<GroupSessionModel?> endSession({required String gid}) {
    final existingFuture = _inFlightEndSessions[gid];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _endSessionInternal(gid: gid);
    _inFlightEndSessions[gid] = future;
    return future.whenComplete(() {
      if (_inFlightEndSessions[gid] == future) {
        _inFlightEndSessions.remove(gid);
      }
    });
  }

  Future<GroupSessionModel?> _endSessionInternal({required String gid}) async {
    final now = DateTime.now();
    final uid = authService.currentUid ?? '';
    final actorName = authService.displayName ?? 'Pemilik Grup';

    final local = _getLocalGroup(gid);
    final activeSess = local?.activeSession;
    final endedSessionId = activeSess?.sessionId ?? '';

    // Idempotency guard 1: tidak ada sesi aktif lagi -> jangan buat event ganda
    if (activeSess == null || endedSessionId.isEmpty) {
      return null;
    }

    // Idempotency guard 2: sesi ini sudah berakhir di riwayat lokal / penanda ended
    final alreadyFrozen = _findLocalSessionById(gid, endedSessionId);
    if (alreadyFrozen != null &&
        alreadyFrozen.isEnded &&
        alreadyFrozen.endedAt != null) {
      await _markSessionEnded(gid, endedSessionId, alreadyFrozen.endedAt!);
      if (local != null) {
        final updatedGroup = local.copyWith(clearActiveSession: true);
        await _saveLocalGroup(updatedGroup);
        _notifyGroupChanged(gid, updatedGroup);
      }
      return alreadyFrozen;
    }
    if (isSessionEnded(gid, activeSess)) {
      if (local != null) {
        final updatedGroup = local.copyWith(clearActiveSession: true);
        await _saveLocalGroup(updatedGroup);
        _notifyGroupChanged(gid, updatedGroup);
      }
      return alreadyFrozen;
    }

    // 1. Tandai sesi telah diakhiri agar tidak dihidupkan kembali oleh polling / failsafe
    await _markSessionEnded(gid, endedSessionId, now);

    // 1b. Bekukan dokumen sesi (TIDAK dihapus; hitung hasil & totalSpent saat selesai)
    GroupSessionModel? frozenSession;
    int noteCount = 0;
    {
      final allLocalNotes = _getLocalNotes(gid);
      bool migratedAny = false;
      final updatedAllNotes = allLocalNotes.map((n) {
        if (n.sessionId.isEmpty) {
          migratedAny = true;
          return n.copyWith(sessionId: endedSessionId);
        }
        return n;
      }).toList();
      if (migratedAny) {
        await _saveLocalNotes(gid, updatedAllNotes);
      }

      final sessionNotes = updatedAllNotes
          .where((n) => n.sessionId == endedSessionId)
          .toList();
      final sortedNotes =
          GroupHistoryCalculator.sortActiveNotesChronologically(sessionNotes);
      noteCount = sortedNotes.length;
      final totalSpent =
          sortedNotes.fold<int>(0, (sum, n) => sum + n.amount);
      final status = totalSpent <= activeSess.budget ? 'lolos' : 'lewat';
      frozenSession = activeSess.copyWith(
        gid: gid,
        endedAt: now,
        endedByUid: uid,
        endedByName: actorName,
        totalSpent: totalSpent,
        status: status,
        locked: true,
      );
      await upsertLocalSession(gid, frozenSession);
    }

    final statusLabel = frozenSession.isLolos ? 'Lolos' : 'Lewat';
    final hematVal = frozenSession.hemat;

    // 2. Catat event session_end ke log lokal terlebih dahulu (0ms Local-First)
    final endEvt = GroupEventModel(
      eventId: generateEventId(),
      type: GroupEventType.sessionEnd,
      actorUid: uid,
      actorName: actorName,
      summary: '$actorName menyelesaikan date: $statusLabel',
      payload: {
        'action': 'end_session',
        'sessionId': endedSessionId,
        'endedSessionId': endedSessionId,
        'endedAt': now.millisecondsSinceEpoch,
        'startedAt': frozenSession.startedAt.millisecondsSinceEpoch,
        'budget': frozenSession.budget,
        'totalSpent': frozenSession.totalSpent,
        'status': frozenSession.status,
        'game': frozenSession.game,
        'budgetByName': frozenSession.budgetByName.isNotEmpty
            ? frozenSession.budgetByName
            : frozenSession.startedByName,
        'endedByName': actorName,
        'endedByUid': uid,
        'hemat': hematVal,
        'noteCount': noteCount,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, endEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    // 3. Bersihkan activeSession di localGroup seketika & beri tahu seluruh UI (0ms delay)
    if (local != null) {
      final updatedGroup = local.copyWith(clearActiveSession: true);
      await _saveLocalGroup(updatedGroup);
      _notifyGroupChanged(gid, updatedGroup);
    }

    // 4. Siarkan ke seluruh anggota via WebSocket & update database di latar belakang
    if (supabase != null) {
      final endSid = endEvt.sessionId;
      final eventMap = {
        'id': endEvt.eventId,
        'gid': gid,
        'actor_uid': uid,
        'actor_name': actorName,
        'type': GroupEventType.sessionEnd.value,
        'summary': endEvt.summary,
        if (endSid.isNotEmpty) 'session_id': endSid,
        'payload': endEvt.payload,
        'created_at': now.toUtc().toIso8601String(),
      };
      _broadcastGroupEvent(gid, eventMap);
      final fs = frozenSession;
      unawaited(() async {
        try {
          final existingRemote = await supabase!
              .from('group_sessions')
              .select('id, status')
              .eq('id', fs.sessionId)
              .maybeSingle();
          final remoteAlreadyEnded = existingRemote != null &&
              existingRemote['status'] != null &&
              existingRemote['status'].toString() != 'running';

          await supabase!.from('groups').update({
            'active_session': null,
          }).eq('id', gid);

          if (!remoteAlreadyEnded) {
            await Future.wait([
              supabase!.from('group_events').insert(eventMap),
              supabase!.from('group_sessions').upsert({
                'id': fs.sessionId,
                'gid': gid,
                'started_at': fs.startedAt.toUtc().toIso8601String(),
                'started_by_uid': fs.startedByUid,
                'started_by_name': fs.startedByName,
                'ended_at': now.toUtc().toIso8601String(),
                'ended_by_uid': uid,
                'ended_by_name': actorName,
                'budget': fs.budget,
                'game': fs.game,
                'budget_by_uid': fs.budgetByUid,
                'budget_by_name': fs.budgetByName,
                'detail': fs.detail,
                'status': fs.status,
                'total_spent': fs.totalSpent,
              }),
            ]);
          }
        } catch (e) {
          debugPrint('[GroupService] endSession Supabase error: $e');
        }
      }());
    }

    if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final batch = firestore!.batch();
        batch.update(groupRef, {'activeSession': null});
        batch.set(
          groupRef.collection('sessions').doc(frozenSession.sessionId),
          frozenSession.toMap(),
        );
        batch.set(
          groupRef.collection('events').doc(endEvt.eventId),
          endEvt.toMap(),
        );
        await batch.commit();
      } catch (e) {
        debugPrint('[GroupService] endSession Firestore error: $e');
      }
    }

    return frozenSession;
  }

  /// Mencatat event tanpa mengubah activeSession (misal event race condition invalid)
  Future<void> recordEventOnly(String gid, GroupEventModel event) async {
    final evts = _getLocalEvents(gid);
    evts.insert(0, event);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final sid = event.sessionId;
      final eventMap = {
        'id': event.eventId,
        'gid': gid,
        'actor_uid': event.actorUid,
        'actor_name': event.actorName,
        'type': event.type.value,
        'summary': event.summary,
        if (sid.isNotEmpty) 'session_id': sid,
        'payload': event.payload,
        'created_at': event.createdAt.toUtc().toIso8601String(),
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

    final codeEvtId = generateEventId();
    final localEvt = GroupEventModel(
      eventId: codeEvtId,
      type: GroupEventType.codeChanged,
      actorUid: uid,
      actorName: actorName,
      summary: '$actorName memperbarui kode undangan grup',
      payload: {'code': newCode},
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    final codeEvtMap = {
      'id': codeEvtId,
      'gid': gid,
      'actor_uid': uid,
      'actor_name': actorName,
      'type': GroupEventType.codeChanged.value,
      'summary': '$actorName memperbarui kode undangan grup',
      'payload': {
        'code': newCode,
      },
      'created_at': now.toUtc().toIso8601String(),
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
      eventId: generateEventId(),
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
          'id': localEvt.eventId,
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
          'created_at': now.toUtc().toIso8601String(),
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

        final eventRef = groupRef.collection('events').doc(localEvt.eventId);
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
      eventId: generateEventId(),
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
          'created_at': now.toUtc().toIso8601String(),
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

  /// Menambah catatan pengeluaran grup (Append-only).
  /// Mendukung aturan sinkronisasi catatan offline hingga 24 jam setelah sesi berakhir:
  /// - Jika [clientCreatedAt] <= `endedAt` dan disinkronkan <= 24 jam pasca `endedAt`,
  ///   catatan tetap diterima, sesi dihitung ulang, dan event `"Hasil date diperbarui"` ditulis.
  /// - Jika > 24 jam pasca `endedAt` atau dibuat setelah `endedAt`, permintaan ditolak.
  Future<void> _setNotePendingFlag(
    String gid,
    String noteId, {
    required bool pending,
  }) async {
    final notes = _getLocalNotes(gid);
    final idx = notes.indexWhere((n) => n.noteId == noteId);
    if (idx == -1 || notes[idx].hasPendingWrites == pending) return;
    notes[idx] = notes[idx].copyWith(hasPendingWrites: pending);
    await _saveLocalNotes(gid, notes);
    _notifyNotesChanged(gid, notes);
  }

  Future<void> _syncAddedNoteToRemote({
    required String gid,
    required String noteId,
    required String sessionId,
    required String uid,
    required String authorName,
    required String cleanTitle,
    required int amount,
    required DateTime noteTime,
    required bool isLateOfflineSync,
    required GroupSessionModel? recalculatedSession,
    required Map<String, dynamic> evtMap,
  }) async {
    if (supabase == null || _disposed) return;
    const reqTimeout = Duration(seconds: 8);
    try {
      await supabase!.from('group_notes').insert({
        'id': noteId,
        'gid': gid,
        'session_id': sessionId,
        'author_uid': uid,
        'author_name': authorName,
        'title': cleanTitle,
        'amount': amount,
        'created_at': noteTime.toUtc().toIso8601String(),
        'deleted': false,
      }).timeout(reqTimeout);

      await _setNotePendingFlag(gid, noteId, pending: false);

      if (isLateOfflineSync && recalculatedSession != null) {
        try {
          await supabase!
              .from('group_sessions')
              .update({
                'total_spent': recalculatedSession.totalSpent,
                'status': recalculatedSession.status,
              })
              .eq('id', recalculatedSession.sessionId)
              .timeout(reqTimeout);
        } catch (_) {}
      }

      await supabase!.from('group_events').insert(evtMap).timeout(reqTimeout);
      _broadcastGroupEvent(gid, evtMap);
    } catch (e) {
      debugPrint('[GroupService] Supabase addNote background sync error: $e');
    }
  }

  Future<void> _syncUpdatedNoteToRemote({
    required String gid,
    required String noteId,
    required String cleanTitle,
    required int newAmount,
    required GroupSessionModel? recalculatedSession,
    required Map<String, dynamic> evtMap,
  }) async {
    if (supabase == null || _disposed) return;
    const reqTimeout = Duration(seconds: 8);
    try {
      await supabase!
          .from('group_notes')
          .update({
            'title': cleanTitle,
            'amount': newAmount,
          })
          .eq('id', noteId)
          .timeout(reqTimeout);

      await _setNotePendingFlag(gid, noteId, pending: false);

      if (recalculatedSession != null) {
        try {
          await supabase!
              .from('group_sessions')
              .update({
                'total_spent': recalculatedSession.totalSpent,
                'status': recalculatedSession.status,
              })
              .eq('id', recalculatedSession.sessionId)
              .timeout(reqTimeout);
        } catch (_) {}
      }

      await supabase!.from('group_events').insert(evtMap).timeout(reqTimeout);
      _broadcastGroupEvent(gid, evtMap);
    } catch (e) {
      debugPrint('[GroupService] Supabase updateNote background sync error: $e');
    }
  }

  Future<String> addNote({
    required String gid,
    required String sessionId,
    required String title,
    required int amount,
    int? sessionBudget,
    DateTime? clientCreatedAt,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Nama barang tidak boleh kosong.');
    }
    if (amount <= 0) {
      throw ArgumentError('Nominal harus lebih dari 0.');
    }

    final syncTime = DateTime.now();
    final uid = authService.currentUid ??
        await authService.ensureSignedIn().timeout(
              const Duration(seconds: 4),
              onTimeout: () =>
                  authService.fallbackUid ??
                  'anon_local_${syncTime.millisecondsSinceEpoch}',
            );
    final authorName = authService.displayName ?? 'Anggota';
    final noteTime = clientCreatedAt ?? syncTime;
    final noteId = 'note_${syncTime.millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    final groupBeforeSave = _getLocalGroup(gid);
    final activeSess = groupBeforeSave?.activeSession;
    final isActiveCurrentSession = activeSess != null &&
        activeSess.sessionId == sessionId &&
        activeSess.endedAt == null &&
        !isSessionEnded(gid, activeSess);
    final existingSession = _findLocalSessionById(gid, sessionId);
    bool isLateOfflineSync = false;
    if (!isActiveCurrentSession &&
        existingSession != null &&
        existingSession.endedAt != null) {
      final endedAt = existingSession.endedAt!;
      if (noteTime.isAfter(endedAt)) {
        throw StateError(
          'Date sudah selesai. Buat date baru untuk mencatat pengeluaran.',
        );
      }
      if (syncTime.difference(endedAt) > const Duration(hours: 24)) {
        throw StateError(
          'Catatan offline melewati batas 24 jam setelah date selesai.',
        );
      }
      isLateOfflineSync = true;
    }

    final localNote = GroupNoteModel(
      noteId: noteId,
      sessionId: sessionId,
      authorUid: uid,
      authorName: authorName,
      title: cleanTitle,
      amount: amount,
      createdAt: noteTime,
      deleted: false,
      hasPendingWrites: supabase != null,
    );

    final notes = _getLocalNotes(gid)..insert(0, localNote);
    await _saveLocalNotes(gid, notes);

    // Hitung ulang totalSpent & status pada sesi terkait
    GroupSessionModel? recalculatedSession;
    final sessions = _getLocalSessions(gid);
    final sIdx = sessions.indexWhere((s) => s.sessionId == sessionId);
    if (sIdx != -1) {
      recalculatedSession = await upsertLocalSession(gid, sessions[sIdx]);
    } else if (existingSession != null) {
      recalculatedSession = await upsertLocalSession(gid, existingSession);
    }

    final group = _getLocalGroup(gid);
    final matchedSessionBudget = sessions
        .where((s) => s.sessionId == sessionId && s.budget > 0)
        .map((s) => s.budget)
        .firstOrNull;
    final resolvedBudget = (sessionBudget != null && sessionBudget > 0)
        ? sessionBudget
        : ((group?.activeSession?.sessionId == sessionId &&
                (group?.activeSession?.budget ?? 0) > 0)
            ? group!.activeSession!.budget
            : (matchedSessionBudget ??
                ((group?.activeSession?.budget ?? 0) > 0
                    ? group!.activeSession!.budget
                    : (_recoverSessionBudgetFromEvents(gid, sessionId) ?? 0))));
    final totalBudget = resolvedBudget;
    final currentNotes = _getLocalNotes(gid).where((n) => n.sessionId == sessionId && !n.deleted).toList();
    final currentSpent = currentNotes.fold<int>(0, (total, n) => total + n.amount);
    final remaining = totalBudget - currentSpent;

    final evtId = generateEventId();
    final evtPayload = <String, dynamic>{
      'noteId': noteId,
      'title': cleanTitle,
      'amount': amount,
      'budget': totalBudget,
      'spent': currentSpent,
      'remaining': remaining,
      'sessionId': sessionId,
      if (isLateOfflineSync) 'lateOfflineSync': true,
    };

    final localEvt = GroupEventModel(
      eventId: evtId,
      type: GroupEventType.expense,
      actorUid: uid,
      actorName: authorName,
      summary: '$authorName mencatat "$cleanTitle" (${RupiahFormatter.format(amount)})',
      payload: evtPayload,
      createdAt: noteTime,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);

    _notifyNotesChanged(gid, notes);
    _notifyEventsChanged(gid, evts);

    if (isLateOfflineSync && recalculatedSession != null) {
      await _emitEndedSessionRecalculatedEvent(
        gid: gid,
        session: recalculatedSession,
        actorUid: uid,
        actorName: authorName,
        lateOfflineSync: true,
      );
    }

    if (supabase != null) {
      final evtMap = {
        'id': evtId,
        'gid': gid,
        'actor_uid': uid,
        'actor_name': authorName,
        'type': GroupEventType.expense.value,
        'summary': '$authorName mencatat "$cleanTitle" (${RupiahFormatter.format(amount)})',
        if (sessionId.isNotEmpty) 'session_id': sessionId,
        'payload': evtPayload,
        'created_at': noteTime.toUtc().toIso8601String(),
      };
      unawaited(
        _syncAddedNoteToRemote(
          gid: gid,
          noteId: noteId,
          sessionId: sessionId,
          uid: uid,
          authorName: authorName,
          cleanTitle: cleanTitle,
          amount: amount,
          noteTime: noteTime,
          isLateOfflineSync: isLateOfflineSync,
          recalculatedSession: recalculatedSession,
          evtMap: evtMap,
        ),
      );
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
          'createdAt': noteTime.millisecondsSinceEpoch,
          'deleted': false,
        });

        if (isLateOfflineSync && recalculatedSession != null) {
          batch.set(
            firestore!
                .collection('groups')
                .doc(gid)
                .collection('sessions')
                .doc(recalculatedSession.sessionId),
            recalculatedSession.toMap(),
          );
        }

        final eventRef = firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .doc(evtId);

        batch.set(eventRef, {
          'id': evtId,
          'actorUid': uid,
          'actorName': authorName,
          'type': GroupEventType.expense.value,
          'summary': '$authorName mencatat "$cleanTitle" (${RupiahFormatter.format(amount)})',
          'payload': evtPayload,
          'timestamp': noteTime.millisecondsSinceEpoch,
        });

        await batch.commit();
      } catch (_) {}
    }

    return noteId;
  }

  /// Memantau catatan pengeluaran grup secara realtime (Local-First + Stream + Polling)
  Stream<List<GroupNoteModel>> watchNotes(String gid, String sessionId) async* {
    List<GroupNoteModel> filterNotes(List<GroupNoteModel> all) {
      if (sessionId.isEmpty) return all.where((n) => !n.deleted).toList();
      return all.where((n) => !n.deleted && (n.sessionId == sessionId || n.sessionId.isEmpty)).toList();
    }

    final initialLocal = filterNotes(_getLocalNotes(gid));
    yield initialLocal;

    final rawController = StreamController<List<GroupNoteModel>>.broadcast();
    final streamController = StreamController<List<GroupNoteModel>>.broadcast();
    _notesControllers.putIfAbsent(gid, () => []).add(rawController);

    final rawSub = rawController.stream.listen((allNotes) {
      final filtered = filterNotes(allNotes);
      if (!streamController.isClosed) {
        streamController.add(filtered);
      }
    });

    Timer? timer;
    StreamSubscription? sub;

    if (supabase != null) {
      _ensureChannel(gid);

      Future<void> mergeAndEmit(List<GroupNoteModel> remoteNotes) async {
        final existing = _getLocalNotes(gid);
        final existingMap = {for (final n in existing) n.noteId: n};
        final mergedMap = <String, GroupNoteModel>{};
        for (final r in remoteNotes) {
          final loc = existingMap[r.noteId];
          if (loc != null && loc.deleted && !r.deleted) {
            // Tombstone lokal lebih baru dari remote yang belum sync delete
            mergedMap[r.noteId] = loc;
          } else {
            mergedMap[r.noteId] = r;
          }
        }
        for (final loc in existing) {
          if (!mergedMap.containsKey(loc.noteId)) {
            mergedMap[loc.noteId] = loc;
          }
        }
        final merged = mergedMap.values.toList();
        await _saveLocalNotes(gid, merged);
        final filtered = filterNotes(merged);
        if (!streamController.isClosed) {
          streamController.add(filtered);
        }
      }

      // Jalankan initial fetch non-blocking agar streamController langsung terpasang (0ms delay)
      unawaited(() async {
        try {
          final rows = await supabase!
              .from('group_notes')
              .select('*')
              .eq('gid', gid)
              .order('created_at', ascending: false);
          final notes = (rows as List)
              .map((r) => GroupNoteModel.fromMap(r['id']?.toString() ?? '', r))
              .toList();
          await mergeAndEmit(notes);
        } catch (_) {}
      }());

      timer = Timer.periodic(const Duration(seconds: 10), (_) async {
        try {
          final rows = await supabase!
              .from('group_notes')
              .select('*')
              .eq('gid', gid)
              .order('created_at', ascending: false);
          final notes = (rows as List)
              .map((r) => GroupNoteModel.fromMap(r['id']?.toString() ?? '', r))
              .toList();
          await mergeAndEmit(notes);
        } catch (_) {}
      });

      try {
        sub = supabase!
            .from('group_notes')
            .stream(primaryKey: ['id'])
            .eq('gid', gid)
            .order('created_at', ascending: false)
            .listen((rows) {
              final notes = rows
                  .map((r) => GroupNoteModel.fromMap(r['id']?.toString() ?? '', r))
                  .toList();
              mergeAndEmit(notes);
            }, onError: (_) {});
      } catch (_) {}
    }

    streamController.onCancel = () {
      _notesControllers[gid]?.remove(rawController);
      rawSub.cancel();
      rawController.close();
      timer?.cancel();
      sub?.cancel();
    };

    yield* streamController.stream;
  }

  /// Evaluasi aturan izin Ubah & Hapus catatan (H4 Security Rules):
  /// Hanya pembuat catatan (authorUid) atau pemilik grup (ownerUid) yang boleh mengubah atau menghapus.
  bool canModifyNote({
    required GroupModel? group,
    required GroupNoteModel note,
    String? userUid,
  }) {
    final uid = userUid ?? authService.currentUid ?? '';
    if (uid.isEmpty) return false;
    if (note.authorUid == uid || authService.isCurrentUser(note.authorUid)) {
      return true;
    }
    if (group != null &&
        (group.ownerUid == uid || authService.isCurrentUser(group.ownerUid))) {
      return true;
    }
    return false;
  }

  /// Evaluasi aturan izin perubahan langsung pada dokumen sesi (H4 Security Rules):
  /// Sesi yang sedang berjalan boleh diperbarui anggota grup; sesi yang sudah berakhir
  /// TIDAK boleh diubah kecuali oleh pemilik grup (ownerUid).
  bool canModifySession({
    required GroupModel? group,
    required GroupSessionModel session,
    String? userUid,
  }) {
    final uid = userUid ?? authService.currentUid ?? '';
    if (uid.isEmpty) return false;
    if (!session.isEnded) {
      return true;
    }
    if (group != null &&
        (group.ownerUid == uid || authService.isCurrentUser(group.ownerUid))) {
      return true;
    }
    return false;
  }

  /// Mengubah sesi yang sudah berakhir (hanya diizinkan untuk pemilik grup),
  /// menghitung ulang totalSpent & status, lalu menulis event perubahan.
  Future<GroupSessionModel> updateEndedSession({
    required String gid,
    required GroupSessionModel session,
    int? newBudget,
  }) async {
    final myUid = authService.currentUid ?? await authService.ensureSignedIn();
    final myName = authService.displayName ?? 'Pemilik Grup';
    final group = _getLocalGroup(gid);
    if (!canModifySession(group: group, session: session, userUid: myUid)) {
      throw StateError(
        'Sesi yang sudah berakhir hanya bisa diubah oleh pemilik grup.',
      );
    }

    final updatedTarget = newBudget != null && newBudget > 0
        ? session.copyWith(budget: newBudget)
        : session;
    final recalculated = await upsertLocalSession(gid, updatedTarget);

    final now = DateTime.now();
    final localEvt = GroupEventModel(
      eventId: generateEventId(),
      type: GroupEventType.budgetChanged,
      actorUid: myUid,
      actorName: myName,
      summary:
          '$myName memperbarui sesi date (${RupiahFormatter.format(recalculated.budget)})',
      payload: {
        'sessionId': recalculated.sessionId,
        'budget': recalculated.budget,
        'totalSpent': recalculated.totalSpent,
        'status': recalculated.status,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);
    return recalculated;
  }

  Future<void> _emitEndedSessionRecalculatedEvent({
    required String gid,
    required GroupSessionModel session,
    required String actorUid,
    required String actorName,
    bool lateOfflineSync = false,
  }) async {
    final now = DateTime.now();
    final statusLabel = session.isLolos ? 'Lolos' : 'Lewat';
    final summary =
        'Hasil date diperbarui: $statusLabel (${RupiahFormatter.format(session.totalSpent)})';
    final evtPayload = <String, dynamic>{
      'action': 'session_result_updated',
      'sessionId': session.sessionId,
      'status': session.status,
      'totalSpent': session.totalSpent,
      'budget': session.budget,
      'subtitle': summary,
      if (lateOfflineSync) 'lateOfflineSync': true,
    };
    final evt = GroupEventModel(
      eventId: generateEventId(),
      type: GroupEventType.custom,
      actorUid: actorUid,
      actorName: actorName,
      summary: summary,
      payload: evtPayload,
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, evt);
    await _saveLocalEvents(gid, evts);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      try {
        final evtMap = {
          'id': evt.eventId,
          'gid': gid,
          'actor_uid': actorUid,
          'actor_name': actorName,
          'type': GroupEventType.custom.value,
          'summary': summary,
          if (session.sessionId.isNotEmpty) 'session_id': session.sessionId,
          'payload': evtPayload,
          'created_at': now.toUtc().toIso8601String(),
        };
        await supabase!.from('group_events').insert(evtMap);
        _broadcastGroupEvent(gid, evtMap);
      } catch (_) {}
    }

    if (firestore != null) {
      try {
        await firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .doc(evt.eventId)
            .set(evt.toMap());
      } catch (_) {}
    }
  }

  Future<GroupSessionModel?> _recalculateSessionForNoteMutation(
    String gid,
    String targetSessionId,
    GroupModel? group,
  ) async {
    if (targetSessionId.isEmpty) return null;
    final sessions = _getLocalSessions(gid);
    final sIdx = sessions.indexWhere((s) => s.sessionId == targetSessionId);
    GroupSessionModel? baseSession;
    if (sIdx != -1) {
      baseSession = sessions[sIdx];
    } else if (group?.activeSession?.sessionId == targetSessionId) {
      baseSession = group!.activeSession;
    } else {
      final migrated = await getGroupSessionsWithMigration(gid);
      final mIdx = migrated.indexWhere((s) => s.sessionId == targetSessionId);
      if (mIdx != -1) {
        baseSession = migrated[mIdx];
      }
    }
    if (baseSession == null) return null;
    final recalculated = await upsertLocalSession(gid, baseSession);
    if (group?.activeSession != null &&
        group!.activeSession!.sessionId == recalculated.sessionId) {
      await _saveLocalGroup(group.copyWith(activeSession: recalculated));
    }
    return recalculated;
  }

  /// Mengubah catatan pengeluaran grup yang sudah ada (dengan aturan izin author atau ownerUid)
  /// dan menghitung ulang totalSpent serta status sesi bila sesi sudah berakhir.
  Future<GroupNoteModel> updateNote({
    required String gid,
    required String noteId,
    required String newTitle,
    required int newAmount,
    int? sessionBudget,
  }) async {
    final cleanTitle = newTitle.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Nama barang tidak boleh kosong.');
    }
    if (newAmount <= 0) {
      throw ArgumentError('Nominal harus lebih dari 0.');
    }

    final myUid = authService.currentUid ?? await authService.ensureSignedIn();
    final myName = authService.displayName ?? 'Anggota';
    final now = DateTime.now();

    final group = _getLocalGroup(gid);
    final notes = _getLocalNotes(gid);
    final idx = notes.indexWhere((n) => n.noteId == noteId);
    if (idx == -1) {
      throw StateError('Catatan tidak ditemukan.');
    }

    final existingNote = notes[idx];
    if (!canModifyNote(group: group, note: existingNote, userUid: myUid)) {
      throw StateError(
        'Hanya ${existingNote.authorName} dan pemilik grup yang bisa mengubah atau menghapus.',
      );
    }

    final targetSessionId = existingNote.sessionId;
    final updatedNote = existingNote.copyWith(
      title: cleanTitle,
      amount: newAmount,
      hasPendingWrites: supabase != null,
    );
    notes[idx] = updatedNote;
    await _saveLocalNotes(gid, notes);

    // Hitung ulang totalSpent & status pada sesi terkait (termasuk jika sesi sudah berakhir)
    final recalculatedSession = await _recalculateSessionForNoteMutation(
      gid,
      targetSessionId,
      group,
    );

    final totalBudget = (sessionBudget != null && sessionBudget > 0)
        ? sessionBudget
        : (recalculatedSession?.budget ??
            ((group?.activeSession?.budget ?? 0) > 0
                ? group!.activeSession!.budget
                : (_recoverSessionBudgetFromEvents(gid, targetSessionId) ?? 0)));

    final remainingNotes = notes
        .where(
          (n) =>
              !n.deleted &&
              (targetSessionId.isEmpty || n.sessionId == targetSessionId),
        )
        .toList();
    final currentSpent =
        remainingNotes.fold<int>(0, (total, n) => total + n.amount);
    final remaining = totalBudget - currentSpent;

    final localEvt = GroupEventModel(
      eventId: generateEventId(),
      type: GroupEventType.expense,
      actorUid: myUid,
      actorName: myName,
      summary:
          '$myName mengubah catatan "$cleanTitle" (${RupiahFormatter.format(newAmount)})',
      payload: {
        'noteId': noteId,
        'title': cleanTitle,
        'amount': newAmount,
        'budget': totalBudget,
        'spent': currentSpent,
        'remaining': remaining,
        'sessionId': targetSessionId,
        'edited': true,
      },
      createdAt: now,
    );
    final evts = _getLocalEvents(gid)..insert(0, localEvt);
    await _saveLocalEvents(gid, evts);

    _notifyNotesChanged(gid, notes);
    _notifyEventsChanged(gid, evts);

    if (supabase != null) {
      final evtMap = {
        'id': localEvt.eventId,
        'gid': gid,
        'actor_uid': myUid,
        'actor_name': myName,
        'type': GroupEventType.expense.value,
        'summary': localEvt.summary,
        if (targetSessionId.isNotEmpty) 'session_id': targetSessionId,
        'payload': localEvt.payload,
        'created_at': now.toUtc().toIso8601String(),
      };
      unawaited(
        _syncUpdatedNoteToRemote(
          gid: gid,
          noteId: noteId,
          cleanTitle: cleanTitle,
          newAmount: newAmount,
          recalculatedSession: recalculatedSession,
          evtMap: evtMap,
        ),
      );
    }

    if (firestore != null) {
      try {
        final groupRef = firestore!.collection('groups').doc(gid);
        final batch = firestore!.batch();
        batch.update(groupRef.collection('notes').doc(noteId), {
          'title': cleanTitle,
          'amount': newAmount,
        });
        if (recalculatedSession != null) {
          batch.set(
            groupRef.collection('sessions').doc(recalculatedSession.sessionId),
            recalculatedSession.toMap(),
          );
        }
        batch.set(
          groupRef.collection('events').doc(localEvt.eventId),
          localEvt.toMap(),
        );
        await batch.commit();
      } catch (_) {}
    }

    return updatedNote;
  }

  /// Menghapus catatan pengeluaran menggunakan Tombstone (deleted = true),
  /// memeriksa aturan izin (author atau ownerUid), menulis event expense_deleted,
  /// dan menghitung ulang totalSpent serta status sesi.
  Future<void> deleteNote({
    required String gid,
    required String noteId,
    required String title,
    required int amount,
    int? sessionBudget,
  }) async {
    final myUid = authService.currentUid ?? '';
    final myName = authService.displayName ?? 'Anggota';
    final now = DateTime.now();

    final group = _getLocalGroup(gid);
    final notes = _getLocalNotes(gid);
    final idx = notes.indexWhere((n) => n.noteId == noteId);
    String targetSessionId = '';
    if (idx != -1) {
      final existingNote = notes[idx];
      if (!canModifyNote(group: group, note: existingNote, userUid: myUid)) {
        throw StateError(
          'Hanya ${existingNote.authorName} dan pemilik grup yang bisa mengubah atau menghapus.',
        );
      }
      targetSessionId = existingNote.sessionId;
      notes[idx] = existingNote.copyWith(deleted: true);
      await _saveLocalNotes(gid, notes);
    }

    // Hitung ulang totalSpent & status pada sesi terkait (termasuk bila sesi sudah berakhir)
    final recalculatedSession = await _recalculateSessionForNoteMutation(
      gid,
      targetSessionId,
      group,
    );

    final totalBudget = (sessionBudget != null && sessionBudget > 0)
        ? sessionBudget
        : (recalculatedSession?.budget ??
            ((group?.activeSession?.budget ?? 0) > 0
                ? group!.activeSession!.budget
                : (_recoverSessionBudgetFromEvents(gid, targetSessionId) ?? 0)));
    final remainingNotes = notes
        .where((n) => !n.deleted && (targetSessionId.isEmpty || n.sessionId == targetSessionId))
        .toList();
    final currentSpent = remainingNotes.fold<int>(0, (total, n) => total + n.amount);
    final remaining = totalBudget - currentSpent;

    final localEvt = GroupEventModel(
      eventId: generateEventId(),
      type: GroupEventType.expenseDeleted,
      actorUid: myUid,
      actorName: myName,
      summary: '$myName menghapus pengeluaran "$title" (${RupiahFormatter.format(amount)})',
      payload: {
        'noteId': noteId,
        'title': title,
        'amount': amount,
        'budget': totalBudget,
        'spent': currentSpent,
        'remaining': remaining,
        'deleted': true,
        'sessionId': targetSessionId,
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

        if (recalculatedSession != null) {
          try {
            await supabase!
                .from('group_sessions')
                .update({
                  'total_spent': recalculatedSession.totalSpent,
                  'status': recalculatedSession.status,
                })
                .eq('id', recalculatedSession.sessionId);
          } catch (_) {}
        }

        final evtMap = {
          'id': localEvt.eventId,
          'gid': gid,
          'actor_uid': myUid,
          'actor_name': myName,
          'type': GroupEventType.expenseDeleted.value,
          'summary': '$myName menghapus pengeluaran "$title" (${RupiahFormatter.format(amount)})',
          if (targetSessionId.isNotEmpty) 'session_id': targetSessionId,
          'payload': {
            'noteId': noteId,
            'title': title,
            'amount': amount,
            'budget': totalBudget,
            'spent': currentSpent,
            'remaining': remaining,
            'deleted': true,
            'sessionId': targetSessionId,
          },
          'created_at': now.toUtc().toIso8601String(),
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
        if (recalculatedSession != null) {
          batch.set(
            firestore!
                .collection('groups')
                .doc(gid)
                .collection('sessions')
                .doc(recalculatedSession.sessionId),
            recalculatedSession.toMap(),
          );
        }

        final eventRef = firestore!
            .collection('groups')
            .doc(gid)
            .collection('events')
            .doc(localEvt.eventId);

        batch.set(eventRef, {
          'actorUid': myUid,
          'actorName': myName,
          'type': GroupEventType.expenseDeleted.value,
          'summary': '$myName menghapus pengeluaran "$title" (${RupiahFormatter.format(amount)})',
          'payload': localEvt.payload,
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
    await _clearEndedSessionMarker(gid);

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
          if (effectiveSessionId.isNotEmpty) 'session_id': effectiveSessionId,
          'payload': {
            'budget': budget,
            'sessionId': effectiveSessionId,
          },
          'created_at': now.toUtc().toIso8601String(),
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
      final evtMap = unwrapBroadcastEventPayload(rawPayload);
      final evtId = (evtMap['id'] ?? evtMap['eventId'] ?? '').toString();
      if (evtId.isEmpty && evtMap['type'] == null) return;
      final newEvt = GroupEventModel.fromMap(evtId, evtMap);

      // 1. Simpan ke riwayat event lokal secara serial agar broadcast & postgresChanges tidak balapan
      await _enqueueEventWrite(gid, () async {
        final currentEvents = _getLocalEvents(gid);
        final existingIdx = newEvt.eventId.isNotEmpty
            ? currentEvents.indexWhere((e) => e.eventId == newEvt.eventId)
            : -1;
        if (existingIdx == -1) {
          currentEvents.insert(0, newEvt);
          await _saveLocalEvents(gid, currentEvents);
        } else {
          final existing = currentEvents[existingIdx];
          if (existing.summary != newEvt.summary ||
              existing.type != newEvt.type ||
              jsonEncode(existing.payload) != jsonEncode(newEvt.payload)) {
            currentEvents[existingIdx] = newEvt;
            await _saveLocalEvents(gid, currentEvents);
          }
        }
      });

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

      // 4. Realtime Expense Added / Edited (< 50ms)
      if (newEvt.type == GroupEventType.expense && newEvt.payload['deleted'] != true) {
        final noteId = newEvt.payload['noteId']?.toString();
        final sessId = newEvt.payload['sessionId']?.toString() ?? '';
        final title = newEvt.payload['title']?.toString() ?? '';
        final amount = (newEvt.payload['amount'] as num?)?.toInt() ?? 0;
        if (noteId != null && noteId.isNotEmpty && amount > 0) {
          final curNotes = _getLocalNotes(gid);
          final existingIdx = curNotes.indexWhere((n) => n.noteId == noteId);
          if (existingIdx == -1) {
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
          } else {
            curNotes[existingIdx] = curNotes[existingIdx].copyWith(
              title: title,
              amount: amount,
            );
            await _saveLocalNotes(gid, curNotes);
            _notifyNotesChanged(gid, curNotes);
          }
          final sessions = _getLocalSessions(gid);
          final sIdx = sessions.indexWhere((s) => s.sessionId == sessId);
          if (sIdx != -1) {
            await upsertLocalSession(gid, sessions[sIdx]);
          }
        }
      }

      // 5. Realtime Expense Deleted (< 50ms)
      if ((newEvt.type == GroupEventType.expense && newEvt.payload['deleted'] == true) ||
          newEvt.type == GroupEventType.expenseDeleted) {
        final noteId = newEvt.payload['noteId']?.toString();
        if (noteId != null && noteId.isNotEmpty) {
          final curNotes = _getLocalNotes(gid);
          final idx = curNotes.indexWhere((n) => n.noteId == noteId);
          if (idx != -1 && !curNotes[idx].deleted) {
            final targetSid = curNotes[idx].sessionId;
            curNotes[idx] = curNotes[idx].copyWith(deleted: true);
            await _saveLocalNotes(gid, curNotes);
            _notifyNotesChanged(gid, curNotes);
            final sessions = _getLocalSessions(gid);
            final sIdx = sessions.indexWhere((s) => s.sessionId == targetSid);
            if (sIdx != -1) {
              await upsertLocalSession(gid, sessions[sIdx]);
            }
          }
        }
      }

      // 6. Realtime Session Start (< 50ms)
      if (newEvt.type == GroupEventType.sessionStart &&
          newEvt.payload['sessionId'] != null &&
          newEvt.payload['budget'] != null) {
        await _clearEndedSessionMarker(gid);
        final sessId = newEvt.payload['sessionId'].toString();
        final budget = (newEvt.payload['budget'] as num).toInt();
        final startedByUid = newEvt.payload['startedByUid']?.toString() ?? newEvt.actorUid;
        final startedByName = newEvt.payload['startedByName']?.toString() ?? newEvt.actorName;
        final session = GroupSessionModel(
          sessionId: sessId,
          gid: gid,
          budget: budget,
          game: newEvt.payload['type']?.toString() ?? 'fixed',
          startedByUid: startedByUid,
          startedByName: startedByName,
          startedAt: newEvt.createdAt,
          budgetByUid: startedByUid,
          budgetByName: startedByName,
          status: 'running',
        );
        await upsertLocalSession(gid, session);
        final cur = _getLocalGroup(gid);
        if (cur != null) {
          final updated = cur.copyWith(activeSession: session);
          await _saveLocalGroup(updated);
          _notifyGroupChanged(gid, updated);
        }
      }

      // 6b. Realtime End Session (< 50ms)
      if (newEvt.type == GroupEventType.sessionEnd ||
          newEvt.payload['action'] == 'end_session') {
        final endedSid =
            (newEvt.payload['endedSessionId'] ?? newEvt.payload['sessionId'])
                    ?.toString() ??
                '';
        await _markSessionEnded(gid, endedSid, newEvt.createdAt);
        final cur = _getLocalGroup(gid);
        final activeSess = cur?.activeSession;
        final sessions = _getLocalSessions(gid);
        final sIdx = sessions.indexWhere((s) => s.sessionId == endedSid);
        final baseSess = sIdx != -1 ? sessions[sIdx] : activeSess;
        final payloadBudget = (newEvt.payload['budget'] as num?)?.toInt() ?? 0;
        final payloadSpent =
            (newEvt.payload['totalSpent'] as num?)?.toInt() ?? 0;
        final payloadStatus = newEvt.payload['status']?.toString();
        final payloadStartedMs = (newEvt.payload['startedAt'] as num?)?.toInt();

        if (baseSess != null && baseSess.sessionId.isNotEmpty) {
          final resolvedSpent = baseSess.totalSpent > 0
              ? baseSess.totalSpent
              : payloadSpent;
          final resolvedStatus = payloadStatus ??
              (resolvedSpent <= baseSess.budget ? 'lolos' : 'lewat');
          final frozen = baseSess.copyWith(
            gid: gid,
            endedAt: newEvt.createdAt,
            endedByUid: newEvt.actorUid,
            endedByName: newEvt.actorName,
            totalSpent: resolvedSpent,
            status: resolvedStatus,
            locked: true,
          );
          await upsertLocalSession(gid, frozen);
        } else if (endedSid.isNotEmpty && payloadBudget > 0) {
          final syntheticSession = GroupSessionModel(
            sessionId: endedSid,
            gid: gid,
            budget: payloadBudget,
            game: newEvt.payload['game']?.toString() ?? 'wheel',
            startedByUid: newEvt.actorUid,
            startedByName: newEvt.payload['budgetByName']?.toString() ??
                newEvt.actorName,
            startedAt: payloadStartedMs != null
                ? DateTime.fromMillisecondsSinceEpoch(payloadStartedMs)
                : newEvt.createdAt,
            endedAt: newEvt.createdAt,
            endedByUid: newEvt.actorUid,
            endedByName: newEvt.actorName,
            budgetByUid: newEvt.actorUid,
            budgetByName: newEvt.payload['budgetByName']?.toString() ??
                newEvt.actorName,
            status: payloadStatus ??
                (payloadSpent <= payloadBudget ? 'lolos' : 'lewat'),
            totalSpent: payloadSpent,
            locked: true,
          );
          await upsertLocalSession(gid, syntheticSession);
        }
        if (cur != null) {
          final updated = cur.copyWith(clearActiveSession: true);
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
      if ((newEvt.type == GroupEventType.gameResult || newEvt.type == GroupEventType.spin) &&
          newEvt.payload['valid'] != false &&
          (newEvt.payload['amount'] != null || newEvt.payload['budget'] != null)) {
        await _clearEndedSessionMarker(gid);
        final amount = ((newEvt.payload['amount'] ?? newEvt.payload['budget']) as num).toInt();
        final game = newEvt.payload['game']?.toString() ?? 'wheel';
        final sessId = newEvt.payload['sessionId']?.toString() ??
            'sess_${newEvt.createdAt.millisecondsSinceEpoch}';
        final cur = _getLocalGroup(gid);
        if (cur != null) {
          final isLocked = cur.lockPolicy == 'lock';
          final newSession = GroupSessionModel(
            sessionId: sessId,
            gid: gid,
            budget: amount,
            game: game,
            startedByUid: newEvt.actorUid,
            startedByName: newEvt.actorName,
            startedAt: newEvt.createdAt,
            budgetByUid: newEvt.actorUid,
            budgetByName: newEvt.actorName,
            detail: newEvt.payload['detail'],
            status: 'running',
            locked: isLocked,
          );
          await upsertLocalSession(gid, newSession);
          final updated = cur.copyWith(activeSession: newSession);
          await _saveLocalGroup(updated);
          _notifyGroupChanged(gid, updated);
        }
      }
    } catch (e) {
      debugPrint('[GroupService] Broadcast handle error: $e');
    }
  }

  /// Menggabungkan event remote dengan event lokal optimis yang masih baru
  /// agar aktivitas offline/optimis tidak hilang terhapus poll atau stream.
  Future<void> _mergeAndSaveRemoteEvents(
    String gid,
    List<GroupEventModel> remoteEvents,
  ) {
    return _enqueueEventWrite(gid, () async {
      final local = _getLocalEvents(gid);
      final mergedMap = <String, GroupEventModel>{};
      final withoutId = <GroupEventModel>[];
      for (final r in remoteEvents) {
        if (r.eventId.isEmpty) {
          withoutId.add(r);
        } else {
          mergedMap[r.eventId] = r;
        }
      }
      final recentCutoff = DateTime.now().subtract(const Duration(minutes: 15));
      for (final loc in local) {
        if (loc.eventId.isEmpty) {
          withoutId.add(loc);
        } else if (!mergedMap.containsKey(loc.eventId) &&
            loc.createdAt.isAfter(recentCutoff)) {
          mergedMap[loc.eventId] = loc;
        }
      }
      final merged = [...mergedMap.values, ...withoutId]
        ..sort((a, b) {
          final cmp = b.createdAt.compareTo(a.createdAt);
          if (cmp != 0) return cmp;
          return b.eventId.compareTo(a.eventId);
        });
      await _saveLocalEvents(gid, merged);
    });
  }

  /// Memaksa muat ulang daftar aktivitas/notifikasi grup dari server
  Future<List<GroupEventModel>> refreshEvents(String gid) async {
    if (supabase != null) {
      try {
        final rows = await supabase!
            .from('group_events')
            .select('*')
            .eq('gid', gid)
            .order('created_at', ascending: false)
            .limit(100);
        final events = (rows as List)
            .map((r) => GroupEventModel.fromMap(r['id']?.toString() ?? '', r))
            .toList();
        await _mergeAndSaveRemoteEvents(gid, events);
        return _getLocalEvents(gid);
      } catch (e) {
        debugPrint('[GroupService] refreshEvents error: $e');
      }
    }
    return _getLocalEvents(gid);
  }

  /// Memantau log aktivitas grup realtime (Local-First + Broadcast + PostgresChanges + Polling)
  Stream<List<GroupEventModel>> watchEvents(String gid) async* {
    final local = _getLocalEvents(gid);
    yield local;

    final controller = StreamController<List<GroupEventModel>>.broadcast();
    _eventsControllers.putIfAbsent(gid, () => []).add(controller);

    final afterYield = _getLocalEvents(gid);
    if (afterYield.length != local.length) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(afterYield);
      });
    }

    // 1. Pastikan channel realtime aktif (mendengar broadcast & postgresChanges langsung)
    //    serta jalankan query awal non-blocking dari Supabase.
    if (supabase != null) {
      _ensureChannel(gid);
      unawaited(refreshEvents(gid));
    }

    // 2. Fallback Periodic Polling (setiap 10 detik) + Auto-recover Supabase table stream
    Timer? pollTimer;
    Timer? streamRetryTimer;
    StreamSubscription? subSubscription;
    bool cancelled = false;

    void attachEventStream() {
      if (cancelled || supabase == null || _disposed) return;
      subSubscription?.cancel();
      try {
        subSubscription = supabase!
            .from('group_events')
            .stream(primaryKey: ['id'])
            .eq('gid', gid)
            .order('created_at', ascending: false)
            .limit(100)
            .listen(
              (rows) {
                final events = rows
                    .map((r) => GroupEventModel.fromMap(r['id']?.toString() ?? '', r))
                    .toList();
                unawaited(_mergeAndSaveRemoteEvents(gid, events));
              },
              onError: (e) {
                debugPrint('[GroupService] watchEvents stream error: $e');
                if (cancelled || controller.isClosed || _disposed) return;
                _channelNeedsReconnect = true;
                _ensureChannel(gid);
                streamRetryTimer?.cancel();
                streamRetryTimer = Timer(const Duration(seconds: 3), () {
                  if (!cancelled && !controller.isClosed && !_disposed) {
                    unawaited(refreshEvents(gid));
                    attachEventStream();
                  }
                });
              },
              onDone: () {
                if (cancelled || controller.isClosed || _disposed) return;
                streamRetryTimer?.cancel();
                streamRetryTimer = Timer(const Duration(seconds: 3), () {
                  if (!cancelled && !controller.isClosed && !_disposed) {
                    unawaited(refreshEvents(gid));
                    attachEventStream();
                  }
                });
              },
            );
      } catch (e) {
        debugPrint('[GroupService] watchEvents stream attach error: $e');
      }
    }

    if (supabase != null) {
      pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await refreshEvents(gid);
      });
      attachEventStream();
    }

    // 3. Firestore fallback
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
      cancelled = true;
      _eventsControllers[gid]?.remove(controller);
      streamRetryTimer?.cancel();
      pollTimer?.cancel();
      subSubscription?.cancel();
      firestoreSub?.cancel();
    };

    yield* controller.stream;
  }

  /// Menandai bahwa pengguna telah membaca aktivitas terkini di grup
  Future<void> markActivityAsRead(String gid) async {
    final myUid = authService.currentUid ?? authService.fallbackUid;
    var now = DateTime.now();
    // Jika jam server sedikit lebih maju dari jam perangkat (clock skew <= 2 menit),
    // pastikan event yang sudah tampil saat membuka notifikasi ikut tertandai terbaca.
    final maxAllowedSkew = now.add(const Duration(minutes: 2));
    for (final evt in _getLocalEvents(gid)) {
      if (evt.createdAt.isAfter(now) && !evt.createdAt.isAfter(maxAllowedSkew)) {
        now = evt.createdAt;
      }
    }

    // 1. Update lokal seketika (0ms badge reset, bekerja offline & multi-UID)
    await _setLocalLastReadAt(gid, now);

    final localMembers = _getLocalMembers(gid);
    bool updatedAny = false;
    final nextMembers = localMembers.map((m) {
      if (authService.isCurrentUser(m.uid) || (myUid != null && m.uid == myUid)) {
        updatedAny = true;
        return m.copyWith(lastReadAt: now);
      }
      return m;
    }).toList();
    if (updatedAny) {
      await _saveLocalMembers(gid, nextMembers);
    } else {
      _notifyMembersChanged(gid, localMembers);
    }

    if (myUid == null) return;

    if (supabase != null) {
      try {
        final candidates = <String>{
          if (authService.currentUid != null && authService.currentUid!.isNotEmpty)
            authService.currentUid!,
          if (authService.fallbackUid != null && authService.fallbackUid!.isNotEmpty)
            authService.fallbackUid!,
          myUid,
        }.toList();
        if (candidates.length > 1) {
          await supabase!
              .from('group_members')
              .update({'last_read_at': now.toUtc().toIso8601String()})
              .eq('gid', gid)
              .inFilter('uid', candidates);
        } else {
          await supabase!
              .from('group_members')
              .update({'last_read_at': now.toUtc().toIso8601String()})
              .eq('gid', gid)
              .eq('uid', myUid);
        }
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

  /// Memperbarui timestamp kehadiran pengguna (lastSeenAt) & memperbaiki last_read_at jika corrupt di masa depan
  Future<void> updatePresence(String gid) async {
    final myUid = authService.currentUid;
    if (myUid == null) return;
    final now = DateTime.now();

    // Self-heal last_read_at yang bergeser ke masa depan akibat bug timezone versi lama
    final maxFutureLimit = now.add(const Duration(minutes: 2));
    final localMembers = _getLocalMembers(gid);
    final idx = localMembers.indexWhere((m) => authService.isCurrentUser(m.uid));
    final localReadAt = getLocalLastReadAt(gid);
    final hasCorruptMemberReadAt =
        idx != -1 && localMembers[idx].lastReadAt.isAfter(maxFutureLimit);
    final hasCorruptLocalReadAt =
        localReadAt != null && localReadAt.isAfter(maxFutureLimit);
    if (hasCorruptMemberReadAt || hasCorruptLocalReadAt) {
      await markActivityAsRead(gid);
    }

    if (supabase != null) {
      try {
        await supabase!
            .from('group_members')
            .update({'last_seen_at': now.toUtc().toIso8601String()})
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

  /// Menjalankan migrasi aman sessionId pada sesi, catatan, dan event lokal grup,
  /// lalu mengembalikan daftar sesi terurut terbaru di atas.
  Future<List<GroupSessionModel>> getGroupSessionsWithMigration(String gid) async {
    final group = _getLocalGroup(gid);
    final rawSessions = _getLocalSessions(gid);
    final rawNotes = _getLocalNotes(gid);
    final rawEvents = _getLocalEvents(gid);

    final migrated = GroupHistoryCalculator.migrateMissingSessionIds(
      gid: gid,
      sessions: rawSessions,
      notes: rawNotes,
      events: rawEvents,
      activeSession: group?.activeSession,
    );

    if (migrated.hasChanges) {
      await _saveLocalSessions(gid, migrated.sessions);
      await _saveLocalNotes(gid, migrated.notes);
      await _saveLocalEvents(gid, migrated.events);
    }

    return migrated.sessions;
  }

  /// Memantau daftar riwayat sesi (date) grup secara realtime (Local-First + Supabase/Firestore)
  Stream<List<GroupSessionModel>> watchGroupSessions(
    String gid, {
    int limit = 200,
  }) async* {
    final initial = await getGroupSessionsWithMigration(gid);
    yield initial.take(limit).toList();

    final controller = StreamController<List<GroupSessionModel>>.broadcast();
    _sessionsControllers.putIfAbsent(gid, () => []).add(controller);

    // Dengarkan juga perubahan pada notes/events agar ringkasan riwayat selalu reaktif
    final notesMirror = StreamController<List<GroupNoteModel>>.broadcast();
    final eventsMirror = StreamController<List<GroupEventModel>>.broadcast();
    _notesControllers.putIfAbsent(gid, () => []).add(notesMirror);
    _eventsControllers.putIfAbsent(gid, () => []).add(eventsMirror);

    Future<void> refreshFromLocal() async {
      final updated = await getGroupSessionsWithMigration(gid);
      if (!controller.isClosed) {
        controller.add(updated.take(limit).toList());
      }
    }

    final notesSub = notesMirror.stream.listen((_) => refreshFromLocal());
    final eventsSub = eventsMirror.stream.listen((_) => refreshFromLocal());

    if (supabase != null) {
      try {
        final rows = await supabase!
            .from('group_sessions')
            .select('*')
            .eq('gid', gid)
            .order('started_at', ascending: false)
            .limit(limit);
        if (rows.isNotEmpty) {
          final remoteSessions = (rows as List)
              .map((r) => GroupSessionModel.fromMap(Map<String, dynamic>.from(r)))
              .toList();
          final localSessions = _getLocalSessions(gid);
          final byId = {for (final s in localSessions) s.sessionId: s};
          for (final rs in remoteSessions) {
            if (rs.sessionId.isNotEmpty) {
              byId[rs.sessionId] = rs.copyWith(gid: gid);
            }
          }
          await _saveLocalSessions(gid, byId.values.toList());
          await refreshFromLocal();
        }
      } catch (_) {}
    }

    StreamSubscription? firestoreSub;
    if (firestore != null) {
      try {
        firestoreSub = firestore!
            .collection('groups')
            .doc(gid)
            .collection('sessions')
            .orderBy('startedAt', descending: true)
            .limit(limit)
            .snapshots()
            .listen((snapshot) async {
          final remoteSessions = snapshot.docs
              .map((doc) => GroupSessionModel.fromMap(doc.data()).copyWith(
                    sessionId: doc.id,
                    gid: gid,
                  ))
              .toList();
          final localSessions = _getLocalSessions(gid);
          final byId = {for (final s in localSessions) s.sessionId: s};
          for (final rs in remoteSessions) {
            if (rs.sessionId.isNotEmpty) {
              byId[rs.sessionId] = rs;
            }
          }
          await _saveLocalSessions(gid, byId.values.toList());
          await refreshFromLocal();
        }, onError: (_) {});
      } catch (_) {}
    }

    controller.onCancel = () {
      _sessionsControllers[gid]?.remove(controller);
      _notesControllers[gid]?.remove(notesMirror);
      _eventsControllers[gid]?.remove(eventsMirror);
      notesSub.cancel();
      eventsSub.cancel();
      notesMirror.close();
      eventsMirror.close();
      firestoreSub?.cancel();
    };

    yield* controller.stream;
  }

  /// Memantau catatan untuk satu sesi spesifik (termasuk setelah migrasi sessionId)
  Stream<List<GroupNoteModel>> watchSessionNotes(
    String gid,
    String sessionId,
  ) async* {
    await getGroupSessionsWithMigration(gid);
    yield* watchNotes(gid, sessionId);
  }

  /// Memantau event timeline untuk satu sesi spesifik (diurutkan waktu server ascending)
  Stream<List<GroupEventModel>> watchSessionEvents(
    String gid,
    String sessionId,
  ) async* {
    await getGroupSessionsWithMigration(gid);
    await for (final allEvents in watchEvents(gid)) {
      final filtered = allEvents.where((evt) {
        if (evt.sessionId == sessionId) return true;
        return false;
      }).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      yield filtered;
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
    resolveLiveSupabase: true,
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
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty) {
    return Stream.value([]);
  }
  final localGroup = groupService.getLocalGroup(activeGid);
  final activeGroupAsync = ref.watch(activeGroupStreamProvider);
  final streamedGroup = activeGroupAsync.valueOrNull;
  final resolvedSession = groupService.resolveEffectiveSession(
    activeGid,
    streamedGroup?.activeSession,
    localGroup?.activeSession,
  );

  String? sessionId = resolvedSession?.sessionId;
  if (sessionId == null || sessionId.isEmpty) {
    final evts = groupService.getLocalEvents(activeGid);
    for (final evt in evts) {
      if (evt.payload['action'] == 'end_session') break;
      if (evt.payload['sessionId'] != null) {
        final candidateSid = evt.payload['sessionId'].toString();
        final candidateSession = GroupSessionModel(
          sessionId: candidateSid,
          budget: 1,
          startedByUid: evt.actorUid,
          startedByName: evt.actorName,
          startedAt: evt.createdAt,
        );
        if (!groupService.isSessionEnded(activeGid, candidateSession)) {
          sessionId = candidateSid;
        }
        break;
      }
    }
  }

  return groupService.watchNotes(activeGid, sessionId ?? '');
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

final _groupLastReadRevisionProvider = StreamProvider<int>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  return groupService.watchLastReadRevision();
});

/// Provider menghitung jumlah aktivitas belum dibaca oleh anggota saat ini
final unreadActivityCountProvider = Provider<int>((ref) {
  final authService = ref.watch(groupAuthServiceProvider);
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  ref.watch(_groupLastReadRevisionProvider);
  final myUid = authService.currentUid ?? authService.fallbackUid;
  if (myUid == null) return 0;

  final membersAsync = ref.watch(activeGroupMembersStreamProvider);
  final eventsAsync = ref.watch(activeGroupEventsStreamProvider);

  final members = membersAsync.valueOrNull ??
      ((activeGid != null && activeGid.isNotEmpty)
          ? groupService.getLocalMembers(activeGid)
          : const <GroupMemberModel>[]);
  final events = eventsAsync.valueOrNull ??
      (activeGid != null && activeGid.isNotEmpty
          ? groupService.getLocalEvents(activeGid)
          : const <GroupEventModel>[]);
  if (events.isEmpty) return 0;

  final localReadAt = (activeGid != null && activeGid.isNotEmpty)
      ? groupService.getLocalLastReadAt(activeGid)
      : null;

  final matchedIdx = members.indexWhere(
    (m) => authService.isCurrentUser(m.uid) || m.uid == myUid,
  );
  final myMember = matchedIdx != -1 ? members[matchedIdx] : null;

  final now = DateTime.now();
  final maxFutureLimit = now.add(const Duration(minutes: 2));
  DateTime? memberReadAt = myMember?.lastReadAt;
  // Guard terhadap timestamp kosong (epoch 0) atau corrupt masa depan dari versi lama
  if (memberReadAt != null &&
      (memberReadAt.millisecondsSinceEpoch <= 0 ||
          memberReadAt.isAfter(maxFutureLimit))) {
    memberReadAt = null;
  }

  final safeLocalReadAt =
      (localReadAt != null && !localReadAt.isAfter(maxFutureLimit))
          ? localReadAt
          : null;

  DateTime threshold;
  if (memberReadAt != null && safeLocalReadAt != null) {
    threshold =
        memberReadAt.isAfter(safeLocalReadAt) ? memberReadAt : safeLocalReadAt;
  } else if (memberReadAt != null || safeLocalReadAt != null) {
    threshold = (memberReadAt ?? safeLocalReadAt)!;
  } else {
    final localGroup = (activeGid != null && activeGid.isNotEmpty)
        ? groupService.getLocalGroup(activeGid)
        : null;
    threshold = localGroup?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  return events
      .where((e) => groupService.isUnreadEligibleEvent(e, threshold))
      .length;
});


/// StreamProvider untuk memantau siaran langsung putaran/game grup aktif (F2)
final activeLivePlayStreamProvider = StreamProvider<LivePlayModel?>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty) {
    return Stream.value(null);
  }
  return groupService.watchLivePlay(activeGid);
});

/// StreamProvider untuk memantau daftar riwayat sesi (date) grup aktif (Layar 62)
final activeGroupSessionsStreamProvider =
    StreamProvider<List<GroupSessionModel>>((ref) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty) {
    return Stream.value([]);
  }
  return groupService.watchGroupSessions(activeGid);
});

/// StreamProvider.family untuk memantau catatan pada satu sesi riwayat grup (Layar 63, 64, 66)
final groupSessionNotesStreamProvider =
    StreamProvider.family<List<GroupNoteModel>, String>((ref, sessionId) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty || sessionId.isEmpty) {
    return Stream.value([]);
  }
  return groupService.watchSessionNotes(activeGid, sessionId);
});

/// StreamProvider.family untuk memantau event linimasa pada satu sesi riwayat grup (Layar 65)
final groupSessionEventsStreamProvider =
    StreamProvider.family<List<GroupEventModel>, String>((ref, sessionId) {
  final groupService = ref.watch(groupServiceProvider);
  final activeGid = ref.watch(activeGroupIdProvider);
  if (activeGid == null || activeGid.isEmpty || sessionId.isEmpty) {
    return Stream.value([]);
  }
  return groupService.watchSessionEvents(activeGid, sessionId);
});

/// StateProvider untuk menandai mode offline perangkat pada tampilan grup & riwayat grup
final groupOfflineModeProvider = StateProvider<bool>((ref) => false);

