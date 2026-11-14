import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/models/group_history_models.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/group_important_dialog.dart';
import 'package:putar_jajan/core/group/widgets/group_realtime_listener.dart';
import 'package:putar_jajan/core/notifications/coordinator/notification_coordinator.dart';
import 'package:putar_jajan/core/painters/confetti_painter.dart';
import 'package:putar_jajan/core/theme/app_colors.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/features/group/screens/group_date_detail_screen.dart';
import 'package:putar_jajan/features/group/screens/group_date_result_screen.dart';
import 'package:putar_jajan/features/group/screens/group_notes_view.dart';
import 'package:putar_jajan/features/navigation/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testGid = 'grp_h6_test';
  const ownerUid = 'uid_owner';
  const rakaUid = 'uid_raka';
  const bimaUid = 'uid_bima';

  final emojiRegex = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  void expectNoIconsOrEmojiInTree(WidgetTester tester) {
    expect(find.byType(Icon), findsNothing);
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      final content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      expect(
        emojiRegex.hasMatch(content),
        isFalse,
        reason: 'Ditemukan emoji pada teks "$content"',
      );
    }
  }

  Future<(SharedPreferences, GroupAuthService, GroupService)> setupServices({
    String uid = ownerUid,
    String displayName = 'Kamu',
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(GroupAuthService.keyFallbackUid, uid);
    await prefs.setString(GroupAuthService.keyDisplayName, displayName);
    final authService = GroupAuthService(auth: null, prefs: prefs);
    final groupService = GroupService(
      firestore: null,
      authService: authService,
      prefs: prefs,
    );
    await groupService.setActiveGroupId(testGid);
    return (prefs, authService, groupService);
  }

  group('Layar 67 (Hgrup3) — Konfirmasi Akhiri Date & Tombol Owner', () {
    testWidgets(
      'Layar 67 renders preview Lolos & Lewat pada 320dp dan 390dp textScale 1.3 tanpa overflow & tanpa Icons/emoji',
      (tester) async {
        const widths = [320.0, 390.0];
        for (final width in widths) {
          for (final disableAnim in [false, true]) {
            tester.view.physicalSize = Size(width, 720);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            bool? dialogResult;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 720),
                    textScaler: const TextScaler.linear(1.3),
                    disableAnimations: disableAnim,
                  ),
                  child: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            dialogResult = await GroupImportantDialog
                                .showConfirmEndGroupSession(
                              context,
                              groupName: 'Grup Jajan Panjang Banget',
                              budget: 200000,
                              totalSpent: disableAnim ? 235000 : 150000,
                              itemCount: 3,
                            );
                          },
                          child: const Text('Buka Dialog'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.tap(find.text('Buka Dialog'));
            await tester.pump(const Duration(milliseconds: 500));

            expect(tester.takeException(), isNull);
            expect(find.text('Selesaikan date ini?'), findsOneWidget);
            expect(find.text('Budget Rp200.000'), findsOneWidget);
            expect(find.text('3 catatan'), findsOneWidget);
            expect(find.text('Batal'), findsOneWidget);
            expect(find.text('Selesaikan'), findsOneWidget);
            if (disableAnim) {
              expect(find.text('Terpakai Rp235.000'), findsOneWidget);
              expect(find.textContaining('Lewat Rp35.000'), findsOneWidget);
            } else {
              expect(find.text('Terpakai Rp150.000'), findsOneWidget);
              expect(
                find.textContaining('Lolos, hemat Rp50.000'),
                findsOneWidget,
              );
            }
            expectNoIconsOrEmojiInTree(tester);

            await tester.tap(find.text('Selesaikan'));
            await tester.pump(const Duration(milliseconds: 250));
            expect(dialogResult, isTrue);
          }
        }
      },
    );

    testWidgets(
      'GroupNotesView hanya menampilkan Selesaikan date + caption untuk pemilik grup (tidak untuk member)',
      (tester) async {
        final now = DateTime.now();
        final activeGroup = GroupModel(
          id: testGid,
          name: 'Date Jumat',
          ownerUid: ownerUid,
          code: 'H6CODE',
          createdAt: now,
          memberCount: 2,
          activeSession: GroupSessionModel(
            sessionId: 'sess_owner_btn',
            budget: 150000,
            startedByUid: ownerUid,
            startedByName: 'Kamu',
            startedAt: now,
          ),
        );

        // Non-owner view
        final (memberPrefs, memberAuth, memberGroupSvc) = await setupServices(
          uid: rakaUid,
          displayName: 'Raka',
        );
        await memberGroupSvc.saveLocalGroup(activeGroup);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(memberPrefs),
              groupAuthServiceProvider.overrideWithValue(memberAuth),
              groupServiceProvider.overrideWithValue(memberGroupSvc),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(activeGroup),
              ),
              activeGroupNotesStreamProvider.overrideWith(
                (ref) => Stream.value(const <GroupNoteModel>[]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const GroupNotesView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Catat jajan'), findsOneWidget);
        expect(find.text('Selesaikan date'), findsNothing);
        expect(
          find.text('Tombol Selesaikan date hanya tampil untuk pemilik grup'),
          findsNothing,
        );

        // Owner view
        final (ownerPrefs, ownerAuth, ownerGroupSvc) = await setupServices(
          uid: ownerUid,
          displayName: 'Kamu',
        );
        await ownerGroupSvc.saveLocalGroup(activeGroup);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(ownerPrefs),
              groupAuthServiceProvider.overrideWithValue(ownerAuth),
              groupServiceProvider.overrideWithValue(ownerGroupSvc),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(activeGroup),
              ),
              activeGroupNotesStreamProvider.overrideWith(
                (ref) => Stream.value(const <GroupNoteModel>[]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const GroupNotesView(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Catat jajan'), findsOneWidget);
        expect(find.text('Selesaikan date'), findsOneWidget);
        expect(
          find.text('Tombol Selesaikan date hanya tampil untuk pemilik grup'),
          findsOneWidget,
        );
      },
    );
  });

  group('Layar 68 (Hgrup1) & Layar 69 (Hgrup2) — Hasil Date Grup', () {
    final fourMembers = <MemberSpendingSummary>[
      const MemberSpendingSummary(
        uid: bimaUid,
        name: 'Bima',
        colorIndex: 3,
        amountSpent: 20000,
        noteCount: 1,
        percentageOfTotalSpent: 0.2,
      ),
      const MemberSpendingSummary(
        uid: ownerUid,
        name: 'Kamu',
        colorIndex: 1,
        amountSpent: 45000,
        noteCount: 2,
        percentageOfTotalSpent: 0.45,
      ),
      const MemberSpendingSummary(
        uid: rakaUid,
        name: 'Raka',
        colorIndex: 2,
        amountSpent: 35000,
        noteCount: 1,
        percentageOfTotalSpent: 0.35,
      ),
      const MemberSpendingSummary(
        uid: 'uid_dina',
        name: 'Dina',
        colorIndex: 0,
        amountSpent: 0,
        noteCount: 0,
        percentageOfTotalSpent: 0,
      ),
    ];

    final fiveMembers = <MemberSpendingSummary>[
      ...fourMembers,
      const MemberSpendingSummary(
        uid: 'uid_sari',
        name: 'Sari',
        colorIndex: 4,
        amountSpent: 15000,
        noteCount: 1,
        percentageOfTotalSpent: 0.13,
      ),
    ];

    testWidgets(
      'Layar 68 Lolos & Layar 69 Lewat render mulus pada 320dp & 390dp textScale 1.3, hormati disableAnimations & urutan netral',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        try {
          final (prefs, authService, groupService) = await setupServices();
        for (final width in [320.0, 390.0]) {
          for (final disableAnim in [false, true]) {
            tester.view.physicalSize = Size(width, 760);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            // Layar 68 (Lolos) dengan 4 anggota -> Row horizontal
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(prefs),
                  groupAuthServiceProvider.overrideWithValue(authService),
                  groupServiceProvider.overrideWithValue(groupService),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 760),
                      textScaler: const TextScaler.linear(1.3),
                      disableAnimations: disableAnim,
                    ),
                    child: GroupDateResultScreen(
                      groupName: 'Grup Jajan Jumat Super Panjang',
                      budget: 200000,
                      totalSpent: 100000,
                      itemCount: 4,
                      budgetByName: 'Dina',
                      budgetGame: 'dice',
                      endedByName: 'Kamu',
                      endedByUid: ownerUid,
                      sessionDate: DateTime(2026, 10, 23, 19, 0),
                      endedAt: DateTime(2026, 10, 23, 20, 48),
                      memberSpendings: fourMembers,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 150));
            await tester.pump(const Duration(milliseconds: 500));

            expect(tester.takeException(), isNull);
            final scaffoldLolos = tester.widget<Scaffold>(find.byType(Scaffold));
            expect(scaffoldLolos.backgroundColor, AppColors.mint);
            expect(find.text('Lolos budget!'), findsOneWidget);
            expect(find.text('Grup hemat'), findsOneWidget);
            expect(find.text('PENGELUARAN PER ORANG'), findsOneWidget);
            expect(
              find.text('Penentu budget: Dina · Kocok Dadu'),
              findsOneWidget,
            );
            expect(
              find.byType(ConfettiField),
              disableAnim ? findsNothing : findsOneWidget,
            );

            // Urutan netral sesuai input, tanpa label juara/boros
            final bimaX = tester.getTopLeft(find.text('Bima')).dx;
            final kamuX = tester.getTopLeft(find.text('Kamu')).dx;
            final rakaX = tester.getTopLeft(find.text('Raka')).dx;
            expect(bimaX, lessThan(kamuX));
            expect(kamuX, lessThan(rakaX));
            expect(find.textContaining('#1'), findsNothing);
            expect(find.textContaining('Juara'), findsNothing);
            expect(find.textContaining('Boros'), findsNothing);

            // TalkBack semantics & bebas Icon/emoji
            expect(find.bySemanticsLabel('Lihat detail date'), findsOneWidget);
            expect(find.bySemanticsLabel('Bagikan hasil date'), findsOneWidget);
            expect(find.bySemanticsLabel('Tutup hasil date'), findsOneWidget);
            expectNoIconsOrEmojiInTree(tester);

            // Layar 69 (Lewat) dengan 5 anggota -> Wrap
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(prefs),
                  groupAuthServiceProvider.overrideWithValue(authService),
                  groupServiceProvider.overrideWithValue(groupService),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 760),
                      textScaler: const TextScaler.linear(1.3),
                      disableAnimations: disableAnim,
                    ),
                    child: GroupDateResultScreen(
                      groupName: 'Grup Jajan Jumat',
                      budget: 100000,
                      totalSpent: 115000,
                      itemCount: 5,
                      budgetByName: 'Raka',
                      budgetGame: 'wheel',
                      endedByName: 'Kamu',
                      endedByUid: ownerUid,
                      sessionDate: DateTime(2026, 10, 23, 19, 0),
                      endedAt: DateTime(2026, 10, 23, 20, 48),
                      memberSpendings: fiveMembers,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 150));
            await tester.pump(const Duration(milliseconds: 500));

            expect(tester.takeException(), isNull);
            final scaffoldLewat = tester.widget<Scaffold>(find.byType(Scaffold));
            expect(scaffoldLewat.backgroundColor, const Color(0xFFFFC9BE));
            expect(find.text('Budget lewat Rp15.000'), findsOneWidget);
            expect(
              find.text('Gak apa-apa, catat dan putar lagi minggu depan'),
              findsOneWidget,
            );
            expect(find.byType(ConfettiField), findsNothing);
            expectNoIconsOrEmojiInTree(tester);
          }
        }
        } finally {
          semanticsHandle.dispose();
        }
      },
    );
  });

  group('Idempotensi endSession & Aturan Catatan Offline 24 Jam', () {
    test(
      'endSession idempoten saat dipanggil bersamaan ganda & setelah sesi selesai',
      () async {
        final (_, _, groupService) = await setupServices();
        final startedAt = DateTime.now().subtract(const Duration(hours: 1));
        const sid = 'sess_idempotent';

        await groupService.saveLocalGroup(
          GroupModel(
            id: testGid,
            name: 'Grup Idempoten',
            ownerUid: ownerUid,
            code: 'IDEMP1',
            createdAt: startedAt,
            memberCount: 2,
            activeSession: GroupSessionModel(
              sessionId: sid,
              budget: 100000,
              startedByUid: ownerUid,
              startedByName: 'Kamu',
              startedAt: startedAt,
            ),
          ),
        );
        await groupService.saveLocalNotes(testGid, [
          GroupNoteModel(
            noteId: 'n1',
            sessionId: sid,
            authorUid: ownerUid,
            authorName: 'Kamu',
            title: 'Kopi',
            amount: 30000,
            createdAt: startedAt.add(const Duration(minutes: 10)),
          ),
          GroupNoteModel(
            noteId: 'n2',
            sessionId: sid,
            authorUid: rakaUid,
            authorName: 'Raka',
            title: 'Roti',
            amount: 20000,
            createdAt: startedAt.add(const Duration(minutes: 20)),
          ),
        ]);

        // Panggilan ganda bersamaan + panggilan ketiga berurutan
        final concurrentResults = await Future.wait([
          groupService.endSession(gid: testGid),
          groupService.endSession(gid: testGid),
        ]);
        final thirdResult = await groupService.endSession(gid: testGid);

        expect(concurrentResults[0], isNotNull);
        expect(concurrentResults[0]!.sessionId, sid);
        expect(concurrentResults[0]!.status, 'lolos');
        expect(concurrentResults[0]!.totalSpent, 50000);
        expect(concurrentResults[0]!.endedAt, isNotNull);
        expect(concurrentResults[1]?.sessionId, sid);
        expect(thirdResult, isNull);

        expect(groupService.getLocalGroup(testGid)?.activeSession, isNull);
        final storedSessions = groupService
            .getLocalSessions(testGid)
            .where((s) => s.sessionId == sid)
            .toList();
        expect(storedSessions.length, 1);
        expect(storedSessions.first.totalSpent, 50000);
        expect(storedSessions.first.status, 'lolos');

        final endEvents = groupService
            .getLocalEvents(testGid)
            .where((e) => e.type == GroupEventType.sessionEnd)
            .toList();
        expect(endEvents.length, 1);
      },
    );

    test(
      'addNote menerima catatan offline <= endedAt dalam 24 jam + hitung ulang + emit Hasil date diperbarui, namun menolak > 24 jam atau pasca endedAt',
      () async {
        final (_, _, groupService) = await setupServices();
        final now = DateTime.now();
        final endedRecently = now.subtract(const Duration(hours: 2));
        const recentSid = 'sess_recent_ended';

        await groupService.saveLocalGroup(
          GroupModel(
            id: testGid,
            name: 'Grup Offline 24h',
            ownerUid: ownerUid,
            code: 'OFF24H',
            createdAt: now.subtract(const Duration(days: 2)),
            memberCount: 2,
          ),
        );
        await groupService.upsertLocalSession(
          testGid,
          GroupSessionModel(
            sessionId: recentSid,
            gid: testGid,
            startedAt: now.subtract(const Duration(hours: 4)),
            startedByUid: ownerUid,
            startedByName: 'Kamu',
            endedAt: endedRecently,
            endedByUid: ownerUid,
            endedByName: 'Kamu',
            budget: 100000,
            game: 'wheel',
            status: 'lolos',
            totalSpent: 70000,
          ),
        );
        await groupService.saveLocalNotes(testGid, [
          GroupNoteModel(
            noteId: 'n_existing',
            sessionId: recentSid,
            authorUid: ownerUid,
            authorName: 'Kamu',
            title: 'Ramen',
            amount: 70000,
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
        ]);

        // Case A: clientCreatedAt <= endedAt & synced <= 24h -> diterima & dihitung ulang
        await groupService.addNote(
          gid: testGid,
          sessionId: recentSid,
          title: 'Es Krim Offline',
          amount: 50000,
          clientCreatedAt: now.subtract(const Duration(hours: 3)),
        );

        final updatedSession = groupService
            .getLocalSessions(testGid)
            .firstWhere((s) => s.sessionId == recentSid);
        expect(updatedSession.totalSpent, 120000);
        expect(updatedSession.status, 'lewat');

        final recalcEvents = groupService
            .getLocalEvents(testGid)
            .where(
              (e) =>
                  e.type == GroupEventType.custom &&
                  e.payload['action'] == 'session_result_updated',
            )
            .toList();
        expect(recalcEvents.length, 1);
        expect(recalcEvents.first.summary, contains('Hasil date diperbarui'));

        // Case B: clientCreatedAt > endedAt -> ditolak
        await expectLater(
          groupService.addNote(
            gid: testGid,
            sessionId: recentSid,
            title: 'Pasca Date',
            amount: 10000,
            clientCreatedAt: endedRecently.add(const Duration(minutes: 5)),
          ),
          throwsStateError,
        );

        // Case C: sesi sudah berakhir > 24 jam -> ditolak walau clientCreatedAt <= endedAt
        final endedOld = now.subtract(const Duration(hours: 25));
        const oldSid = 'sess_expired_25h';
        await groupService.upsertLocalSession(
          testGid,
          GroupSessionModel(
            sessionId: oldSid,
            gid: testGid,
            startedAt: now.subtract(const Duration(hours: 27)),
            startedByUid: ownerUid,
            startedByName: 'Kamu',
            endedAt: endedOld,
            endedByUid: ownerUid,
            endedByName: 'Kamu',
            budget: 100000,
            game: 'wheel',
            status: 'lolos',
            totalSpent: 40000,
          ),
        );

        await expectLater(
          groupService.addNote(
            gid: testGid,
            sessionId: oldSid,
            title: 'Telat 25 Jam',
            amount: 15000,
            clientCreatedAt: endedOld.subtract(const Duration(minutes: 10)),
          ),
          throwsStateError,
        );
      },
    );
  });

  group('Broadcast Hasil Serentak (GroupRealtimeNotificationListener)', () {
    testWidgets(
      'Membuka /group/date-result 1x saat event live di foreground; melewati saat background, duplikat sessionId, dan offline reconnect',
      (tester) async {
        NotificationCoordinator.instance.didChangeAppLifecycleState(
          AppLifecycleState.resumed,
        );
        addTearDown(() {
          NotificationCoordinator.instance.didChangeAppLifecycleState(
            AppLifecycleState.resumed,
          );
        });

        final (prefs, authService, groupService) = await setupServices(
          uid: bimaUid,
          displayName: 'Bima',
        );
        final now = DateTime.now();
        final group = GroupModel(
          id: testGid,
          name: 'Date Bareng',
          ownerUid: ownerUid,
          code: 'LIVE12',
          createdAt: now.subtract(const Duration(days: 1)),
          memberCount: 2,
        );
        await groupService.saveLocalGroup(group);

        final eventsController =
            StreamController<List<GroupEventModel>>.broadcast();
        addTearDown(() => eventsController.close());

        final router = GoRouter(
          navigatorKey: rootNavigatorKey,
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home Grup')),
            ),
            GoRoute(
              path: '/group/date-result',
              builder: (_, state) {
                final qp = state.uri.queryParameters;
                return GroupDateResultScreen(
                  groupName: qp['groupName'] ?? 'Grup',
                  budget: int.tryParse(qp['budget'] ?? '') ?? 0,
                  totalSpent: int.tryParse(qp['totalSpent'] ?? '') ?? 0,
                  itemCount: int.tryParse(qp['itemCount'] ?? '') ?? 0,
                  groupId: qp['gid'],
                  sessionId: qp['sessionId'],
                );
              },
            ),
          ],
        );
        addTearDown(() => router.dispose());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              activeGroupIdProvider.overrideWith((ref) => testGid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(group),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(const <GroupMemberModel>[]),
              ),
              activeGroupEventsStreamProvider.overrideWith(
                (ref) => eventsController.stream,
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
              builder: (context, child) => GroupRealtimeNotificationListener(
                onNavigateRoute: (route) => router.push(route),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // 1. Live foreground event dari pemilik lain -> auto-navigasi ke /group/date-result
        final liveEvt = GroupEventModel(
          eventId: 'evt_end_live_1',
          type: GroupEventType.sessionEnd,
          actorUid: ownerUid,
          actorName: 'Kamu Pemilik',
          summary: 'Menyelesaikan date',
          payload: {
            'sessionId': 'sess_live_1',
            'budget': 200000,
            'totalSpent': 120000,
            'noteCount': 3,
            'status': 'lolos',
          },
          createdAt: DateTime.now().add(const Duration(milliseconds: 50)),
        );
        eventsController.add([liveEvt]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byType(GroupDateResultScreen), findsOneWidget);
        expect(find.text('Lolos budget!'), findsOneWidget);
        expect(
          groupService.hasShownResultForSession(testGid, 'sess_live_1'),
          isTrue,
        );

        // Kembali ke home lalu kirim ulang sessionId yang sama -> tidak muncul dua kali
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(GroupDateResultScreen), findsNothing);

        final dupEvt = GroupEventModel(
          eventId: 'evt_end_live_dup',
          type: GroupEventType.sessionEnd,
          actorUid: ownerUid,
          actorName: 'Kamu Pemilik',
          summary: 'Menyelesaikan date',
          payload: {
            'sessionId': 'sess_live_1',
            'budget': 200000,
            'totalSpent': 120000,
            'noteCount': 3,
          },
          createdAt: DateTime.now().add(const Duration(milliseconds: 50)),
        );
        eventsController.add([dupEvt]);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GroupDateResultScreen), findsNothing);

        // 2. Background/paused -> skip auto-navigasi untuk session baru
        NotificationCoordinator.instance.didChangeAppLifecycleState(
          AppLifecycleState.paused,
        );
        final bgEvt = GroupEventModel(
          eventId: 'evt_end_bg_2',
          type: GroupEventType.sessionEnd,
          actorUid: ownerUid,
          actorName: 'Kamu Pemilik',
          summary: 'Menyelesaikan date',
          payload: {
            'sessionId': 'sess_bg_2',
            'budget': 150000,
            'totalSpent': 90000,
            'noteCount': 2,
          },
          createdAt: DateTime.now().add(const Duration(milliseconds: 50)),
        );
        eventsController.add([bgEvt]);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GroupDateResultScreen), findsNothing);
        expect(
          groupService.hasShownResultForSession(testGid, 'sess_bg_2'),
          isFalse,
        );

        // 3. Kembali ke foreground tetapi event sudah lama (reconnect stale > 30s) -> skip auto-navigasi
        NotificationCoordinator.instance.didChangeAppLifecycleState(
          AppLifecycleState.resumed,
        );
        final staleEvt = GroupEventModel(
          eventId: 'evt_end_stale_3',
          type: GroupEventType.sessionEnd,
          actorUid: ownerUid,
          actorName: 'Kamu Pemilik',
          summary: 'Menyelesaikan date',
          payload: {
            'sessionId': 'sess_stale_3',
            'budget': 150000,
            'totalSpent': 90000,
            'noteCount': 2,
          },
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        );
        eventsController.add([staleEvt]);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GroupDateResultScreen), findsNothing);
        expect(
          groupService.hasShownResultForSession(testGid, 'sess_stale_3'),
          isFalse,
        );

        // Akhiri & bersihkan timer internal NotificationCoordinator agar tidak pending
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 65));
        NotificationCoordinator.instance.resetAggregationBuffers();
      },
    );
  });

  group('Layar 64/65 — Filter Kosong & Linimasa Hasil Date Diperbarui', () {
    testWidgets(
      'Menampilkan pesan filter kosong per anggota & entri Hasil date diperbarui pada Tab Linimasa',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        try {
          final (prefs, authService, groupService) = await setupServices();
        final now = DateTime(2026, 10, 23, 20, 0);
        const sid = 'sess_detail_h6';

        final group = GroupModel(
          id: testGid,
          name: 'Date Jumat',
          ownerUid: ownerUid,
          code: 'DET065',
          createdAt: now,
          memberCount: 2,
        );
        final members = [
          GroupMemberModel(
            uid: ownerUid,
            name: 'Kamu',
            colorIndex: 1,
            role: 'owner',
            joinedAt: now,
            lastReadAt: now,
          ),
          GroupMemberModel(
            uid: bimaUid,
            name: 'Bima',
            colorIndex: 3,
            role: 'member',
            joinedAt: now,
            lastReadAt: now,
          ),
        ];
        final session = GroupSessionModel(
          sessionId: sid,
          gid: testGid,
          startedAt: now,
          startedByUid: ownerUid,
          startedByName: 'Kamu',
          endedAt: now.add(const Duration(hours: 1)),
          endedByUid: ownerUid,
          endedByName: 'Kamu',
          budget: 100000,
          game: 'wheel',
          status: 'lewat',
          totalSpent: 120000,
        );
        final notes = [
          GroupNoteModel(
            noteId: 'n1',
            sessionId: sid,
            authorUid: ownerUid,
            authorName: 'Kamu',
            title: 'Bakso',
            amount: 120000,
            createdAt: now.add(const Duration(minutes: 15)),
          ),
        ];
        final events = [
          GroupEventModel(
            eventId: 'evt_updated_1',
            type: GroupEventType.custom,
            actorUid: ownerUid,
            actorName: 'Kamu',
            summary: 'Hasil date diperbarui: Lewat (Rp120.000)',
            payload: {
              'action': 'session_result_updated',
              'sessionId': sid,
              'status': 'lewat',
              'totalSpent': 120000,
              'budget': 100000,
              'lateOfflineSync': true,
            },
            createdAt: now.add(const Duration(hours: 2)),
          ),
        ];

        await groupService.saveLocalGroup(group);
        await groupService.saveLocalNotes(testGid, notes);
        await groupService.upsertLocalSession(testGid, session);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupServiceProvider.overrideWithValue(groupService),
              activeGroupIdProvider.overrideWith((ref) => testGid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(group),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(members),
              ),
              activeGroupNotesStreamProvider.overrideWith(
                (ref) => Stream.value(notes),
              ),
              activeGroupSessionsStreamProvider.overrideWith(
                (ref) => Stream.value([session]),
              ),
              activeGroupEventsStreamProvider.overrideWith(
                (ref) => Stream.value(events),
              ),
              groupSessionNotesStreamProvider(sid).overrideWith(
                (ref) => Stream.value(notes),
              ),
              groupSessionEventsStreamProvider(sid).overrideWith(
                (ref) => Stream.value(events),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const GroupDateDetailScreen(
                groupId: testGid,
                sessionId: sid,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));

        // Tab Catatan -> ketuk chip anggota 'Bima' yang 0 catatan
        await tester.tap(find.text('Catatan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.bySemanticsLabel(RegExp('Filter anggota Bima')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.text('Bima belum mencatat pengeluaran di date ini'),
          findsOneWidget,
        );

        // Tab Linimasa -> menampilkan entri Hasil date diperbarui
        await tester.tap(find.text('Linimasa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final hasilUpdatedFinder = find.textContaining(
          'Hasil date diperbarui',
          findRichText: true,
        );
        await tester.scrollUntilVisible(
          hasilUpdatedFinder,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(hasilUpdatedFinder, findsWidgets);
        } finally {
          semanticsHandle.dispose();
        }
      },
    );
  });
}
