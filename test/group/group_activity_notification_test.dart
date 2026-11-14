import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';
import 'package:putar_jajan/core/group/services/group_notification_settings_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/activity_tile.dart';
import 'package:putar_jajan/core/group/widgets/group_realtime_listener.dart';
import 'package:putar_jajan/core/notifications/coordinator/notification_coordinator.dart';
import 'package:putar_jajan/core/notifications/models/notification_intent.dart';
import 'package:putar_jajan/core/notifications/storage/notified_claim_store.dart';
import 'package:putar_jajan/core/theme/app_colors.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';
import 'package:putar_jajan/features/group/screens/group_activity_screen.dart';
import 'package:putar_jajan/features/group/screens/group_games_hub_view.dart';
import 'package:putar_jajan/features/group/screens/group_history_view.dart';
import 'package:putar_jajan/features/group/screens/group_notes_view.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late GroupAuthService authService;
  late GroupService groupService;
  late GroupGameService gameService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(prefs);
    NotificationCoordinator.instance.setClaimStore(InMemoryNotifiedClaimStore());
    NotificationCoordinator.instance.clearDecisionHistory();

    authService = GroupAuthService(prefs: prefs);
    await authService.ensureSignedIn();
    await authService.setDisplayName('Evan');

    groupService = GroupService(
      firestore: null,
      supabase: null,
      authService: authService,
      prefs: prefs,
    );
    gameService = GroupGameService(
      groupService: groupService,
      authService: authService,
    );
  });

  group('GroupService Event Capture, Sync & Unread Count', () {
    test('Menangkap semua aksi lokal: create, sessionStart, spin, gameResult, note add/edit/delete, endSession, inviteCode', () async {
      final gid = await groupService.createGroup(
        groupName: 'Date Weekend',
        creatorName: 'Evan',
        colorIndex: 0,
      );

      // 1. sessionStart (notifySessionStarted)
      await groupService.notifySessionStarted(gid);

      // 2. spin
      await groupService.recordSpin(
        gid: gid,
        budget: 100000,
        sessionId: 'sess_spin_1',
      );

      // 3. gameResult (coin) via claimSessionAndWriteResult
      final gameOutcome = await gameService.claimSessionAndWriteResult(
        gid: gid,
        game: 'coin',
        amount: 80000,
      );
      final activeSid = gameOutcome.activeSession?.sessionId ?? 'sess_spin_1';

      // 4. addNote -> updateNote (edited) -> deleteNote
      final noteId = await groupService.addNote(
        gid: gid,
        sessionId: activeSid,
        title: 'Boba',
        amount: 35000,
        sessionBudget: 80000,
      );
      await groupService.addNote(
        gid: gid,
        sessionId: activeSid,
        title: 'Steak',
        amount: 60000, // total 95rb -> remaining -15rb!
        sessionBudget: 80000,
      );
      await groupService.updateNote(
        gid: gid,
        noteId: noteId,
        newTitle: 'Boba Jumbo',
        newAmount: 40000,
        sessionBudget: 80000,
      );
      await groupService.deleteNote(
        gid: gid,
        noteId: noteId,
        title: 'Boba Jumbo',
        amount: 40000,
        sessionBudget: 80000,
      );

      // 5. endSession
      await groupService.endSession(gid: gid);

      // 6. regenerateInviteCode
      final newCode = await groupService.regenerateInviteCode(gid);
      expect(newCode, isNotEmpty);

      final events = groupService.getLocalEvents(gid);
      expect(events, isNotEmpty);

      // Pastikan semua eventId unik (tidak duplikat)
      final eventIds = events.map((e) => e.eventId).toList();
      expect(eventIds.toSet().length, equals(eventIds.length));

      expect(events.any((e) => e.type == GroupEventType.memberJoin), isTrue);
      expect(events.any((e) => e.type == GroupEventType.sessionStart), isTrue);
      expect(events.any((e) => e.type == GroupEventType.spin), isTrue);
      expect(
        events.any(
          (e) =>
              e.type == GroupEventType.gameResult &&
              e.payload['game'] == 'coin' &&
              e.payload['amount'] == 80000,
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.type == GroupEventType.expense &&
              e.payload['title'] == 'Steak' &&
              e.payload['remaining'] == -15000,
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.type == GroupEventType.expense &&
              e.payload['edited'] == true &&
              e.payload['title'] == 'Boba Jumbo',
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.type == GroupEventType.expenseDeleted &&
              e.payload['title'] == 'Boba Jumbo',
        ),
        isTrue,
      );
      expect(events.any((e) => e.type == GroupEventType.sessionEnd), isTrue);
      expect(events.any((e) => e.type == GroupEventType.codeChanged), isTrue);
    });

    test('Timezone serialization: toMap mengirim UTC ISO-8601 (Z) dan fromMap mengembalikan DateTime lokal', () {
      final sampleLocal = DateTime(2026, 11, 13, 18, 30, 0);
      final evt = GroupEventModel(
        eventId: 'evt_tz_1',
        type: GroupEventType.gameResult,
        actorUid: 'u1',
        actorName: 'Dina',
        summary: null,
        payload: {'game': 'dice', 'amount': 50000, 'sessionId': 's1'},
        createdAt: sampleLocal,
      );

      final map = evt.toMap();
      final createdAtIso = map['created_at'] as String;
      expect(createdAtIso.endsWith('Z'), isTrue);
      expect(map['session_id'], 's1');

      final decoded = GroupEventModel.fromMap('evt_tz_1', map);
      expect(decoded.createdAt.isUtc, isFalse);
      expect(decoded.createdAt.millisecondsSinceEpoch, sampleLocal.millisecondsSinceEpoch);

      final member = GroupMemberModel(
        uid: 'u1',
        name: 'Dina',
        colorIndex: 1,
        role: 'member',
        joinedAt: sampleLocal,
        lastReadAt: sampleLocal,
        lastSeenAt: sampleLocal,
      );
      final decodedMember = GroupMemberModel.fromMap('u1', member.toMap());
      expect(decodedMember.lastReadAt.millisecondsSinceEpoch, sampleLocal.millisecondsSinceEpoch);

      // Verifikasi parsing baris UTC ISO-8601 dari Supabase menjadi DateTime lokal
      final utcIso = sampleLocal.toUtc().toIso8601String();
      final fromSupabaseMember = GroupMemberModel.fromMap('u1', {
        'uid': 'u1',
        'name': 'Dina',
        'color_index': 1,
        'role': 'member',
        'joined_at': utcIso,
        'last_read_at': utcIso,
        'last_seen_at': utcIso,
      });
      expect(fromSupabaseMember.lastReadAt.isUtc, isFalse);
      expect(fromSupabaseMember.lastReadAt.millisecondsSinceEpoch, sampleLocal.millisecondsSinceEpoch);
    });

    test('watchEvents langsung meng-emit list kosong tanpa gantung loading saat grup baru / offline', () async {
      final firstEmission = await groupService.watchEvents('grp_empty_watch').first;
      expect(firstEmission, isEmpty);
    });

    test('unreadActivityCountProvider menghitung event anggota lain, mereset 0ms via markActivityAsRead, dan menangkis lastReadAt +7 jam', () async {
      const gid = 'grp_unread_test';
      final myUid = authService.currentUid!;
      final now = DateTime.now();

      final members = [
        GroupMemberModel(
          uid: myUid,
          name: 'Evan',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now.subtract(const Duration(days: 1)),
          // Simulasi timestamp corrupt +7 jam dari versi lama
          lastReadAt: now.add(const Duration(hours: 7)),
        ),
      ];
      await prefs.setString(
        'local_members_$gid',
        jsonEncode(members.map((m) => {'uid': m.uid, ...m.toMap()}).toList()),
      );

      final events = [
        GroupEventModel(
          eventId: 'evt_other_1',
          type: GroupEventType.gameResult,
          actorUid: 'uid_partner',
          actorName: 'Dina',
          payload: {'game': 'dice', 'amount': 75000},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
        GroupEventModel(
          eventId: 'evt_other_2',
          type: GroupEventType.expense,
          actorUid: 'uid_partner',
          actorName: 'Dina',
          payload: {'title': 'Kopi', 'amount': 25000, 'remaining': 50000},
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        GroupEventModel(
          eventId: 'evt_self_1',
          type: GroupEventType.spin,
          actorUid: myUid,
          actorName: 'Evan',
          payload: {'budget': 100000},
          createdAt: now.subtract(const Duration(seconds: 30)),
        ),
      ];
      await prefs.setString(
        'local_events_$gid',
        jsonEncode(events.map((e) => {'eventId': e.eventId, ...e.toMap()}).toList()),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupAuthServiceProvider.overrideWithValue(authService),
          groupServiceProvider.overrideWithValue(groupService),
          activeGroupIdProvider.overrideWith((ref) => gid),
          activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
          activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
        ],
      );
      addTearDown(container.dispose);

      // Flush stream providers
      await container.read(activeGroupMembersStreamProvider.future);
      await container.read(activeGroupEventsStreamProvider.future);

      // Karena lastReadAt corrupt (+7 jam), event 1-2 menit lalu dari anggota lain dihitung belum dibaca (2, aksi sendiri di-skip)
      expect(container.read(unreadActivityCountProvider), 2);

      // Tandai telah dibaca -> reset seketika ke 0 secara lokal tanpa perlu invalidate manual
      await groupService.markActivityAsRead(gid);
      expect(groupService.getLocalLastReadAt(gid), isNotNull);
      expect(container.read(unreadActivityCountProvider), 0);
    });

    test('NotificationCoordinator mengabaikan watermark korup di masa depan (+7 jam)', () async {
      final coordinator = NotificationCoordinator.instance;
      final claimStore = InMemoryNotifiedClaimStore();
      coordinator.setClaimStore(claimStore);
      coordinator.currentUidGetter = () => 'uid_me';
      coordinator.isGroupMutedGetter = (_) => false;
      coordinator.isCategoryEnabledGetter = (_) => true;
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      final shown = <NotificationIntent>[];
      coordinator.onRenderBanner = (intent) async => shown.add(intent);

      await claimStore.setLastDeliveredEventAt(
        'grp_wm_test',
        DateTime.now().add(const Duration(hours: 7)),
      );
      final intent = NotificationIntent.groupEvent(
        gid: 'grp_wm_test',
        groupName: 'Grup Test',
        eventId: 'evt_wm_fresh',
        eventType: 'game_result',
        actorUid: 'uid_partner',
        actorName: 'Dina',
        title: 'Dina memainkan Kocok Dadu: Rp50.000',
        subtitle: 'Budget baru untuk date',
        systemBody: 'Dina memainkan Kocok Dadu Rp50.000',
      );

      final decision = await coordinator.dispatch(intent);
      coordinator.resetAggregationBuffers();

      expect(decision.surface, NotificationSurface.banner);
      expect(decision.reason, isNot(equals(NotificationDropReason.oldEvent)));
      expect(shown.length, 1);
    });
  });

  group('GroupActivityScreen & ActivityTile UI Tests', () {
    testWidgets('Semua 5 filter (Semua, Roda, Catatan, Date, Anggota) menangkap seluruh tipe event dengan tepat', (tester) async {
      const gid = 'grp_ui_filters';
      final now = DateTime.now();
      final myUid = authService.currentUid!;

      final group = GroupModel(
        id: gid,
        name: 'Grup Jajan',
        ownerUid: myUid,
        code: 'XYZ999',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      final members = [
        GroupMemberModel(
          uid: myUid,
          name: 'Evan',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now.subtract(const Duration(days: 1)),
          // Simulasi +7 jam -> harus tetap dianggap expired/aman sehingga event baru tetap tampil di BARU
          lastReadAt: now.add(const Duration(hours: 7)),
        ),
        GroupMemberModel(
          uid: 'uid_dina',
          name: 'Dina',
          colorIndex: 2,
          role: 'member',
          joinedAt: now.subtract(const Duration(days: 1)),
          lastReadAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

      final events = [
        GroupEventModel(
          eventId: 'e_spin',
          type: GroupEventType.spin,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          payload: {'budget': 150000, 'sessionId': 's1'},
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        GroupEventModel(
          eventId: 'e_coin',
          type: GroupEventType.gameResult,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          payload: {'game': 'coin', 'amount': 50000, 'valid': true, 'sessionId': 's1'},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
        GroupEventModel(
          eventId: 'e_dice_invalid',
          type: GroupEventType.gameResult,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          payload: {'game': 'dice', 'amount': 40000, 'valid': false},
          createdAt: now.subtract(const Duration(minutes: 3)),
        ),
        GroupEventModel(
          eventId: 'e_note',
          type: GroupEventType.expense,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          payload: {'title': 'Ramen', 'amount': 65000, 'remaining': -15000, 'sessionId': 's1'},
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
        GroupEventModel(
          eventId: 'e_note_del',
          type: GroupEventType.expenseDeleted,
          actorUid: myUid,
          actorName: 'Evan',
          payload: {'title': 'Puding', 'amount': 10000, 'remaining': 50000, 'sessionId': 's1'},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        GroupEventModel(
          eventId: 'e_end',
          type: GroupEventType.sessionEnd,
          actorUid: myUid,
          actorName: 'Evan',
          payload: {'budget': 50000, 'totalSpent': 65000, 'status': 'lewat', 'endedSessionId': 's1'},
          createdAt: now.subtract(const Duration(minutes: 6)),
        ),
        GroupEventModel(
          eventId: 'e_join',
          type: GroupEventType.memberJoin,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          payload: const {},
          createdAt: now.subtract(const Duration(minutes: 7)),
        ),
        GroupEventModel(
          eventId: 'e_join_self',
          type: GroupEventType.memberJoin,
          actorUid: myUid,
          actorName: 'Evan',
          payload: const {},
          createdAt: now.subtract(const Duration(minutes: 8)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            activeGroupIdProvider.overrideWith((ref) => gid),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
            activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const GroupActivityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default 'Semua' menampilkan BARU + SEBELUMNYA serta nilai minus & status tidak berlaku
      expect(find.text('BARU'), findsOneWidget);
      expect(find.text('SEBELUMNYA'), findsOneWidget);
      expect(find.text('Sisa -Rp15.000'), findsOneWidget);
      expect(find.text('Tidak berlaku'), findsOneWidget);
      expect(find.text('Terpakai Rp65.000'), findsOneWidget);
      expect(find.text('Lewat'), findsOneWidget);

      // Filter 'Roda' harus menangkap spin + gameResult (coin, dice), dan menyembunyikan catatan/join
      await tester.tap(find.text('Roda'));
      await tester.pumpAndSettle();
      expect(find.text('Dina memutar roda: Rp150.000'), findsOneWidget);
      expect(find.text('Dina memainkan Lempar Koin: Rp50.000'), findsOneWidget);
      expect(find.text('Dina memainkan Kocok Dadu: Rp40.000 (tidak berlaku)'), findsOneWidget);
      expect(find.text('Dina mencatat "Ramen"'), findsNothing);

      // Filter 'Catatan' menangkap expense + expenseDeleted
      await tester.tap(find.text('Catatan'));
      await tester.pumpAndSettle();
      expect(find.text('Dina mencatat "Ramen"'), findsOneWidget);
      expect(find.text('Kamu menghapus catatan "Puding"'), findsOneWidget);
      expect(find.text('Dina memainkan Lempar Koin: Rp50.000'), findsNothing);

      // Filter 'Date' menangkap sessionEnd
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      expect(find.text('Kamu menyelesaikan date: Lewat'), findsOneWidget);
      expect(find.text('Dina mencatat "Ramen"'), findsNothing);

      // Filter 'Anggota' menangkap memberJoin
      await tester.tap(find.text('Anggota'));
      await tester.pumpAndSettle();
      expect(find.text('Dina bergabung ke grup.'), findsOneWidget);
      expect(find.text('Kamu menyelesaikan date: Lewat'), findsNothing);
    });

    testWidgets('Kategori filter kosong menampilkan tombol Tampilkan Semua yang memulihkan daftar', (tester) async {
      const gid = 'grp_ui_filtered_empty';
      final now = DateTime.now();
      final myUid = authService.currentUid!;

      final group = GroupModel(
        id: gid,
        name: 'Grup Jajan',
        ownerUid: myUid,
        code: 'XYZ999',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      final members = [
        GroupMemberModel(
          uid: myUid,
          name: 'Evan',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now.subtract(const Duration(days: 1)),
          lastReadAt: now.subtract(const Duration(hours: 1)),
        ),
      ];
      final events = [
        GroupEventModel(
          eventId: 'e_only_spin',
          type: GroupEventType.spin,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          payload: {'budget': 100000, 'sessionId': 's1'},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            activeGroupIdProvider.overrideWith((ref) => gid),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
            activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const GroupActivityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Catatan'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada notifikasi di kategori ini'), findsOneWidget);
      expect(find.text('Tampilkan Semua'), findsOneWidget);

      await tester.tap(find.text('Tampilkan Semua'));
      await tester.pumpAndSettle();

      expect(find.text('Dina memutar roda: Rp100.000'), findsOneWidget);
    });

    testWidgets('ActivityTile zero RenderFlex overflow di 320dp dengan TextScaler 1.3 untuk BARU & SEBELUMNYA', (tester) async {
      final now = DateTime.now();
      final events = [
        GroupEventModel(
          eventId: 'o1',
          type: GroupEventType.gameResult,
          actorUid: 'u2',
          actorName: 'Nama Anggota Yang Sangat Panjang Sekali',
          payload: {'game': 'envelope', 'amount': 250000, 'valid': false},
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        GroupEventModel(
          eventId: 'o2',
          type: GroupEventType.expense,
          actorUid: 'u2',
          actorName: 'Dina',
          payload: {'title': 'Makan Malam Keluarga Super Lengkap', 'amount': 350000, 'remaining': -125000, 'edited': true},
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
        GroupEventModel(
          eventId: 'o3',
          type: GroupEventType.sessionEnd,
          actorUid: 'u1',
          actorName: 'Evan',
          payload: {'budget': 100000, 'totalSpent': 125000, 'status': 'lewat'},
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    for (final e in events) ...[
                      ActivityTile(event: e, isUnread: true),
                      ActivityTile(event: e, isUnread: false, isMe: e.actorUid == 'u1'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Realtime Notification & Activity Fixes', () {
    test('unwrapBroadcastEventPayload memulihkan tipe asli event dan melindungi map asli dari mutasi broadcast', () {
      final originalDbMap = <String, dynamic>{
        'id': 'evt_spin_1',
        'gid': 'grp_unwrap',
        'type': 'session_end',
        'actor_uid': 'u1',
        'actor_name': 'Evan',
        'payload': {'status': 'lolos'},
      };

      // Simulasi amplop broadcast + mutasi in-place seperti RealtimeChannel.send
      final outerEnvelope = <String, dynamic>{
        'event_record': Map<String, dynamic>.from(originalDbMap),
      };
      outerEnvelope['type'] = 'broadcast';
      outerEnvelope['event'] = 'group_event';

      // Map asli untuk DB insert tidak ikut termutasi 'type=broadcast' / 'event'
      expect(originalDbMap['type'], 'session_end');
      expect(originalDbMap.containsKey('event'), isFalse);

      final unwrapped = GroupService.unwrapBroadcastEventPayload(outerEnvelope);
      expect(unwrapped['type'], 'session_end');
      expect(unwrapped['id'], 'evt_spin_1');

      // Juga mendukung format lama bersarang 'payload' serta fallback 'event_type'
      final legacyNested = GroupService.unwrapBroadcastEventPayload({
        'type': 'broadcast',
        'event': 'group_event',
        'payload': {'id': 'evt_leg', 'type': 'spin', 'actor_uid': 'u2'},
      });
      expect(legacyNested['type'], 'spin');
      expect(legacyNested['id'], 'evt_leg');

      final fallbackType = GroupService.unwrapBroadcastEventPayload({
        'id': 'evt_fb',
        'type': 'broadcast',
        'event_type': 'game_result',
      });
      expect(fallbackType['type'], 'game_result');
    });

    test('GroupEventModel.normalizeSkewedTimestamp memperbaiki row +7 jam ber-epoch ID tanpa merusak ID sintetis', () {
      const refEpoch = 1794552000000; // referensi "sekarang"
      final refNow = DateTime.fromMillisecondsSinceEpoch(refEpoch);
      const eventEpoch = 1794545185195; // ~1.89 jam sebelum refNow
      final corruptFuture = DateTime.fromMillisecondsSinceEpoch(eventEpoch).add(const Duration(hours: 7));

      final normalized = GroupEventModel.normalizeSkewedTimestamp(
        'evt_${eventEpoch}_696',
        corruptFuture,
        referenceNow: refNow,
      );
      expect(normalized.millisecondsSinceEpoch, eventEpoch);

      // ID sintetis dalam skenario uji tetap mempertahankan timestamp aslinya
      final syntheticFuture = refNow.add(const Duration(hours: 2));
      final kept = GroupEventModel.normalizeSkewedTimestamp(
        'evt_updated_1',
        syntheticFuture,
        referenceNow: refNow,
      );
      expect(kept.millisecondsSinceEpoch, syntheticFuture.millisecondsSinceEpoch);
    });

    test('NotificationCoordinator tidak meracuni watermark jika menerima event berskew masa depan', () async {
      final store = InMemoryNotifiedClaimStore();
      NotificationCoordinator.instance.setClaimStore(store);
      final prevUidGetter = NotificationCoordinator.instance.currentUidGetter;
      final prevIsCurrentUser = NotificationCoordinator.instance.isCurrentUserGetter;
      NotificationCoordinator.instance.currentUidGetter = () => 'me';
      NotificationCoordinator.instance.isCurrentUserGetter = (uid) => uid == 'me';
      NotificationCoordinator.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final banners = <NotificationIntent>[];
      NotificationCoordinator.instance.onRenderBanner = (intent) async {
        banners.add(intent);
      };
      addTearDown(() {
        NotificationCoordinator.instance.onRenderBanner = null;
        NotificationCoordinator.instance.currentUidGetter = prevUidGetter;
        NotificationCoordinator.instance.isCurrentUserGetter = prevIsCurrentUser;
      });

      const gid = 'grp_wm_skew';
      final now = DateTime.now();

      final futureDecision = await NotificationCoordinator.instance.dispatch(
        NotificationIntent(
          dedupeKey: 'evt:$gid:future_1',
          category: NotificationCategory.spin,
          source: NotificationSource.listener,
          gid: gid,
          groupName: 'Grup Uji',
          actorUid: 'partner',
          actorName: 'Dina',
          title: 'Dina memutar Roda Putar',
          subtitle: 'Budget Rp50.000',
          systemTitle: 'Grup Uji',
          systemBody: 'Dina memutar roda Rp50.000',
          createdAt: now.add(const Duration(hours: 3)),
        ),
      );
      expect(futureDecision.reason, NotificationDropReason.none);
      expect(await store.getLastDeliveredEventAt(gid), isNull);

      final normalDecision = await NotificationCoordinator.instance.dispatch(
        NotificationIntent(
          dedupeKey: 'evt:$gid:normal_1',
          category: NotificationCategory.expense,
          source: NotificationSource.listener,
          gid: gid,
          groupName: 'Grup Uji',
          actorUid: 'partner',
          actorName: 'Dina',
          title: 'Dina menambah catatan',
          subtitle: 'Kopi Rp20.000',
          systemTitle: 'Grup Uji',
          systemBody: 'Dina menambah Kopi Rp20.000',
          createdAt: now,
        ),
      );
      expect(normalDecision.reason, isNot(NotificationDropReason.oldEvent));
      expect(await store.getLastDeliveredEventAt(gid), isNotNull);
      // Bersihkan timer agregasi banner (3 detik) agar test tidak meninggalkan pending timer
      await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
      expect(banners, isNotEmpty);
    });

    test('Semua aksi grup langsung tercatat dan tersiar ke watchEvents dengan tipe yang tepat', () async {
      const gid = 'grp_all_actions_rt';
      final ownerUid = authService.currentUid!;
      final now = DateTime.now();
      await groupService.saveLocalGroup(
        GroupModel(
          id: gid,
          name: 'Jajan Bareng',
          ownerUid: ownerUid,
          code: 'JJN123',
          createdAt: now.subtract(const Duration(days: 1)),
          memberCount: 2,
          wheelSlots: const [20000, 50000, 100000],
          budgetMode: 'game',
          spinPolicy: 'all',
        ),
      );

      final snapshots = <List<GroupEventModel>>[];
      final sub = groupService.watchEvents(gid).listen(snapshots.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      // 1. Roda Putar (spin)
      final spinRes = await gameService.claimSessionAndWriteResult(
        gid: gid,
        game: 'wheel',
        amount: 50000,
      );
      expect(spinRes.success, isTrue);

      // 2. Tambah & Hapus Catatan (expense, expenseDeleted)
      final noteId = await groupService.addNote(
        gid: gid,
        sessionId: spinRes.activeSession!.sessionId,
        title: 'Matcha',
        amount: 30000,
        sessionBudget: 50000,
      );
      await groupService.deleteNote(
        gid: gid,
        noteId: noteId,
        title: 'Matcha',
        amount: 30000,
        sessionBudget: 50000,
      );

      // 3. Akhiri Date (sessionEnd)
      await groupService.endSession(gid: gid);

      // 4. Permainan lain (gameResult)
      for (final game in ['dice', 'capsule', 'coin', 'envelope']) {
        final gRes = await gameService.claimSessionAndWriteResult(
          gid: gid,
          game: game,
          amount: 40000,
        );
        expect(gRes.success, isTrue);
        await groupService.endSession(gid: gid);
      }

      // 5. Ubah slot & regenerasi kode undangan
      await groupService.updateGroupSlots(gid, [10000, 30000, 75000]);
      await groupService.regenerateInviteCode(gid);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(snapshots, isNotEmpty);
      final latest = snapshots.last;
      expect(
        latest.any((e) => e.type == GroupEventType.gameResult && e.payload['game'] == 'wheel'),
        isTrue,
      );
      expect(latest.any((e) => e.type == GroupEventType.expense), isTrue);
      expect(latest.any((e) => e.type == GroupEventType.expenseDeleted), isTrue);
      expect(latest.any((e) => e.type == GroupEventType.sessionEnd), isTrue);
      expect(
        latest.where((e) => e.type == GroupEventType.gameResult).length,
        5,
      );
      expect(latest.any((e) => e.type == GroupEventType.codeChanged), isTrue);
      expect(
        latest.any(
          (e) => e.type == GroupEventType.custom && e.payload['action'] == 'update_slots',
        ),
        isTrue,
      );
    });

    testWidgets(
      'GroupActivityScreen mempertahankan seksi BARU saat snapshot member lambat, menangkap event live, dan menandai baca saat keluar',
      (tester) async {
        const gid = 'grp_act_live_screen';
        final myUid = authService.currentUid!;
        final now = DateTime.now();

        final eventsCtrl = StreamController<List<GroupEventModel>>.broadcast();
        final membersCtrl = StreamController<List<GroupMemberModel>>.broadcast();
        addTearDown(() async {
          await eventsCtrl.close();
          await membersCtrl.close();
        });

        final initialEvents = [
          GroupEventModel(
            eventId: 'evt_init_partner',
            type: GroupEventType.spin,
            actorUid: 'partner_1',
            actorName: 'Dina',
            payload: const {'budget': 100000},
            createdAt: now.subtract(const Duration(minutes: 1)),
          ),
        ];

        await groupService.saveLocalGroup(
          GroupModel(
            id: gid,
            name: 'Grup Test',
            ownerUid: myUid,
            code: 'ABC123',
            createdAt: now.subtract(const Duration(days: 1)),
            memberCount: 2,
          ),
        );
        groupService.setActiveGroupId(gid);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              activeGroupIdProvider.overrideWith((ref) => gid),
              activeGroupMembersStreamProvider.overrideWith((ref) => membersCtrl.stream),
              activeGroupEventsStreamProvider.overrideWith((ref) => eventsCtrl.stream),
            ],
            child: const MaterialApp(
              home: GroupActivityScreen(),
            ),
          ),
        );

        // Emit event awal sebelum members tiba, lalu flush postFrameCallback (_markAsRead)
        eventsCtrl.add(initialEvents);
        await tester.pump();
        await tester.pump();

        // Kemudian members baru tiba (simulasi stream lambat memuat lastReadAt baru dari markActivityAsRead)
        membersCtrl.add([
          GroupMemberModel(
            uid: myUid,
            name: 'Evan',
            colorIndex: 0,
            role: 'owner',
            joinedAt: now.subtract(const Duration(days: 1)),
            lastReadAt: now.add(const Duration(seconds: 2)),
          ),
        ]);
        await tester.pump();

        expect(find.text('BARU'), findsOneWidget);

        // Event baru masuk saat layar masih terbuka (bahkan dengan clock skew -20 detik)
        final liveEvent = GroupEventModel(
          eventId: 'evt_live_game',
          type: GroupEventType.gameResult,
          actorUid: 'partner_1',
          actorName: 'Dina',
          payload: const {'game': 'dice', 'amount': 80000},
          createdAt: now.subtract(const Duration(seconds: 20)),
        );
        eventsCtrl.add([liveEvent, ...initialEvents]);
        await tester.pump();

        expect(find.textContaining('memainkan Kocok Dadu'), findsOneWidget);
        expect(find.text('BARU'), findsOneWidget);

        // Keluar dari layar -> lastReadAt lokal harus terbarui saat dispose
        final beforeDispose = DateTime.now();
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        final afterDisposeRead = groupService.getLocalLastReadAt(gid);
        expect(afterDisposeRead, isNotNull);
        expect(
          afterDisposeRead!.millisecondsSinceEpoch >=
              beforeDispose.subtract(const Duration(seconds: 2)).millisecondsSinceEpoch,
          isTrue,
        );
      },
    );

    testWidgets(
      'GroupRealtimeNotificationListener menjaga >200 seen IDs terbaru dan tidak membuang event mitra berskew ringan',
      (tester) async {
        const gid = 'grp_listener_seen_tail';
        final myUid = authService.currentUid!;
        final now = DateTime.now();

        // Isi >200 ID lama lebih dulu agar urutan LinkedHashSet menguji eviction ekor
        final seededOldIds = List.generate(205, (i) => 'old_evt_$i');
        await prefs.setStringList('seen_group_events_$gid', seededOldIds);

        final banners = <NotificationIntent>[];
        final prevUidGetter = NotificationCoordinator.instance.currentUidGetter;
        final prevIsCurrentUser = NotificationCoordinator.instance.isCurrentUserGetter;
        NotificationCoordinator.instance.currentUidGetter = () => myUid;
        NotificationCoordinator.instance.isCurrentUserGetter = (uid) => uid == myUid;
        NotificationCoordinator.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
        NotificationCoordinator.instance.onRenderBanner = (intent) async {
          banners.add(intent);
        };
        addTearDown(() {
          NotificationCoordinator.instance.onRenderBanner = null;
          NotificationCoordinator.instance.currentUidGetter = prevUidGetter;
          NotificationCoordinator.instance.isCurrentUserGetter = prevIsCurrentUser;
        });

        final eventsCtrl = StreamController<List<GroupEventModel>>.broadcast();
        addTearDown(eventsCtrl.close);

        final group = GroupModel(
          id: gid,
          name: 'Grup Notif',
          ownerUid: myUid,
          code: 'XYZ999',
          createdAt: now.subtract(const Duration(days: 1)),
          memberCount: 2,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              activeGroupIdProvider.overrideWith((ref) => gid),
              groupNotificationSettingsProvider.overrideWith(
                (ref, arg) => ActiveGroupNotificationSettingsNotifier(
                  GroupNotificationSettingsService(prefs),
                  arg,
                ),
              ),
              activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value([
                  GroupMemberModel(
                    uid: myUid,
                    name: 'Evan',
                    colorIndex: 0,
                    role: 'owner',
                    joinedAt: now.subtract(const Duration(days: 1)),
                    lastReadAt: now.subtract(const Duration(minutes: 5)),
                  ),
                ]),
              ),
              activeGroupEventsStreamProvider.overrideWith((ref) => eventsCtrl.stream),
            ],
            child: const MaterialApp(
              home: GroupRealtimeNotificationListener(
                child: Scaffold(body: SizedBox.shrink()),
              ),
            ),
          ),
        );
        await tester.pump();

        // Snapshot 1 (initial) berisi event lama agar _isFirstEventSnapshot beralih ke false
        eventsCtrl.add([
          GroupEventModel(
            eventId: 'evt_hist_init',
            type: GroupEventType.spin,
            actorUid: 'partner_2',
            actorName: 'Bima',
            payload: const {'budget': 50000},
            createdAt: now.subtract(const Duration(minutes: 2)),
          ),
        ]);
        await tester.pump();

        // Snapshot 2 (live): event baru dari mitra dengan clock lag 45 detik (lebih lambat dari 15s!)
        eventsCtrl.add([
          GroupEventModel(
            eventId: 'evt_live_skewed_partner',
            type: GroupEventType.sessionEnd,
            actorUid: 'partner_2',
            actorName: 'Bima',
            payload: const {'status': 'lolos', 'budget': 50000, 'totalSpent': 30000},
            createdAt: now.subtract(const Duration(seconds: 45)),
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(banners.any((b) => b.dedupeKey.contains('evt_live_skewed_partner')), isTrue);
        final persistedSeen = prefs.getStringList('seen_group_events_$gid') ?? [];
        expect(persistedSeen.length, 200);
        expect(persistedSeen.contains('evt_live_skewed_partner'), isTrue);
        expect(persistedSeen.contains('old_evt_0'), isFalse);

        // Flush timer agregasi banner (3 detik) sebelum teardown widget test
        await tester.pump(const Duration(seconds: 4));
      },
    );

    test(
      'Aksi sendiri menjaga badge 0, hanya aksi anggota lain yang valid yang menaikkan badge 1..N dan reset 0 via markActivityAsRead',
      () async {
        final gid = await groupService.createGroup(
          groupName: 'Date Malam',
          creatorName: 'Evan',
          colorIndex: 0,
        );
        final myUid = authService.currentUid!;

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            groupGameServiceProvider.overrideWithValue(gameService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(activeGroupMembersStreamProvider.future);
        await container.read(activeGroupEventsStreamProvider.future);
        expect(container.read(unreadActivityCountProvider), 0);

        await Future<void>.delayed(const Duration(milliseconds: 5));

        // 1. Aksi diri sendiri (spin, tambah catatan, akhiri date) tidak memicu badge pada diri sendiri
        final spinRes = await gameService.claimSessionAndWriteResult(
          gid: gid,
          game: 'wheel',
          amount: 120000,
        );
        expect(spinRes.activeSession, isNotNull);
        await groupService.addNote(
          gid: gid,
          sessionId: spinRes.activeSession!.sessionId,
          title: 'Sushi',
          amount: 55000,
          sessionBudget: 120000,
        );
        await groupService.endSession(gid: gid);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(unreadActivityCountProvider), 0);

        // 2. Aksi anggota lain yang valid menaikkan badge 1, 2, 3 (invalid gameResult di-skip)
        final t = DateTime.now();
        final partnerEvents = [
          GroupEventModel(
            eventId: 'evt_p_1',
            type: GroupEventType.expense,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'title': 'Matcha', 'amount': 35000, 'remaining': 85000},
            createdAt: t,
          ),
          GroupEventModel(
            eventId: 'evt_p_2_del',
            type: GroupEventType.expenseDeleted,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'title': 'Es Krim', 'amount': 15000, 'remaining': 100000},
            createdAt: t.add(const Duration(milliseconds: 1)),
          ),
          GroupEventModel(
            eventId: 'evt_p_3_code',
            type: GroupEventType.codeChanged,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'code': 'NEW999'},
            createdAt: t.add(const Duration(milliseconds: 2)),
          ),
          GroupEventModel(
            eventId: 'evt_p_invalid',
            type: GroupEventType.gameResult,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'game': 'dice', 'amount': 50000, 'valid': false},
            createdAt: t.add(const Duration(milliseconds: 3)),
          ),
          GroupEventModel(
            eventId: 'evt_self_after',
            type: GroupEventType.spin,
            actorUid: myUid,
            actorName: 'Evan',
            payload: const {'budget': 100000},
            createdAt: t.add(const Duration(milliseconds: 4)),
          ),
        ];

        final partnerContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            activeGroupIdProvider.overrideWith((ref) => gid),
            activeGroupEventsStreamProvider.overrideWith(
              (ref) => Stream.value(partnerEvents),
            ),
          ],
        );
        addTearDown(partnerContainer.dispose);

        await partnerContainer.read(activeGroupMembersStreamProvider.future);
        await partnerContainer.read(activeGroupEventsStreamProvider.future);
        expect(partnerContainer.read(unreadActivityCountProvider), 3);

        // Pastikan waktu baca lebih baru dari timestamp event mitra di atas
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Buka halaman notifikasi / markActivityAsRead -> langsung reset ke 0
        await groupService.markActivityAsRead(gid);
        expect(partnerContainer.read(unreadActivityCountProvider), 0);
      },
    );

    test(
      'GroupMemberModel.fromMap(last_read_at: null) dan unreadActivityCountProvider tidak memalsukan DateTime.now() jadi 0',
      () async {
        const gid = 'grp_null_last_read';
        final myUid = authService.currentUid!;
        final now = DateTime.now();

        final parsedNullMember = GroupMemberModel.fromMap(myUid, {
          'uid': myUid,
          'name': 'Evan',
          'role': 'owner',
          'joined_at': now.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
          'last_read_at': null,
        });
        expect(parsedNullMember.lastReadAt.millisecondsSinceEpoch, 0);

        final group = GroupModel(
          id: gid,
          name: 'Jajan Null Read',
          ownerUid: myUid,
          code: 'NULL01',
          createdAt: now.subtract(const Duration(hours: 2)),
        );
        await groupService.saveLocalGroup(group);

        final events = [
          GroupEventModel(
            eventId: 'evt_unread_null_partner',
            type: GroupEventType.gameResult,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'game': 'wheel', 'amount': 150000, 'valid': true},
            createdAt: now.subtract(const Duration(minutes: 3)),
          ),
          GroupEventModel(
            eventId: 'evt_unread_null_self',
            type: GroupEventType.expense,
            actorUid: myUid,
            actorName: 'Evan',
            payload: const {'title': 'Kopi', 'amount': 20000, 'remaining': 130000},
            createdAt: now.subtract(const Duration(minutes: 2)),
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            activeGroupIdProvider.overrideWith((ref) => gid),
            activeGroupMembersStreamProvider.overrideWith(
              (ref) => Stream.value([parsedNullMember]),
            ),
            activeGroupEventsStreamProvider.overrideWith(
              (ref) => Stream.value(events),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(activeGroupMembersStreamProvider.future);
        await container.read(activeGroupEventsStreamProvider.future);
        expect(container.read(unreadActivityCountProvider), 1);

        final containerMissingMember = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            activeGroupIdProvider.overrideWith((ref) => gid),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value([])),
            activeGroupEventsStreamProvider.overrideWith(
              (ref) => Stream.value(events),
            ),
          ],
        );
        addTearDown(containerMissingMember.dispose);

        await containerMissingMember.read(activeGroupMembersStreamProvider.future);
        await containerMissingMember.read(activeGroupEventsStreamProvider.future);
        expect(containerMissingMember.read(unreadActivityCountProvider), 1);
      },
    );

    testWidgets(
      'Rute notifikasi: pelaku hanya dalam app (0 notif luar), anggota lain hanya banner saat resumed & notif luar saat paused (termasuk hapus/pengaturan)',
      (tester) async {
        const gid = 'grp_role_routing';
        final myUid = authService.currentUid!;
        final now = DateTime.now();

        final coordinator = NotificationCoordinator.instance;
        final banners = <NotificationIntent>[];
        final systems = <NotificationIntent>[];
        coordinator.onRenderBanner = (intent) async => banners.add(intent);
        coordinator.onRenderSystem = (intent) async => systems.add(intent);
        coordinator.hasSystemNotificationPermissionGetter = () async => true;

        // 1. Cek NotificationCoordinator: aksi diri sendiri tidak pernah dikirim ke sistem walau app paused
        coordinator.currentUidGetter = () => myUid;
        coordinator.isCurrentUserGetter = (uid) => uid == myUid;
        coordinator.setLifecycleState(AppLifecycleState.paused);
        final ownBgDecision = await coordinator.dispatch(
          NotificationIntent.groupEvent(
            gid: gid,
            groupName: 'Jajan',
            eventId: 'evt_own_bg',
            eventType: 'expense',
            actorUid: myUid,
            actorName: 'Evan',
            title: 'Kamu mencatat Teh',
            subtitle: 'Rp10.000',
            systemBody: 'Kamu mencatat Teh Rp10.000',
            createdAt: now,
          ),
        );
        expect(ownBgDecision.surface, NotificationSurface.dropped);
        expect(ownBgDecision.reason, NotificationDropReason.ownAction);
        expect(systems, isEmpty);

        // 2. Cek GroupRealtimeNotificationListener ketika anggota sedang di dalam aplikasi (resumed)
        final eventsCtrl = StreamController<List<GroupEventModel>>.broadcast();
        addTearDown(eventsCtrl.close);
        final group = GroupModel(
          id: gid,
          name: 'Jajan',
          ownerUid: myUid,
          code: 'RT01',
          createdAt: now.subtract(const Duration(hours: 1)),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              groupNotificationSettingsServiceProvider.overrideWithValue(
                GroupNotificationSettingsService(prefs),
              ),
              activeGroupIdProvider.overrideWith((ref) => gid),
              activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value([
                  GroupMemberModel(
                    uid: myUid,
                    name: 'Evan',
                    colorIndex: 0,
                    role: 'owner',
                    joinedAt: now.subtract(const Duration(hours: 1)),
                    lastReadAt: now.subtract(const Duration(minutes: 10)),
                  ),
                ]),
              ),
              activeGroupEventsStreamProvider.overrideWith((ref) => eventsCtrl.stream),
            ],
            child: const MaterialApp(
              home: GroupRealtimeNotificationListener(
                child: Scaffold(body: SizedBox.shrink()),
              ),
            ),
          ),
        );
        await tester.pump();

        // Snapshot awal
        eventsCtrl.add(const []);
        await tester.pump();

        coordinator.setLifecycleState(AppLifecycleState.resumed);
        // Pelaku & partner beraksi saat pengguna sedang di dalam aplikasi -> hanya banner, 0 notif luar!
        eventsCtrl.add([
          GroupEventModel(
            eventId: 'evt_fg_self',
            type: GroupEventType.expense,
            actorUid: myUid,
            actorName: 'Evan',
            payload: const {'title': 'Kopi', 'amount': 18000, 'remaining': 82000},
            createdAt: now,
          ),
          GroupEventModel(
            eventId: 'evt_fg_partner',
            type: GroupEventType.expenseDeleted,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'title': 'Boba', 'amount': 25000, 'remaining': 107000},
            createdAt: now.add(const Duration(milliseconds: 5)),
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(banners.length, 2);
        expect(systems, isEmpty);

        // Flush timer agregasi banner
        await tester.pump(const Duration(seconds: 4));

        // 3. Ketika anggota sedang di luar aplikasi (paused): hapus catatan & ubah kode dikirim ke sistem luar HP!
        banners.clear();
        coordinator.setLifecycleState(AppLifecycleState.paused);
        eventsCtrl.add([
          GroupEventModel(
            eventId: 'evt_bg_partner_code',
            type: GroupEventType.codeChanged,
            actorUid: 'uid_partner',
            actorName: 'Dina',
            payload: const {'code': 'BARU88'},
            createdAt: now.add(const Duration(seconds: 5)),
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(systems.length, 1);
        expect(systems.first.dedupeKey, contains('evt_bg_partner_code'));
        expect(banners, isEmpty);

        // Flush timer agregasi sistem (60 detik) sebelum teardown
        await tester.pump(const Duration(seconds: 61));
      },
    );

    testWidgets(
      'Logo lonceng menampilkan angka badge putih (1) pada Catatan, Main (termasuk null), dan Riwayat tanpa overflow di 320dp',
      (tester) async {
        const gid = 'grp_bell_ui_views';
        final myUid = authService.currentUid!;
        final now = DateTime.now();
        final group = GroupModel(
          id: gid,
          name: 'Jajan',
          ownerUid: myUid,
          code: 'BELL99',
          createdAt: now.subtract(const Duration(hours: 1)),
        );
        final members = [
          GroupMemberModel(
            uid: myUid,
            name: 'Evan',
            colorIndex: 0,
            role: 'owner',
            joinedAt: now.subtract(const Duration(hours: 1)),
            lastReadAt: now.subtract(const Duration(minutes: 10)),
          ),
        ];

        Widget wrapView(Widget child, {GroupModel? streamGroup}) {
          return ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              groupGameServiceProvider.overrideWithValue(gameService),
              activeGroupIdProvider.overrideWith((ref) => gid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(streamGroup),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(members),
              ),
              activeGroupNotesStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              unreadActivityCountProvider.overrideWith((ref) => 1),
              appScopeProvider.overrideWith((ref) => AppScope.grup),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 844),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Scaffold(body: child),
              ),
            ),
          );
        }

        // 1. GroupNotesView (Tab Catatan)
        await tester.pumpWidget(wrapView(const GroupNotesView(), streamGroup: group));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('1'), findsOneWidget);
        final notesBadgeText = tester.widget<Text>(find.text('1'));
        expect(notesBadgeText.style?.color, AppColors.surface);
        expect(tester.takeException(), isNull);

        // 2. GroupGamesHubView (termasuk saat group == null)
        await tester.pumpWidget(wrapView(const GroupGamesHubView(), streamGroup: null));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('1'), findsOneWidget);
        final hubBadgeText = tester.widget<Text>(find.text('1'));
        expect(hubBadgeText.style?.color, AppColors.surface);
        expect(tester.takeException(), isNull);

        // 3. GroupHistoryView (Tab Riwayat)
        await tester.pumpWidget(wrapView(const GroupHistoryView(), streamGroup: group));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('1'), findsOneWidget);
        final histBadgeText = tester.widget<Text>(find.text('1'));
        expect(histBadgeText.style?.color, AppColors.surface);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'normalizeSkewedTimestamp tetap memulihkan row +7 jam meskipun jam sekarang sudah mendekati/melewati createdAt corrupt',
      () {
        final realEventTime = DateTime(2026, 11, 13, 11, 46, 25);
        final skewedCreatedAt = realEventTime.add(const Duration(hours: 7)); // 18:46:25
        final nowInside15Min = DateTime(2026, 11, 13, 18, 34, 0);

        final normalized = GroupEventModel.normalizeSkewedTimestamp(
          'evt_${realEventTime.millisecondsSinceEpoch}_696',
          skewedCreatedAt,
          referenceNow: nowInside15Min,
        );

        expect(
          normalized.millisecondsSinceEpoch,
          realEventTime.millisecondsSinceEpoch,
        );
      },
    );

    test(
      'NotificationCoordinator menyembuhkan watermark masa depan corrupt saat paused dan tetap mengirim notif sistem spin',
      () async {
        final store = InMemoryNotifiedClaimStore();
        final coordinator = NotificationCoordinator.instance;
        coordinator.setClaimStore(store);
        final prevUid = coordinator.currentUidGetter;
        final prevIsMe = coordinator.isCurrentUserGetter;
        final prevSystem = coordinator.onRenderSystem;
        final prevPerm = coordinator.hasSystemNotificationPermissionGetter;

        final systemDelivered = <NotificationIntent>[];
        coordinator.currentUidGetter = () => 'me_uid';
        coordinator.isCurrentUserGetter = (uid) => uid == 'me_uid';
        coordinator.hasSystemNotificationPermissionGetter = () async => true;
        coordinator.onRenderSystem = (intent) async {
          systemDelivered.add(intent);
        };
        coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);

        addTearDown(() {
          coordinator.onRenderSystem = prevSystem;
          coordinator.currentUidGetter = prevUid;
          coordinator.isCurrentUserGetter = prevIsMe;
          coordinator.hasSystemNotificationPermissionGetter = prevPerm;
          coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
        });

        const gid = 'grp_poisoned_wm';
        final now = DateTime.now();
        // Simulasikan watermark lama yang corrupt +11 menit di masa depan
        await store.setLastDeliveredEventAt(
          gid,
          now.add(const Duration(minutes: 11)),
        );

        final decision = await coordinator.dispatch(
          NotificationIntent.groupEvent(
            gid: gid,
            groupName: 'budget date',
            eventId: 'evt_${now.millisecondsSinceEpoch}_430',
            eventType: 'game_result',
            actorUid: 'partner_uid',
            actorName: 'Evan',
            title: 'Evan memainkan Roda Putar: Rp150.000',
            subtitle: 'Budget baru untuk date ini',
            systemBody: 'Evan memainkan Roda Putar dan mendapat budget Rp150.000.',
            amount: 150000,
            createdAt: now,
          ),
        );

        expect(decision.surface, NotificationSurface.system);
        expect(decision.reason, NotificationDropReason.none);
        expect(systemDelivered.length, 1);
        expect(
          NotificationService.channelGroupActivityId,
          'channel_group_activity_v2',
        );
      },
    );

    test(
      'addNote tetap berhasil pada sesi aktif meskipun pernah ada penanda akhir sesi usang untuk sessionId lain/staled',
      () async {
        const gid = 'grp_active_note_safe';
        final myUid = authService.currentUid!;
        final now = DateTime.now();
        final activeSession = GroupSessionModel(
          sessionId: 'sess_live_1',
          gid: gid,
          budget: 150000,
          game: 'wheel',
          startedByUid: myUid,
          startedByName: 'Evan',
          startedAt: now.subtract(const Duration(minutes: 2)),
          budgetByUid: myUid,
          budgetByName: 'Evan',
          status: 'running',
        );
        await groupService.saveLocalGroup(
          GroupModel(
            id: gid,
            name: 'budget date',
            ownerUid: myUid,
            code: 'SAFE01',
            createdAt: now.subtract(const Duration(days: 1)),
            activeSession: activeSession,
          ),
        );
        // Simulasikan cache sesi lokal memiliki endedAt corrupt di masa lalu untuk sessionId yang sama
        await groupService.upsertLocalSession(
          gid,
          activeSession.copyWith(
            endedAt: now.subtract(const Duration(hours: 5)),
          ),
        );

        final noteId = await groupService.addNote(
          gid: gid,
          sessionId: 'sess_live_1',
          title: 'Ayam Geprek',
          amount: 35000,
          sessionBudget: 150000,
        );

        expect(noteId, startsWith('note_'));
        final saved = groupService.getLocalNotes(gid);
        expect(saved.any((n) => n.noteId == noteId && n.title == 'Ayam Geprek'), isTrue);
      },
    );

    testWidgets(
      'BottomSheet tambah catatan menampilkan error validasi inline di atas tombol dan langsung tersimpan saat valid',
      (tester) async {
        const gid = 'grp_add_note_sheet';
        final myUid = authService.currentUid!;
        final now = DateTime.now();
        final activeSession = GroupSessionModel(
          sessionId: 'sess_sheet_1',
          gid: gid,
          budget: 150000,
          game: 'wheel',
          startedByUid: myUid,
          startedByName: 'Evan',
          startedAt: now.subtract(const Duration(minutes: 1)),
          budgetByUid: myUid,
          budgetByName: 'Evan',
          status: 'running',
        );
        final group = GroupModel(
          id: gid,
          name: 'budget date',
          ownerUid: myUid,
          code: 'NOTE99',
          createdAt: now.subtract(const Duration(days: 1)),
          activeSession: activeSession,
        );
        await groupService.saveLocalGroup(group);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              groupGameServiceProvider.overrideWithValue(gameService),
              activeGroupIdProvider.overrideWith((ref) => gid),
              activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
              activeGroupNotesStreamProvider.overrideWith(
                (ref) => groupService.watchNotes(gid, activeSession.sessionId),
              ),
              unreadActivityCountProvider.overrideWith((ref) => 0),
              appScopeProvider.overrideWith((ref) => AppScope.grup),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const GroupNotesView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Buka bottom sheet tambah catatan
        await tester.tap(find.text('Catat jajan'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('add_group_note_title_field')), findsOneWidget);
        expect(find.byKey(const ValueKey('save_group_note_button')), findsOneWidget);

        // 1. Tap simpan saat nama kosong -> error validasi terlihat jelas di dalam sheet
        await tester.ensureVisible(find.byKey(const ValueKey('save_group_note_button')));
        await tester.tap(find.byKey(const ValueKey('save_group_note_button')));
        await tester.pump();
        expect(find.byKey(const ValueKey('sheet_inline_error_banner')), findsOneWidget);
        expect(find.text('Masukkan nama pengeluaran terlebih dahulu'), findsOneWidget);

        // 2. Isi nama tapi nominal masih kosong -> pesan error berganti
        await tester.enterText(
          find.byKey(const ValueKey('add_group_note_title_field')),
          'Matcha Latte',
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('sheet_inline_error_banner')), findsNothing);

        await tester.ensureVisible(find.byKey(const ValueKey('save_group_note_button')));
        await tester.tap(find.byKey(const ValueKey('save_group_note_button')));
        await tester.pump();
        expect(find.text('Masukkan nominal belanja yang valid'), findsOneWidget);

        // 3. Isi nominal valid lalu simpan -> sheet menutup & catatan tersimpan
        await tester.enterText(
          find.byKey(const ValueKey('add_group_note_amount_field')),
          '28000',
        );
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('save_group_note_button')));
        await tester.tap(find.byKey(const ValueKey('save_group_note_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('save_group_note_button')), findsNothing);
        final storedNotes = groupService.getLocalNotes(gid);
        expect(
          storedNotes.any((n) => n.title == 'Matcha Latte' && n.amount == 28000),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

