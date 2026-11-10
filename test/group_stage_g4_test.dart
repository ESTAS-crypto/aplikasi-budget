import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/activity_tile.dart';
import 'package:putar_jajan/core/group/widgets/sync_legend.dart';
import 'package:putar_jajan/features/group/screens/group_wheel_view.dart';
import 'package:putar_jajan/features/group/screens/group_activity_screen.dart';
import 'package:putar_jajan/core/group/widgets/group_realtime_listener.dart';
import 'package:putar_jajan/core/group/services/clock_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
  });

  group('G4: GroupEventModel & ActivityTile Unit Tests', () {
    test('GroupEventModel correctly generates formatted summary', () {
      final now = DateTime.now();
      final spinEvent = GroupEventModel(
        eventId: 'e1',
        type: GroupEventType.spin,
        actorUid: 'u1',
        actorName: 'Raka',
        payload: {'budget': 150000},
        createdAt: now,
      );
      expect(spinEvent.formattedSummary, contains('Raka memutar roda: Rp150.000'));

      final expenseEvent = GroupEventModel(
        eventId: 'e2',
        type: GroupEventType.expense,
        actorUid: 'u2',
        actorName: 'Dina',
        summary: 'Dina menambahkan Rp30.000 untuk sate taichan. Sisa Rp170.000.',
        payload: {'amount': 30000},
        createdAt: now,
      );
      expect(expenseEvent.formattedSummary, 'Dina menambahkan Rp30.000 untuk sate taichan. Sisa Rp170.000.');
    });

    testWidgets('ActivityTile renders actorName, summary, and indicator', (tester) async {
      final now = DateTime.now();
      final event = GroupEventModel(
        eventId: 'e1',
        type: GroupEventType.expense,
        actorUid: 'u1',
        actorName: 'Dina',
        summary: 'Dina mencatat martabak',
        payload: {},
        createdAt: now,
      );

      // Unread tile
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityTile(
              event: event,
              isUnread: true,
              isMe: false,
              colorIndex: 1,
            ),
          ),
        ),
      );

      expect(find.text('Dina mencatat martabak'), findsOneWidget);
      expect(find.text('Baru saja'), findsOneWidget);

      // Aksi sendiri (isMe == true)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityTile(
              event: event,
              isUnread: false,
              isMe: true,
              colorIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('Kamu mencatat martabak'), findsOneWidget);
    });
  });

  group('G4: Layar 20 GroupActivityScreen Widget Tests', () {
    testWidgets('GroupActivityScreen renders BARU, SEBELUMNYA, and SyncLegend', (tester) async {
      final now = DateTime.now();
      await testAuthService.ensureSignedIn();
      await testAuthService.setDisplayName('Saya');
      final myUid = testAuthService.currentUid!;
      await testGroupService.setActiveGroupId('grp_1');

      final members = [
        GroupMemberModel(
          uid: myUid,
          name: 'Saya',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now.subtract(const Duration(days: 2)),
          lastReadAt: now.subtract(const Duration(minutes: 10)),
        ),
        GroupMemberModel(
          uid: 'uid_dina',
          name: 'Dina',
          colorIndex: 1,
          role: 'member',
          joinedAt: now.subtract(const Duration(days: 1)),
          lastReadAt: now.subtract(const Duration(minutes: 5)),
        ),
      ];

      final events = [
        // Unread from Dina (5 minutes ago > myMember.lastReadAt 10 minutes ago)
        GroupEventModel(
          eventId: 'e_new',
          type: GroupEventType.expense,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          summary: 'Dina mencatat boba',
          payload: {},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        // Previous event (15 minutes ago < myMember.lastReadAt 10 minutes ago)
        GroupEventModel(
          eventId: 'e_old',
          type: GroupEventType.spin,
          actorUid: 'uid_dina',
          actorName: 'Dina',
          summary: 'Dina memutar roda: Rp200.000',
          payload: {'budget': 200000},
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
            activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
          ],
          child: const MaterialApp(
            home: GroupActivityScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aktivitas grup'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Roda'), findsOneWidget);
      expect(find.text('Catatan'), findsOneWidget);

      expect(find.text('BARU'), findsOneWidget);
      expect(find.text('Dina mencatat boba'), findsOneWidget);

      expect(find.text('SEBELUMNYA'), findsOneWidget);
      expect(find.text('Dina memutar roda: Rp200.000'), findsOneWidget);

      // Verify SyncLegend is rendered at the bottom
      expect(find.byType(SyncLegend), findsOneWidget);

      // Filter to Roda
      await tester.tap(find.text('Roda'));
      await tester.pumpAndSettle();
      expect(find.text('Dina mencatat boba'), findsNothing);
      expect(find.text('Dina memutar roda: Rp200.000'), findsOneWidget);

      // Filter to Catatan
      await tester.tap(find.text('Catatan'));
      await tester.pumpAndSettle();
      expect(find.text('Dina mencatat boba'), findsOneWidget);
      expect(find.text('Dina memutar roda: Rp200.000'), findsNothing);
    });
  });

  group('G4: Layar 18 GroupWheelView Widget Tests', () {
    testWidgets('GroupWheelView renders wheel, presence, last spin card, and unread bell badge', (tester) async {
      await testPrefs.setString(GroupAuthService.keyFallbackUid, 'uid_1');
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
      final now = DateTime.now();
      final activeGroup = GroupModel(
        id: 'grp_1',
        name: 'Date Jumat',
        ownerUid: 'uid_1',
        code: 'JMT123',
        createdAt: now,
        memberCount: 2,
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 200000,
          startedByUid: 'uid_2',
          startedByName: 'Dina',
          startedAt: now.subtract(const Duration(minutes: 2)),
        ),
      );

      final members = [
        GroupMemberModel(
          uid: 'uid_1',
          name: 'Raka',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now,
          lastReadAt: now.subtract(const Duration(minutes: 20)),
          lastSeenAt: now,
        ),
        GroupMemberModel(
          uid: 'uid_2',
          name: 'Dina',
          colorIndex: 1,
          role: 'member',
          joinedAt: now,
          lastReadAt: now,
          lastSeenAt: now,
        ),
      ];

      final notes = [
        GroupNoteModel(
          noteId: 'n1',
          sessionId: 'sess_1',
          authorUid: 'uid_2',
          authorName: 'Dina',
          title: 'Sate Taichan',
          amount: 30000,
          createdAt: now,
          hasPendingWrites: false,
        ),
      ];

      final events = [
        GroupEventModel(
          eventId: 'e1',
          type: GroupEventType.expense,
          actorUid: 'uid_2',
          actorName: 'Dina',
          summary: 'Dina mencatat sate',
          payload: {},
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ];

      await testPrefs.setString(GroupAuthService.keyFallbackUid, 'uid_1');
      await testPrefs.setString(GroupAuthService.keyDisplayName, 'Raka');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
            activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value(notes)),
            activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
          ],
          child: const MaterialApp(
            home: GroupWheelView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top title
      expect(find.text('Putar Jajan'), findsOneWidget);

      // Presence
      expect(find.text('2 anggota online'), findsOneWidget);

      // Last spin card: Dina memutar roda
      expect(find.text('Dina memutar roda'), findsOneWidget);

      // Budget summary bar: 200.000 - 30.000 = 170.000
      expect(find.text('Sisa budget grup'), findsOneWidget);
      expect(find.text('Rp170.000 / Rp200.000'), findsOneWidget);

      // Putar Roda / Ulangi budget button
      expect(find.text('ULANGI BUDGET'), findsOneWidget);
    });

    testWidgets('Layar 18 & Layar 20 render on 320dp and 390dp with textScale 1.3 without overflow', (tester) async {
      const widths = [320.0, 390.0];
      final now = DateTime.now();

      final activeGroup = GroupModel(
        id: 'grp_1',
        name: 'Grup Jajan Weekend Super Panjang Sekali',
        ownerUid: 'uid_1',
        code: 'JMT123',
        createdAt: now,
        memberCount: 2,
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 200000,
          startedByUid: 'uid_1',
          startedByName: 'Budi Santoso',
          startedAt: now,
        ),
      );

      final members = [
        GroupMemberModel(
          uid: 'uid_1',
          name: 'Budi Santoso',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now,
          lastReadAt: now,
          lastSeenAt: now,
        ),
      ];

      final events = [
        GroupEventModel(
          eventId: 'e1',
          type: GroupEventType.expense,
          actorUid: 'uid_1',
          actorName: 'Budi Santoso',
          summary: 'Budi Santoso mencatat martabak spesial coklat keju',
          payload: {},
          createdAt: now,
        ),
      ];

      for (final w in widths) {
        tester.view.physicalSize = Size(w * 2.0, 800 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        // 1. Layar 18 (GroupWheelView)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(testPrefs),
              groupAuthServiceProvider.overrideWithValue(testAuthService),
              groupServiceProvider.overrideWithValue(testGroupService),
              activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
              activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
              activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value([])),
              activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
            ],
            child: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: GroupWheelView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layar 18 no overflow on $w dp');

        // 2. Layar 20 (GroupActivityScreen)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(testPrefs),
              groupAuthServiceProvider.overrideWithValue(testAuthService),
              groupServiceProvider.overrideWithValue(testGroupService),
              activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
              activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
              activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value([])),
              activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value(events)),
            ],
            child: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: GroupActivityScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layar 20 no overflow on $w dp');
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Live spectator mode triggers wheel spinning and shows spectator badge', (tester) async {
      final now = DateTime.now();
      final myUid = testAuthService.currentUid!;
      final clockSync = ClockSyncService();
      addTearDown(() => clockSync.stopPeriodicSync());
      await testGroupService.setActiveGroupId('grp_spectator');

      final activeGroup = GroupModel(
        id: 'grp_spectator',
        name: 'Grup Spectator',
        ownerUid: 'owner_uid',
        code: 'SPC123',
        createdAt: now,
        memberCount: 2,
        playPolicy: 'owner',
      );

      final members = [
        GroupMemberModel(
          uid: 'owner_uid',
          name: 'Evan Pemilik',
          colorIndex: 0,
          role: 'owner',
          joinedAt: now,
          lastReadAt: now,
          lastSeenAt: now,
        ),
        GroupMemberModel(
          uid: myUid,
          name: 'Spectator User',
          colorIndex: 1,
          role: 'member',
          joinedAt: now,
          lastReadAt: now,
          lastSeenAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
            clockSyncServiceProvider.overrideWithValue(clockSync),
            activeGroupIdProvider.overrideWith((ref) => 'grp_spectator'),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
            activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value([])),
            activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: GroupRealtimeNotificationListener(
              child: GroupWheelView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially spectator sees waiting button
      expect(find.text('Hanya pemilik yang bisa memutar'), findsOneWidget);

      // Owner broadcasts live spin
      await testGroupService.broadcastLiveSpin(
        gid: 'grp_spectator',
        actorUid: 'owner_uid',
        actorName: 'Evan Pemilik',
        targetDegree: 1800.0,
        winningIndex: 3,
        budget: 100000,
        durationMs: 5000,
      );

      // Pump to trigger stream delivery microtask and then pump frame
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Spectator badge and live overlay appear
      expect(find.text('SIARAN LANGSUNG'), findsOneWidget);
      expect(find.text('Evan Pemilik memutar roda!'), findsOneWidget);

      // Fast forward clock past duration (6000ms > 5000ms)
      clockSync.setOffsetForTesting(6000);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      // Results shown in overlay
      expect(find.text('🎯 Roda mendarat pada hasil budget!'), findsOneWidget);
      expect(find.text('Rp100.000'), findsOneWidget);

      // Settle any pending countdown timers
      await tester.pump(const Duration(seconds: 4));
      clockSync.stopPeriodicSync();
    });

    test('Layar 53 & 54: GroupModel & GroupService Budget Settings & Fixed Mode', () async {
      final group = GroupModel(
        id: 'grp_budget_test',
        name: 'Grup Budget Date',
        ownerUid: 'owner_1',
        code: 'BDG123',
        createdAt: DateTime.now(),
        budgetMode: 'fixed',
        fixedBudget: 250000,
        spinPolicy: 'all',
      );

      final map = group.toMap();
      expect(map['budgetMode'], 'fixed');
      expect(map['fixedBudget'], 250000);
      expect(map['spinPolicy'], 'all');

      final fromMap = GroupModel.fromMap(group.id, map);
      expect(fromMap.budgetMode, 'fixed');
      expect(fromMap.fixedBudget, 250000);
      expect(fromMap.spinPolicy, 'all');

      // Update budget settings via GroupService
      await testGroupService.createGroup(
        groupName: 'Grup Budget Test',
        creatorName: 'Evan Owner',
        colorIndex: 0,
      );
      final created = testGroupService.getLocalGroup(testGroupService.getActiveGroupId()!);
      expect(created, isNotNull);
      expect(created!.budgetMode, 'game'); // default
      expect(created.fixedBudget, 200000); // default
      expect(created.spinPolicy, 'all'); // default

      await testGroupService.updateGroupBudgetSettings(
        gid: created.id,
        budgetMode: 'fixed',
        fixedBudget: 350000,
        spinPolicy: 'all',
      );

      final updated = testGroupService.getLocalGroup(created.id);
      expect(updated!.budgetMode, 'fixed');
      expect(updated.fixedBudget, 350000);
      expect(updated.spinPolicy, 'all');

      // Start fixed session
      await testGroupService.startFixedSession(
        gid: created.id,
        fixedBudget: 350000,
      );

      final withSession = testGroupService.getLocalGroup(created.id);
      expect(withSession!.activeSession, isNotNull);
      expect(withSession.activeSession!.budget, 350000);
    });
  });
}

