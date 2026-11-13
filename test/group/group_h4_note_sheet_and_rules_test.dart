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
import 'package:putar_jajan/features/group/screens/group_date_detail_screen.dart';
import 'package:putar_jajan/features/group/widgets/group_note_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String testGid = 'grp_h4_test';
  const String sessionId = 'sess_23_okt';
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
    code: 'JUMAT1',
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
      name: 'Raka',
      colorIndex: 2,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 0),
    ),
    GroupMemberModel(
      uid: bimaUid,
      name: 'Bima',
      colorIndex: 3,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 0),
    ),
  ];

  // 2026-10-23 adalah hari Jumat
  final sessionOct23 = GroupSessionModel(
    sessionId: sessionId,
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

  final sessionNotes = <GroupNoteModel>[
    GroupNoteModel(
      noteId: 'note_1',
      sessionId: sessionId,
      authorUid: dinaUid,
      authorName: 'Dina',
      title: 'Sate taichan',
      amount: 30000,
      createdAt: DateTime(2026, 10, 23, 19, 20),
    ),
    GroupNoteModel(
      noteId: 'note_2',
      sessionId: sessionId,
      authorUid: ownerUid,
      authorName: 'Kamu',
      title: 'Es teh jumbo',
      amount: 12000,
      createdAt: DateTime(2026, 10, 23, 19, 38),
    ),
    GroupNoteModel(
      noteId: 'note_3',
      sessionId: sessionId,
      authorUid: rakaUid,
      authorName: 'Raka',
      title: 'Kentang goreng',
      amount: 12000,
      createdAt: DateTime(2026, 10, 23, 19, 42),
    ),
  ];

  Future<void> initWithUser(String uid, String displayName) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.setString(GroupAuthService.keyFallbackUid, uid);
    await prefs.setString(GroupAuthService.keyDisplayName, displayName);

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
    await groupService.upsertLocalSession(testGid, sessionOct23);
  }

  setUp(() async {
    await initWithUser(ownerUid, 'Kamu');
  });

  Widget buildTestApp({
    GroupDateDetailTab initialTab = GroupDateDetailTab.catatan,
    double width = 390,
    double textScale = 1.0,
  }) {
    return ProviderScope(
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
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: GroupDateDetailScreen(
          groupId: testGid,
          sessionId: sessionId,
          initialTab: initialTab,
        ),
      ),
    );
  }

  group('Tahap H4: Layar 66 (Sheet Detail Satu Catatan), Ubah/Hapus & Security Rules', () {
    testWidgets(
      'Ketuk catatan di Layar 64 membuka Sheet 66 (Rgrup5.dc.html) dengan detail lengkap & tombol Tutup',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildTestApp(initialTab: GroupDateDetailTab.catatan),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Ketuk kartu catatan pertama ("Sate taichan")
        await tester.tap(find.text('Sate taichan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Sheet 66 terbuka
        expect(find.byType(GroupNoteDetailSheet), findsOneWidget);
        expect(find.text('Catatan 1 dari 3 · Date 23 Okt'), findsOneWidget);
        expect(find.text('Dicatat oleh'), findsOneWidget);
        expect(find.text('Waktu'), findsOneWidget);
        expect(find.text('Jumat, 23 Okt · 19.20'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Terkirim'), findsOneWidget);
        expect(find.text('semua anggota menerima'), findsOneWidget);
        expect(find.text('Sisa budget setelahnya'), findsOneWidget);
        expect(find.text('Rp50.000'), findsOneWidget);
        expect(
          find.text(
            'Hanya Dina dan pemilik grup yang bisa mengubah atau menghapus.',
          ),
          findsOneWidget,
        );

        // Karena user saat ini adalah pemilik grup (ownerUid), tombol Ubah & Hapus tampil
        expect(find.text('Ubah'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);

        // Ketuk tombol Tutup menutup Sheet 66
        await tester.tap(find.bySemanticsLabel('Tutup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(GroupNoteDetailSheet), findsNothing);
      },
    );

    testWidgets(
      'Aturan izin UI: Pembuat catatan (Dina) melihat Ubah & Hapus; anggota lain (Raka) TIDAK melihat tombol dan melihat keterangan izin',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // 1. Login sebagai Dina (pembuat catatan "Sate taichan", bukan owner)
        await initWithUser(dinaUid, 'Dina');
        await tester.pumpWidget(
          buildTestApp(initialTab: GroupDateDetailTab.catatan),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.text('Sate taichan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Ubah'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);
        expect(
          find.text(
            'Hanya Dina dan pemilik grup yang bisa mengubah atau menghapus.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel('Tutup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 2. Login sebagai Raka (anggota lain, bukan pembuat "Sate taichan" dan bukan owner)
        await initWithUser(rakaUid, 'Raka');
        await tester.pumpWidget(
          buildTestApp(initialTab: GroupDateDetailTab.catatan),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.text('Sate taichan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Raka TIDAK melihat tombol Ubah & Hapus, tetapi melihat keterangan
        expect(find.text('Ubah'), findsNothing);
        expect(find.text('Hapus'), findsNothing);
        expect(
          find.text(
            'Hanya Dina dan pemilik grup yang bisa mengubah atau menghapus.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Ubah catatan membuka formulir, menyimpan perubahan, menghitung ulang sisa setelahnya & status sesi',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildTestApp(initialTab: GroupDateDetailTab.catatan),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Buka Sheet 66 pada "Sate taichan" (Rp30.000)
        await tester.tap(find.text('Sate taichan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Ketuk tombol Ubah
        await tester.tap(find.text('Ubah'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Ubah Catatan Grup'), findsOneWidget);

        // Ubah nama menjadi "Sate taichan spesial" dan nominal menjadi 60000
        await tester.enterText(
          find.byKey(const ValueKey('edit_group_note_title_field')),
          'Sate taichan spesial',
        );
        await tester.enterText(
          find.byKey(const ValueKey('edit_group_note_amount_field')),
          '60000',
        );
        await tester.pump();

        await tester.tap(find.text('Simpan Pengeluaran'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Sheet 66 kini menampilkan nilai baru: Rp60.000, sisa budget setelahnya Rp20.000
        expect(find.text('Sate taichan spesial'), findsWidgets);
        expect(find.text('Rp60.000'), findsWidgets);
        expect(find.text('Rp20.000'), findsOneWidget);

        // Total terpakai sesi menjadi 60.000 + 12.000 + 12.000 = 84.000 (> budget 80.000 -> status 'lewat')
        final updatedSessions = groupService.getLocalSessions(testGid);
        final updatedSess = updatedSessions.firstWhere(
          (s) => s.sessionId == sessionId,
        );
        expect(updatedSess.totalSpent, 84000);
        expect(updatedSess.status, 'lewat');
      },
    );

    testWidgets(
      'Hapus catatan = tombstone (deleted: true) dengan konfirmasi, menulis event expense_deleted, dan menghitung ulang sisa budget',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildTestApp(initialTab: GroupDateDetailTab.catatan),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Buka Sheet 66 pada "Sate taichan" (Rp30.000)
        await tester.tap(find.text('Sate taichan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Ketuk tombol Hapus -> muncul dialog konfirmasi
        await tester.tap(find.text('Hapus'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Hapus Catatan?'), findsOneWidget);

        // Konfirmasi Hapus pada dialog
        await tester.tap(find.text('Hapus').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Sheet 66 tertutup otomatis
        expect(find.byType(GroupNoteDetailSheet), findsNothing);

        // Di Layar 64 (Tab Catatan), "Sate taichan" sudah tidak tampil (tombstone),
        // total menjadi Rp24.000 · 2 catatan, dan sisa setelah "Es teh jumbo" menjadi Rp68.000
        expect(find.text('Sate taichan'), findsNothing);
        expect(find.text('Total Rp24.000'), findsOneWidget);
        expect(find.text('2 catatan'), findsOneWidget);
        expect(
          find.textContaining('Kamu · 19.38 · sisa setelahnya Rp68.000'),
          findsOneWidget,
        );

        // Pindah ke Tab Linimasa (Layar 65): catatan yang dihapus tampil sebagai "menghapus catatan"
        await tester.tap(find.text('Linimasa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.textContaining('menghapus catatan Rp30.000'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Sheet 66 dirender tanpa overflow pada lebar 320dp & 390dp dengan textScale 1.3',
      (tester) async {
        for (final width in [320.0, 390.0]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildTestApp(
              initialTab: GroupDateDetailTab.catatan,
              width: width,
              textScale: 1.3,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          await tester.tap(find.text('Sate taichan'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(tester.takeException(), isNull);
          expect(find.byType(GroupNoteDetailSheet), findsOneWidget);

          await tester.tap(find.bySemanticsLabel('Tutup'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        }
        addTearDown(tester.view.reset);
      },
    );

    test(
      'Security Rules (emulator & firestore.rules): hanya pembuat atau pemilik yang boleh ubah dan hapus; anggota lain ditolak; sesi selesai dikunci kecuali pemilik',
      () async {
        final memberSet = {ownerUid, dinaUid, rakaUid, bimaUid};
        final dinaNote = sessionNotes.first; // authorUid == dinaUid

        // 1. Evaluasi Security Rules Emulator untuk notes/{noteId}
        final updatedDinaNote = dinaNote.copyWith(
          title: 'Sate taichan pedas',
          amount: 35000,
        );

        // Pembuat catatan (Dina) -> DIIZINKAN ubah & hapus
        expect(
          GroupSecurityRulesEmulator.canUpdateNote(
            authUid: dinaUid,
            ownerUid: ownerUid,
            memberUids: memberSet,
            existingNote: dinaNote,
            updatedNote: updatedDinaNote,
          ),
          isTrue,
        );
        expect(
          GroupSecurityRulesEmulator.canDeleteNote(
            authUid: dinaUid,
            ownerUid: ownerUid,
            memberUids: memberSet,
            existingNote: dinaNote,
          ),
          isTrue,
        );

        // Pemilik grup (Kamu) -> DIIZINKAN ubah & hapus catatan Dina
        expect(
          GroupSecurityRulesEmulator.canUpdateNote(
            authUid: ownerUid,
            ownerUid: ownerUid,
            memberUids: memberSet,
            existingNote: dinaNote,
            updatedNote: updatedDinaNote,
          ),
          isTrue,
        );
        expect(
          GroupSecurityRulesEmulator.canDeleteNote(
            authUid: ownerUid,
            ownerUid: ownerUid,
            memberUids: memberSet,
            existingNote: dinaNote,
          ),
          isTrue,
        );

        // Anggota lain (Raka & Bima) -> DITOLAK ubah & hapus catatan Dina
        for (final otherUid in [rakaUid, bimaUid, 'stranger_uid']) {
          expect(
            GroupSecurityRulesEmulator.canUpdateNote(
              authUid: otherUid,
              ownerUid: ownerUid,
              memberUids: memberSet,
              existingNote: dinaNote,
              updatedNote: updatedDinaNote,
            ),
            isFalse,
          );
          expect(
            GroupSecurityRulesEmulator.canDeleteNote(
              authUid: otherUid,
              ownerUid: ownerUid,
              memberUids: memberSet,
              existingNote: dinaNote,
            ),
            isFalse,
          );
        }

        // 2. Evaluasi Security Rules untuk sessions/{sessionId} yang sudah berakhir
        expect(
          GroupSecurityRulesEmulator.canUpdateSession(
            authUid: rakaUid,
            ownerUid: ownerUid,
            memberUids: memberSet,
            existingSession: sessionOct23,
          ),
          isFalse,
        );
        expect(
          GroupSecurityRulesEmulator.canUpdateSession(
            authUid: ownerUid,
            ownerUid: ownerUid,
            memberUids: memberSet,
            existingSession: sessionOct23,
          ),
          isTrue,
        );
        expect(GroupSecurityRulesEmulator.canDeleteSession(), isFalse);

        // 3. Evaluasi di GroupService: Raka ditolak mengubah/menghapus catatan Dina & sesi selesai
        await initWithUser(rakaUid, 'Raka');
        expect(
          () => groupService.updateNote(
            gid: testGid,
            noteId: 'note_1',
            newTitle: 'Bajakan',
            newAmount: 10000,
          ),
          throwsStateError,
        );
        expect(
          () => groupService.deleteNote(
            gid: testGid,
            noteId: 'note_1',
            title: 'Sate taichan',
            amount: 30000,
          ),
          throwsStateError,
        );
        expect(
          () => groupService.updateEndedSession(
            gid: testGid,
            session: sessionOct23,
            newBudget: 100000,
          ),
          throwsStateError,
        );

        // 4. Pemilik grup diizinkan memperbarui sesi selesai, yang otomatis menghitung ulang totalSpent & status lalu menulis event
        await initWithUser(ownerUid, 'Kamu');
        final updatedSess = await groupService.updateEndedSession(
          gid: testGid,
          session: sessionOct23,
          newBudget: 50000,
        );
        expect(updatedSess.budget, 50000);
        expect(updatedSess.totalSpent, 54000);
        expect(updatedSess.status, 'lewat'); // 54.000 > 50.000

        // 5. Verifikasi file firestore.rules memuat aturan sessions & notes (authorUid || isOwner)
        final rulesFile = File('firestore.rules');
        expect(rulesFile.existsSync(), isTrue);
        final rulesContent = rulesFile.readAsStringSync();
        expect(rulesContent, contains('match /sessions/{sessionId}'));
        expect(
          rulesContent,
          contains('(resource.data.endedAt == null || isOwner(gid))'),
        );
        expect(
          rulesContent,
          contains('(resource.data.authorUid == request.auth.uid || isOwner(gid))'),
        );
      },
    );
  });
}
