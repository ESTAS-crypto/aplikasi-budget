import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/group_important_dialog.dart';
import 'package:putar_jajan/core/theme/app_colors.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/utils/rupiah_formatter.dart';
import 'package:putar_jajan/core/utils/sound_service.dart';
import 'package:putar_jajan/features/group/screens/group_date_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late GroupAuthService authService;
  late GroupService groupService;

  const testGid = 'grp_fix_test';
  const ownerUid = 'uid_owner';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(prefs);
    authService = GroupAuthService(prefs: prefs);
    await authService.setDisplayName('Evan');
    groupService = GroupService(
      firestore: null,
      supabase: null,
      authService: authService,
      prefs: prefs,
    );

    final group = GroupModel(
      id: testGid,
      name: 'Jajan Bareng',
      ownerUid: ownerUid,
      code: 'ABC123',
      createdAt: DateTime(2026, 11, 13, 19, 0),
      activeSession: GroupSessionModel(
        sessionId: 'sess_1',
        gid: testGid,
        budget: 50000,
        game: 'wheel',
        startedByUid: ownerUid,
        startedByName: 'Evan',
        startedAt: DateTime(2026, 11, 13, 19, 5),
      ),
    );
    await groupService.saveLocalGroup(group);
  });

  test('1. RupiahFormatter.format dan addNote mempertahankan nilai minus asli di notifikasi', () async {
    expect(RupiahFormatter.format(-25000), '-Rp25.000');
    expect(RupiahFormatter.format(0), 'Rp0');

    await groupService.addNote(
      gid: testGid,
      sessionId: 'sess_1',
      title: 'Steak',
      amount: 75000,
      sessionBudget: 50000,
    );

    final events = groupService.getLocalEvents(testGid);
    expect(events, isNotEmpty);
    final expenseEvt = events.first;
    expect(expenseEvt.payload['remaining'], -25000);
    expect(RupiahFormatter.format(expenseEvt.payload['remaining'] as int), '-Rp25.000');
  });

  test('2. endSession mengembalikan frozenSession dan langsung mengosongkan activeSession menjadi 0', () async {
    await groupService.addNote(
      gid: testGid,
      sessionId: 'sess_1',
      title: 'Kopi',
      amount: 20000,
      sessionBudget: 50000,
    );

    final frozen = await groupService.endSession(gid: testGid);
    expect(frozen, isNotNull);
    expect(frozen!.budget, 50000);
    expect(frozen.totalSpent, 20000);
    expect(frozen.status, 'lolos');

    final updatedGroup = groupService.getLocalGroup(testGid);
    expect(updatedGroup?.activeSession, isNull);
  });

  testWidgets('3. GroupDateResultScreen menampilkan Lolos budget (Hgrup1) & Budget lewat (Hgrup2)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GroupDateResultScreen(
            groupName: 'Jajan Bareng',
            budget: 50000,
            totalSpent: 20000,
            itemCount: 1,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final scaffoldLolos = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffoldLolos.backgroundColor, AppColors.mint);
    expect(find.text('Lolos budget!'), findsOneWidget);
    expect(find.text('Grup hemat'), findsOneWidget);
    expect(find.text('Rp30.000'), findsOneWidget);
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('PENGELUARAN PER ORANG'), findsOneWidget);
    expect(find.text('Lihat detail date'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GroupDateResultScreen(
            groupName: 'Jajan Bareng',
            budget: 50000,
            totalSpent: 75000,
            itemCount: 2,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final scaffoldLewat = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffoldLewat.backgroundColor, const Color(0xFFFFC9BE));
    expect(find.text('Budget lewat Rp25.000'), findsOneWidget);
    expect(
      find.text('Gak apa-apa, catat dan putar lagi minggu depan'),
      findsOneWidget,
    );
    expect(find.text('Rp75.000'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('4. Dialog persetujuan budget putaran roda mengembalikan true saat Setuju dan false saat Tidak', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await GroupImportantDialog.showConfirmAcceptWheelBudget(
                  ctx,
                  budget: 80000,
                );
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.text('Setuju Budget Rp80.000?'), findsOneWidget);
    expect(find.text('Tidak'), findsOneWidget);
    expect(find.text('Setuju'), findsOneWidget);

    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setuju'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('5. Dialog showConfirmAcceptGameBudget menampilkan perbandingan budget lama vs baru saat catatan masih ada', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await GroupImportantDialog.showConfirmAcceptGameBudget(
                  ctx,
                  budget: 120000,
                  currentBudget: 50000,
                  gameName: 'Lempar Dadu',
                );
              },
              child: const Text('Buka Game'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Game'));
    await tester.pumpAndSettle();

    expect(find.text('Ganti Budget ke Rp120.000?'), findsOneWidget);
    expect(find.textContaining('Rp50.000'), findsOneWidget);
    expect(find.textContaining('Lempar Dadu'), findsOneWidget);

    await tester.tap(find.text('Setuju'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  test('6. hasActiveBudgetSession & getEffectiveActiveSession akurat setelah endSession dan sesi baru', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = GroupAuthService(prefs: prefs);
    final service = GroupService(prefs: prefs, authService: auth);

    const gid = 'g_session_check';
    final oldSession = GroupSessionModel(
      sessionId: 'sess_old',
      gid: gid,
      budget: 50000,
      startedByUid: 'u1',
      startedByName: 'Evan',
      startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    final group = GroupModel(
      id: gid,
      name: 'Jajan',
      code: 'JJN123',
      ownerUid: 'u1',
      createdAt: DateTime.now(),
      activeSession: oldSession,
    );
    await service.saveLocalGroup(group);
    expect(service.hasActiveBudgetSession(gid), isTrue);

    await service.endSession(gid: gid);
    expect(service.hasActiveBudgetSession(gid), isFalse);
    expect(service.getEffectiveActiveSession(gid), isNull);

    // Simulasikan sesi baru setelah endSession (clearEndedSessionMarker + saveSessionAndEvent)
    final newSession = GroupSessionModel(
      sessionId: 'sess_new',
      gid: gid,
      budget: 100000,
      game: 'wheel',
      startedByUid: 'u1',
      startedByName: 'Evan',
      startedAt: DateTime.now(),
    );
    final evt = GroupEventModel(
      eventId: 'evt_new',
      type: GroupEventType.gameResult,
      actorUid: 'u1',
      actorName: 'Evan',
      summary: null,
      payload: {
        'game': 'wheel',
        'amount': 100000,
        'valid': true,
        'sessionId': 'sess_new',
      },
      createdAt: DateTime.now(),
    );
    await service.saveSessionAndEvent(gid: gid, session: newSession, event: evt);

    expect(service.hasActiveBudgetSession(gid), isTrue);
    expect(service.getEffectiveActiveSession(gid)?.budget, 100000);
    expect(service.getEffectiveActiveSession(gid)?.sessionId, 'sess_new');
  });

  test('7. watchGroup & watchNotes memancarkan pembaruan realtime seketika walau supabase == null', () async {
    SharedPreferences.setMockInitialValues({});
    final testPrefs = await SharedPreferences.getInstance();
    await testPrefs.setString(GroupAuthService.keyFallbackUid, ownerUid);
    await testPrefs.setString(GroupAuthService.keyDisplayName, 'Evan');
    final testAuth = GroupAuthService(prefs: testPrefs);
    final testSvc = GroupService(prefs: testPrefs, authService: testAuth);

    const gid = 'g_stream_live';
    final initialGroup = GroupModel(
      id: gid,
      name: 'Jajan Stream',
      code: 'STR001',
      ownerUid: ownerUid,
      createdAt: DateTime(2026, 11, 13, 9, 0),
    );
    await testSvc.saveLocalGroup(initialGroup);

    final emittedGroups = <GroupModel?>[];
    final subGroup = testSvc.watchGroup(gid).listen(emittedGroups.add);

    final emittedNotes = <List<GroupNoteModel>>[];
    final subNotes = testSvc.watchNotes(gid, 'sess_rt_1').listen(emittedNotes.add);

    await Future<void>.delayed(Duration.zero);
    expect(emittedGroups.last?.activeSession, isNull);
    expect(emittedNotes.last, isEmpty);

    // 1. Mainkan roda / game -> watchGroup langsung memancarkan activeSession tanpa relog
    final newSession = GroupSessionModel(
      sessionId: 'sess_rt_1',
      gid: gid,
      budget: 250000,
      game: 'wheel',
      startedByUid: ownerUid,
      startedByName: 'Evan',
      startedAt: DateTime.now(),
    );
    final evt = GroupEventModel(
      eventId: 'evt_rt_1',
      type: GroupEventType.gameResult,
      actorUid: ownerUid,
      actorName: 'Evan',
      summary: null,
      payload: {'game': 'wheel', 'amount': 250000, 'valid': true, 'sessionId': 'sess_rt_1'},
      createdAt: DateTime.now(),
    );
    await testSvc.saveSessionAndEvent(gid: gid, session: newSession, event: evt);
    await Future<void>.delayed(Duration.zero);
    expect(emittedGroups.last?.activeSession?.budget, equals(250000));

    // 2. Tambah catatan -> watchNotes langsung memancarkan catatan baru
    await testSvc.addNote(gid: gid, title: 'Boba', amount: 30000, sessionId: 'sess_rt_1');
    await Future<void>.delayed(Duration.zero);
    expect(emittedNotes.last.length, equals(1));
    expect(emittedNotes.last.first.title, equals('Boba'));

    // 3. Akhiri date -> watchGroup langsung memancarkan activeSession == null
    await testSvc.endSession(gid: gid);
    await Future<void>.delayed(Duration.zero);
    expect(emittedGroups.last?.activeSession, isNull);

    await subGroup.cancel();
    await subNotes.cancel();
  });

  test('8. claimSessionAndWriteResult memajukan startedAt agar budget baru menang atas sesi lama', () async {
    SharedPreferences.setMockInitialValues({});
    final testPrefs = await SharedPreferences.getInstance();
    await testPrefs.setString(GroupAuthService.keyFallbackUid, ownerUid);
    await testPrefs.setString(GroupAuthService.keyDisplayName, 'Evan');
    final testAuth = GroupAuthService(prefs: testPrefs);
    final testSvc = GroupService(prefs: testPrefs, authService: testAuth);
    final gameSvc = GroupGameService(groupService: testSvc, authService: testAuth);

    const gid = 'g_replace_ts';
    final oldStartedAt = DateTime.now().subtract(const Duration(minutes: 5));
    final oldSession = GroupSessionModel(
      sessionId: 'sess_old_ts',
      gid: gid,
      budget: 150000,
      game: 'wheel',
      startedByUid: ownerUid,
      startedByName: 'Evan',
      startedAt: oldStartedAt,
    );
    await testSvc.saveLocalGroup(
      GroupModel(
        id: gid,
        name: 'Jajan TS',
        code: 'TS0001',
        ownerUid: ownerUid,
        createdAt: oldStartedAt,
        activeSession: oldSession,
      ),
    );

    final res = await gameSvc.claimSessionAndWriteResult(
      gid: gid,
      game: 'wheel',
      amount: 225000,
    );
    expect(res.success, isTrue);
    expect(res.activeSession!.startedAt.isAfter(oldStartedAt), isTrue);

    final resolved = testSvc.resolveEffectiveSession(gid, oldSession, res.activeSession);
    expect(resolved?.budget, equals(225000));
  });

  test('9. SoundService prepareSplashJingle & playPreparedSplashJingle aman di lingkungan headless', () async {
    SharedPreferences.setMockInitialValues({});
    final testPrefs = await SharedPreferences.getInstance();
    await SoundService.instance.prepareSplashJingle(prefs: testPrefs);
    await SoundService.instance.playPreparedSplashJingle(volume: 1.0);
    expect(SoundService.instance.isSoundEnabled, isTrue);
  });
}

