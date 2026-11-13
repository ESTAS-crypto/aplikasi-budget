import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_history_models.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/sync_badge.dart';
import 'package:putar_jajan/core/group/widgets/sync_strip.dart';
import 'package:putar_jajan/features/group/screens/group_date_detail_screen.dart';
import 'package:putar_jajan/features/group/screens/group_history_view.dart';
import 'package:putar_jajan/features/group/widgets/group_note_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String testGid = 'grp_h5_test';
  const String sessionId1 = 'sess_23_okt';
  const String sessionId2 = 'sess_16_okt';
  const String ownerUid = 'uid_kamu';
  const String dinaUid = 'uid_dina';
  const String rakaUid = 'uid_raka';
  const String bimaUid = 'uid_bima';

  late SharedPreferences prefs;
  late GroupAuthService authService;
  late GroupService groupService;
  late GroupGameService gameService;

  final baseGroup = GroupModel(
    id: testGid,
    name: 'Date Jumat',
    ownerUid: ownerUid,
    code: 'JUMAT5',
    createdAt: DateTime(2026, 10, 1, 18, 0),
    memberCount: 4,
  );

  final baseMembers = <GroupMemberModel>[
    GroupMemberModel(
      uid: dinaUid,
      name: 'Dina',
      colorIndex: 0,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 0),
    ),
    GroupMemberModel(
      uid: ownerUid,
      name: 'Kamu',
      colorIndex: 1,
      role: 'owner',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 0),
    ),
    GroupMemberModel(
      uid: rakaUid,
      name: 'Raka Pratama Wijaya',
      colorIndex: 2,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 0),
    ),
    GroupMemberModel(
      uid: bimaUid,
      name: 'Bima Sakti Nusantara',
      colorIndex: 3,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 0),
    ),
  ];

  final sessionOct23 = GroupSessionModel(
    sessionId: sessionId1,
    gid: testGid,
    startedAt: DateTime(2026, 10, 23, 19, 12),
    startedByUid: ownerUid,
    startedByName: 'Kamu',
    endedAt: DateTime(2026, 10, 23, 20, 48),
    endedByUid: ownerUid,
    endedByName: 'Kamu',
    budget: 80000,
    game: 'dice',
    budgetByUid: dinaUid,
    budgetByName: 'Dina',
    detail: {
      'rolls': [5, 3],
      'multiplier': 10000,
    },
    status: 'lolos',
    totalSpent: 54000,
  );

  final sessionOct16 = GroupSessionModel(
    sessionId: sessionId2,
    gid: testGid,
    startedAt: DateTime(2026, 10, 16, 19, 0),
    startedByUid: ownerUid,
    startedByName: 'Kamu',
    endedAt: DateTime(2026, 10, 16, 21, 0),
    endedByUid: ownerUid,
    endedByName: 'Kamu',
    budget: 50000,
    game: 'wheel',
    budgetByUid: ownerUid,
    budgetByName: 'Kamu',
    status: 'lewat',
    totalSpent: 62000,
  );

  final sessionNotes = <GroupNoteModel>[
    GroupNoteModel(
      noteId: 'note_1',
      sessionId: sessionId1,
      authorUid: dinaUid,
      authorName: 'Dina',
      title: 'Sate taichan',
      amount: 30000,
      createdAt: DateTime(2026, 10, 23, 19, 20),
    ),
    GroupNoteModel(
      noteId: 'note_2',
      sessionId: sessionId1,
      authorUid: ownerUid,
      authorName: 'Kamu',
      title: 'Es teh jumbo',
      amount: 12000,
      createdAt: DateTime(2026, 10, 23, 19, 38),
    ),
    GroupNoteModel(
      noteId: 'note_3',
      sessionId: sessionId1,
      authorUid: rakaUid,
      authorName: 'Raka',
      title: 'Kentang goreng',
      amount: 12000,
      createdAt: DateTime(2026, 10, 23, 19, 42),
    ),
    GroupNoteModel(
      noteId: 'note_oct16_1',
      sessionId: sessionId2,
      authorUid: dinaUid,
      authorName: 'Dina',
      title: 'Ramen pedas',
      amount: 62000,
      createdAt: DateTime(2026, 10, 16, 19, 30),
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.setString(GroupAuthService.keyFallbackUid, ownerUid);
    await prefs.setString(GroupAuthService.keyDisplayName, 'Kamu');

    authService = GroupAuthService(auth: null, prefs: prefs);
    groupService = GroupService(
      firestore: null,
      authService: authService,
      prefs: prefs,
    );
    gameService = GroupGameService(
      groupService: groupService,
      authService: authService,
    );

    await groupService.saveLocalGroup(baseGroup);
    await groupService.setActiveGroupId(testGid);
    await groupService.saveLocalNotes(testGid, sessionNotes);
    await groupService.upsertLocalSession(testGid, sessionOct16);
    await groupService.upsertLocalSession(testGid, sessionOct23);
  });

  group('Tahap H5: Polish Gerak, Aksesibilitas TalkBack, Offline, & Uji Dua HP', () {
    testWidgets(
      'Layar 62..66 pada lebar 320dp & 390dp dengan textScale 1.3 bebas overflow & mendukung disableAnimations',
      (tester) async {
        for (final width in [320.0, 390.0]) {
          for (final disableAnim in [false, true]) {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1.0;

            // 1. Layar 62 (Daftar Riwayat Grup)
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  groupServiceProvider.overrideWithValue(groupService),
                  groupAuthServiceProvider.overrideWithValue(authService),
                  groupGameServiceProvider.overrideWithValue(gameService),
                  activeGroupIdProvider.overrideWith((ref) => testGid),
                  activeGroupStreamProvider.overrideWith(
                    (ref) => Stream.value(baseGroup),
                  ),
                  activeGroupMembersStreamProvider.overrideWith(
                    (ref) => Stream.value(baseMembers),
                  ),
                  unreadActivityCountProvider.overrideWith((ref) => 2),
                ],
                child: MaterialApp(
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(width, 844),
                        textScaler: const TextScaler.linear(1.3),
                        disableAnimations: disableAnim,
                      ),
                      child: child!,
                    );
                  },
                  home: const Scaffold(body: GroupHistoryView()),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);

            // 2. Layar 63 -> 64 -> 66 -> 65
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  groupServiceProvider.overrideWithValue(groupService),
                  groupAuthServiceProvider.overrideWithValue(authService),
                  groupGameServiceProvider.overrideWithValue(gameService),
                  activeGroupIdProvider.overrideWith((ref) => testGid),
                  activeGroupStreamProvider.overrideWith(
                    (ref) => Stream.value(baseGroup),
                  ),
                  activeGroupMembersStreamProvider.overrideWith(
                    (ref) => Stream.value(baseMembers),
                  ),
                  unreadActivityCountProvider.overrideWith((ref) => 0),
                ],
                child: MaterialApp(
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(width, 844),
                        textScaler: const TextScaler.linear(1.3),
                        disableAnimations: disableAnim,
                      ),
                      child: child!,
                    );
                  },
                  home: const GroupDateDetailScreen(
                    groupId: testGid,
                    sessionId: sessionId1,
                    initialTab: GroupDateDetailTab.ringkasan,
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);

            // Pindah ke Tab Catatan (Layar 64) dan geser chip filter anggota yang panjang
            await tester.tap(find.text('Catatan'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);

            // Buka Sheet 66 dari kartu catatan
            await tester.tap(find.text('Sate taichan'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
            expect(find.byType(GroupNoteDetailSheet), findsOneWidget);

            // Tutup Sheet 66
            await tester.tap(find.bySemanticsLabel('Tutup'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);

            // Pindah ke Tab Linimasa (Layar 65)
            await tester.tap(find.text('Linimasa'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          }
        }
        addTearDown(tester.view.reset);
      },
    );

    testWidgets(
      'TalkBack Semantics: Kartu date (Layar 62), baris catatan (Layar 64), dan status dibacakan lengkap (tidak hanya warna)',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();

        // 1. Cek Semantics pada Layar 62 (kartu date Lolos & Lewat)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              groupServiceProvider.overrideWithValue(groupService),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupGameServiceProvider.overrideWithValue(gameService),
              activeGroupIdProvider.overrideWith((ref) => testGid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(baseGroup),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(baseMembers),
              ),
              unreadActivityCountProvider.overrideWith((ref) => 0),
            ],
            child: const MaterialApp(
              home: Scaffold(body: GroupHistoryView()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Kartu 23 Okt dibacakan lengkap: tanggal, siapa & permainan, budget, terpakai, status Lolos
        expect(
          find.bySemanticsLabel(
            RegExp(
              r'Jumat, 23 Okt\. Dina, Kocok Dadu\. Budget Rp80\.000, Terpakai Rp54\.000\. Status: Lolos\.',
            ),
          ),
          findsOneWidget,
        );

        // Kartu 16 Okt dibacakan lengkap dengan status Lewat Rp12rb (bukan hanya warna)
        expect(
          find.bySemanticsLabel(
            RegExp(
              r'Jumat, 16 Okt\. Kamu, Roda Putar\. Budget Rp50\.000, Terpakai Rp62\.000\. Status: Lewat Rp12rb\.',
            ),
          ),
          findsOneWidget,
        );

        // 2. Cek Semantics pada Layar 64 (baris catatan)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              groupServiceProvider.overrideWithValue(groupService),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupGameServiceProvider.overrideWithValue(gameService),
              activeGroupIdProvider.overrideWith((ref) => testGid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(baseGroup),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(baseMembers),
              ),
              unreadActivityCountProvider.overrideWith((ref) => 0),
            ],
            child: const MaterialApp(
              home: GroupDateDetailScreen(
                groupId: testGid,
                sessionId: sessionId1,
                initialTab: GroupDateDetailTab.catatan,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          find.bySemanticsLabel(
            RegExp(
              r'Sate taichan, Rp30\.000\. Dicatat oleh Dina pukul 19\.20, sisa budget setelahnya Rp50\.000\. Status terkirim\.',
            ),
          ),
          findsOneWidget,
        );
        semanticsHandle.dispose();
      },
    );

    testWidgets(
      'Offline & Pending Writes: menampilkan SyncStrip, SyncBadge, dan keterangan "Belum termasuk catatan terbaru anggota lain"',
      (tester) async {
        // Tambahkan 1 catatan dengan hasPendingWrites: true
        final pendingNotes = [
          ...sessionNotes,
          GroupNoteModel(
            noteId: 'note_pending',
            sessionId: sessionId1,
            authorUid: ownerUid,
            authorName: 'Kamu',
            title: 'Martabak manis',
            amount: 15000,
            createdAt: DateTime(2026, 10, 23, 20, 0),
            hasPendingWrites: true,
          ),
        ];
        await groupService.saveLocalNotes(testGid, pendingNotes);

        // 1. Layar 62 menampilkan SyncStrip & keterangan pada kartu ringkasan
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              groupServiceProvider.overrideWithValue(groupService),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupGameServiceProvider.overrideWithValue(gameService),
              activeGroupIdProvider.overrideWith((ref) => testGid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(baseGroup),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(baseMembers),
              ),
              unreadActivityCountProvider.overrideWith((ref) => 0),
            ],
            child: const MaterialApp(
              home: Scaffold(body: GroupHistoryView()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(SyncStrip), findsOneWidget);
        expect(
          find.text('Belum termasuk catatan terbaru anggota lain'),
          findsOneWidget,
        );

        // 2. Layar 63 & 64 menampilkan SyncStrip, keterangan, dan SyncBadge pada catatan tertunda
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              groupServiceProvider.overrideWithValue(groupService),
              groupAuthServiceProvider.overrideWithValue(authService),
              groupGameServiceProvider.overrideWithValue(gameService),
              activeGroupIdProvider.overrideWith((ref) => testGid),
              activeGroupStreamProvider.overrideWith(
                (ref) => Stream.value(baseGroup),
              ),
              activeGroupMembersStreamProvider.overrideWith(
                (ref) => Stream.value(baseMembers),
              ),
              unreadActivityCountProvider.overrideWith((ref) => 0),
            ],
            child: const MaterialApp(
              home: GroupDateDetailScreen(
                groupId: testGid,
                sessionId: sessionId1,
                initialTab: GroupDateDetailTab.ringkasan,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SyncStrip), findsOneWidget);
        expect(
          find.text('Belum termasuk catatan terbaru anggota lain'),
          findsOneWidget,
        );

        // Pindah ke Tab Catatan -> catatan "Martabak manis" memiliki SyncBadge Menunggu
        await tester.tap(find.text('Catatan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(SyncBadge), findsOneWidget);

        // Ketuk "Martabak manis" -> Sheet 66 menampilkan status "Menunggu" & "menunggu"
        await tester.tap(find.text('Martabak manis'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Menunggu'), findsWidgets);
        expect(find.text('menunggu'), findsOneWidget);
      },
    );

    test(
      'Uji Dua HP (HP A & HP B): A menambah dan menghapus catatan, B melihat detail, urutan, dan sisa budget yang sama persis',
      () async {
        // Simulasi HP A (milik Dina)
        SharedPreferences.setMockInitialValues({});
        final prefsA = await SharedPreferences.getInstance();
        await prefsA.setString(GroupAuthService.keyFallbackUid, dinaUid);
        await prefsA.setString(GroupAuthService.keyDisplayName, 'Dina');
        final authA = GroupAuthService(auth: null, prefs: prefsA);
        final serviceA = GroupService(
          firestore: null,
          authService: authA,
          prefs: prefsA,
        );

        await serviceA.saveLocalGroup(baseGroup);
        await serviceA.upsertLocalSession(
          testGid,
          sessionOct23.copyWith(totalSpent: 0),
        );
        await serviceA.saveLocalNotes(testGid, []);

        // HP A mencatat 3 pengeluaran pada sesi
        final t1 = DateTime(2026, 10, 23, 19, 20);
        final t2 = DateTime(2026, 10, 23, 19, 35);
        final t3 = DateTime(2026, 10, 23, 19, 50);

        final n1 = GroupNoteModel(
          noteId: 'note_a1',
          sessionId: sessionId1,
          authorUid: dinaUid,
          authorName: 'Dina',
          title: 'Sate taichan',
          amount: 30000,
          createdAt: t1,
        );
        final n2 = GroupNoteModel(
          noteId: 'note_a2',
          sessionId: sessionId1,
          authorUid: dinaUid,
          authorName: 'Dina',
          title: 'Kerupuk kulit',
          amount: 10000,
          createdAt: t2,
        );
        final n3 = GroupNoteModel(
          noteId: 'note_a3',
          sessionId: sessionId1,
          authorUid: rakaUid,
          authorName: 'Raka',
          title: 'Es jeruk',
          amount: 15000,
          createdAt: t3,
        );

        await serviceA.saveLocalNotes(testGid, [n1, n2, n3]);
        await serviceA.upsertLocalSession(testGid, sessionOct23);

        // HP A menghapus catatan ke-2 ("Kerupuk kulit" Rp10.000) -> tombstone deleted: true
        await serviceA.deleteNote(
          gid: testGid,
          noteId: 'note_a2',
          title: 'Kerupuk kulit',
          amount: 10000,
          sessionBudget: 80000,
        );

        final notesOnA = serviceA.getLocalNotes(testGid);
        final sessionOnA = serviceA
            .getLocalSessions(testGid)
            .firstWhere((s) => s.sessionId == sessionId1);

        // Simulasi HP B (milik Raka) yang menerima sinkronisasi catatan dalam urutan terbalik / acak + duplikat
        final notesReceivedByB = <GroupNoteModel>[
          notesOnA[2], // n3
          notesOnA[0], // n1
          notesOnA[1], // n2 (deleted: true)
          notesOnA[0], // duplikat n1 dari cache/reconnect
        ];

        final sessionOnB = GroupHistoryCalculator.recalculateSession(
          session: sessionOct23,
          sessionNotes: notesReceivedByB,
        );

        final remainingOnA = GroupHistoryCalculator.computeNotesWithRemaining(
          budget: sessionOnA.budget,
          notes: notesOnA,
        );
        final remainingOnB = GroupHistoryCalculator.computeNotesWithRemaining(
          budget: sessionOnB.budget,
          notes: notesReceivedByB,
        );

        // HP A dan HP B menghasilkan totalSpent, status, daftar catatan aktif, dan sisa setelahnya yang IDENTIK
        expect(sessionOnA.totalSpent, 45000);
        expect(sessionOnB.totalSpent, 45000);
        expect(sessionOnA.status, 'lolos');
        expect(sessionOnB.status, 'lolos');
        expect(sessionOnA.hemat, 35000);
        expect(sessionOnB.hemat, 35000);

        expect(remainingOnA.length, 2);
        expect(remainingOnB.length, 2);

        for (int i = 0; i < remainingOnA.length; i++) {
          expect(remainingOnB[i].note.noteId, remainingOnA[i].note.noteId);
          expect(remainingOnB[i].remainingAfter, remainingOnA[i].remainingAfter);
          expect(remainingOnB[i].sequenceNumber, remainingOnA[i].sequenceNumber);
        }

        // Catatan 1 ("Sate taichan" Rp30.000) -> sisa Rp50.000
        expect(remainingOnB[0].remainingAfter, 50000);
        // Catatan 2 ("Es jeruk" Rp15.000, karena "Kerupuk kulit" sudah dihapus) -> sisa Rp35.000
        expect(remainingOnB[1].remainingAfter, 35000);
      },
    );

    test(
      'Verifikasi kode layar 62..66 tidak memakai ikon bawaan (Icons.*) dan tidak memakai emoji',
      () {
        final filesToCheck = [
          'lib/features/group/screens/group_history_view.dart',
          'lib/features/group/screens/group_date_detail_screen.dart',
          'lib/features/group/widgets/group_note_detail_sheet.dart',
        ];

        final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
          unicode: true,
        );

        for (final path in filesToCheck) {
          final content = File(path).readAsStringSync();
          expect(
            content.contains(RegExp(r'\bIcons\.')),
            isFalse,
            reason: '$path tidak boleh menggunakan Icons.* bawaan Flutter',
          );
          expect(
            emojiRegex.hasMatch(content),
            isFalse,
            reason: '$path tidak boleh mengandung karakter emoji',
          );
        }
      },
    );
  });
}
