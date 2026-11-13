import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/features/group/screens/group_date_detail_screen.dart';

void main() {
  late SharedPreferences prefs;

  final sampleGroup = GroupModel(
    id: 'grp_jumat',
    name: 'Date Jumat',
    code: 'JMT123',
    ownerUid: 'u_kamu',
    createdAt: DateTime(2026, 10, 1, 18, 0),
  );

  final sampleMembers = <GroupMemberModel>[
    GroupMemberModel(
      uid: 'u_dina',
      name: 'Dina',
      colorIndex: 0,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 15),
    ),
    GroupMemberModel(
      uid: 'u_kamu',
      name: 'Kamu',
      colorIndex: 1,
      role: 'owner',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 15),
    ),
    GroupMemberModel(
      uid: 'u_raka',
      name: 'Raka',
      colorIndex: 2,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 15),
    ),
    GroupMemberModel(
      uid: 'u_bima',
      name: 'Bima',
      colorIndex: 3,
      role: 'member',
      joinedAt: DateTime(2026, 10, 1, 18, 0),
      lastReadAt: DateTime(2026, 10, 23, 21, 15),
    ),
  ];

  final sampleSession = GroupSessionModel(
    sessionId: 'sess_23okt',
    gid: 'grp_jumat',
    budget: 80000,
    game: 'dice',
    startedByUid: 'u_kamu',
    startedByName: 'Kamu',
    startedAt: DateTime(2026, 10, 23, 18, 55),
    endedAt: DateTime(2026, 10, 23, 21, 10),
    endedByUid: 'u_kamu',
    endedByName: 'Kamu',
    budgetByUid: 'u_dina',
    budgetByName: 'Dina',
    detail: {
      'rolls': [5, 3],
      'multiplier': 10000,
    },
    status: 'lolos',
    totalSpent: 54000,
  );

  final sampleNotes = <GroupNoteModel>[
    GroupNoteModel(
      noteId: 'n_1',
      sessionId: 'sess_23okt',
      title: 'Sate taichan',
      amount: 30000,
      authorUid: 'u_dina',
      authorName: 'Dina',
      createdAt: DateTime(2026, 10, 23, 19, 20),
    ),
    GroupNoteModel(
      noteId: 'n_2',
      sessionId: 'sess_23okt',
      title: 'Es teh jumbo',
      amount: 12000,
      authorUid: 'u_kamu',
      authorName: 'Kamu',
      createdAt: DateTime(2026, 10, 23, 19, 38),
    ),
    GroupNoteModel(
      noteId: 'n_3',
      sessionId: 'sess_23okt',
      title: 'Kentang goreng',
      amount: 12000,
      authorUid: 'u_raka',
      authorName: 'Raka',
      createdAt: DateTime(2026, 10, 23, 19, 42),
    ),
    // Catatan yang sudah dihapus (tombstone) tidak boleh muncul di Tab Catatan
    GroupNoteModel(
      noteId: 'n_deleted',
      sessionId: 'sess_23okt',
      title: 'Kerupuk kaleng',
      amount: 5000,
      authorUid: 'u_bima',
      authorName: 'Bima',
      createdAt: DateTime(2026, 10, 23, 19, 50),
      deleted: true,
    ),
  ];

  final sampleEvents = <GroupEventModel>[
    GroupEventModel(
      eventId: 'evt_start',
      type: GroupEventType.sessionStart,
      actorUid: 'u_kamu',
      actorName: 'Kamu',
      payload: {'sessionId': 'sess_23okt', 'budget': 80000},
      createdAt: DateTime(2026, 10, 23, 18, 55),
    ),
    GroupEventModel(
      eventId: 'evt_game',
      type: GroupEventType.gameResult,
      actorUid: 'u_dina',
      actorName: 'Dina',
      payload: {
        'sessionId': 'sess_23okt',
        'game': 'dice',
        'amount': 80000,
        'valid': true,
        'detail': {
          'rolls': [5, 3],
          'multiplier': 10000,
        },
      },
      createdAt: DateTime(2026, 10, 23, 19, 2),
    ),
    GroupEventModel(
      eventId: 'evt_n1',
      type: GroupEventType.expense,
      actorUid: 'u_dina',
      actorName: 'Dina',
      payload: {
        'sessionId': 'sess_23okt',
        'noteId': 'n_1',
        'title': 'Sate taichan',
        'amount': 30000,
      },
      createdAt: DateTime(2026, 10, 23, 19, 20),
    ),
    GroupEventModel(
      eventId: 'evt_n2',
      type: GroupEventType.expense,
      actorUid: 'u_kamu',
      actorName: 'Kamu',
      payload: {
        'sessionId': 'sess_23okt',
        'noteId': 'n_2',
        'title': 'Es teh jumbo',
        'amount': 12000,
      },
      createdAt: DateTime(2026, 10, 23, 19, 38),
    ),
    GroupEventModel(
      eventId: 'evt_n3',
      type: GroupEventType.expense,
      actorUid: 'u_raka',
      actorName: 'Raka',
      payload: {
        'sessionId': 'sess_23okt',
        'noteId': 'n_3',
        'title': 'Kentang goreng',
        'amount': 12000,
      },
      createdAt: DateTime(2026, 10, 23, 19, 42),
    ),
    GroupEventModel(
      eventId: 'evt_del',
      type: GroupEventType.expenseDeleted,
      actorUid: 'u_bima',
      actorName: 'Bima',
      payload: {
        'sessionId': 'sess_23okt',
        'noteId': 'n_deleted',
        'title': 'Kerupuk kaleng',
        'amount': 5000,
        'deleted': true,
      },
      createdAt: DateTime(2026, 10, 23, 19, 55),
    ),
    GroupEventModel(
      eventId: 'evt_end',
      type: GroupEventType.sessionEnd,
      actorUid: 'u_kamu',
      actorName: 'Kamu',
      payload: {
        'sessionId': 'sess_23okt',
        'status': 'lolos',
        'totalSpent': 54000,
        'budget': 80000,
      },
      createdAt: DateTime(2026, 10, 23, 21, 10),
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      GroupService.keyActiveGroupId: 'grp_jumat',
      'pj_local_uid': 'u_kamu',
      'pj_display_name': 'Kamu',
    });
    prefs = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(prefs);
  });

  Widget buildDetailApp({
    GroupDateDetailTab initialTab = GroupDateDetailTab.ringkasan,
    double textScale = 1.0,
    GroupNoteTapCallback? onNoteTapped,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeGroupIdProvider.overrideWith((ref) => 'grp_jumat'),
        activeGroupStreamProvider.overrideWith(
          (ref) => Stream.value(sampleGroup),
        ),
        activeGroupMembersStreamProvider.overrideWith(
          (ref) => Stream.value(sampleMembers),
        ),
        activeGroupSessionsStreamProvider.overrideWith(
          (ref) => Stream.value([sampleSession]),
        ),
        groupSessionNotesStreamProvider('sess_23okt').overrideWith(
          (ref) => Stream.value(sampleNotes),
        ),
        groupSessionEventsStreamProvider('sess_23okt').overrideWith(
          (ref) => Stream.value(sampleEvents),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: GroupDateDetailScreen(
                groupId: 'grp_jumat',
                sessionId: 'sess_23okt',
                initialTab: initialTab,
                onNoteTapped: onNoteTapped,
              ),
            );
          },
        ),
      ),
    );
  }

  group('Tahap H3 - Layar 63 (Ringkasan), 64 (Catatan), 65 (Linimasa)', () {
    testWidgets(
      '1. Layar 63 (Tab Ringkasan) menampilkan kartu Hemat, Budget ditentukan oleh, Pengeluaran per orang (termasuk Belum mencatat), chip waktu, dan Bagikan ringkasan',
      (tester) async {
        await tester.pumpWidget(buildDetailApp());
        await tester.pumpAndSettle();

        // Header
        expect(find.text('Jumat, 23 Okt'), findsOneWidget);
        expect(find.text('Lolos'), findsOneWidget);

        // Hero Hemat Card
        expect(find.text('Hemat'), findsOneWidget);
        expect(find.text('Rp26.000'), findsOneWidget);
        expect(find.text('Terpakai Rp54.000'), findsOneWidget);
        expect(find.text('dari Rp80.000'), findsOneWidget);

        // Budget ditentukan oleh
        expect(find.text('BUDGET DITENTUKAN OLEH'), findsOneWidget);
        expect(find.text('Dina · Kocok Dadu'), findsOneWidget);
        expect(
          find.textContaining('5 + 3 = 8 × Rp10.000 = Rp80.000'),
          findsOneWidget,
        );

        // Pengeluaran per orang
        expect(find.text('Pengeluaran per orang'), findsOneWidget);
        expect(find.text('3 catatan'), findsOneWidget);
        expect(find.text('Dina'), findsOneWidget);
        expect(find.text('Rp30.000'), findsOneWidget);
        expect(find.text('Kamu'), findsOneWidget);
        expect(find.text('Raka'), findsOneWidget);
        expect(find.text('Rp12.000'), findsNWidgets(2));
        expect(find.text('Bima'), findsOneWidget);
        expect(find.text('Rp0'), findsOneWidget);
        expect(find.text('Belum mencatat'), findsOneWidget);

        // Chip waktu & Tombol bagikan
        expect(find.text('Mulai 18.55 oleh Kamu'), findsOneWidget);
        expect(find.text('Selesai 21.10'), findsOneWidget);
        expect(find.text('Lama 2 j 15 mnt'), findsOneWidget);
        expect(find.text('Bagikan ringkasan'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Pergantian ke Layar 64 (Tab Catatan) menampilkan chip anggota, sisa setelahnya berurutan, menyembunyikan catatan deleted, dan memfilter per anggota',
      (tester) async {
        String? tappedNoteTitle;
        await tester.pumpWidget(
          buildDetailApp(
            onNoteTapped: (ctx, item, session, group) {
              tappedNoteTitle = item.note.title;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Ketuk tab Catatan
        await tester.tap(find.text('Catatan'));
        await tester.pumpAndSettle();

        expect(find.text('Semua · 3'), findsOneWidget);
        expect(find.text('Total Rp54.000'), findsOneWidget);

        // 3 catatan aktif tampil beserta sisa setelahnya
        expect(find.text('Sate taichan'), findsOneWidget);
        expect(
          find.text('Dina · 19.20 · sisa setelahnya Rp50.000'),
          findsOneWidget,
        );
        expect(find.text('Es teh jumbo'), findsOneWidget);
        expect(
          find.text('Kamu · 19.38 · sisa setelahnya Rp38.000'),
          findsOneWidget,
        );
        expect(find.text('Kentang goreng'), findsOneWidget);
        expect(
          find.text('Raka · 19.42 · sisa setelahnya Rp26.000'),
          findsOneWidget,
        );

        // Catatan tombstone (deleted: true) tidak tampil di daftar
        expect(find.text('Kerupuk kaleng'), findsNothing);

        // Ketuk catatan pertama memicu callback onNoteTapped
        await tester.tap(find.text('Sate taichan'));
        await tester.pump();
        expect(tappedNoteTitle, equals('Sate taichan'));

        // Filter hanya anggota "Dina"
        await tester.tap(find.text('Dina'));
        await tester.pumpAndSettle();

        expect(find.text('Total Rp30.000'), findsOneWidget);
        expect(find.text('1 catatan'), findsOneWidget);
        expect(find.text('Sate taichan'), findsOneWidget);
        expect(find.text('Es teh jumbo'), findsNothing);
      },
    );

    testWidgets(
      '3. Pergantian ke Layar 65 (Tab Linimasa) menampilkan simpul mulai, permainan, catatan, penghapusan catatan, dan selesai date',
      (tester) async {
        await tester.pumpWidget(
          buildDetailApp(initialTab: GroupDateDetailTab.linimasa),
        );
        await tester.pumpAndSettle();

        expect(find.text('18.55'), findsOneWidget);
        expect(find.text('19.02'), findsOneWidget);
        expect(find.text('8 × Rp10.000 = budget Rp80.000'), findsOneWidget);
        expect(find.text('Sate taichan'), findsOneWidget);
        expect(find.text('Es teh jumbo'), findsOneWidget);
        expect(find.text('Kentang goreng'), findsOneWidget);
        // Catatan yang dihapus tampil di linimasa
        expect(find.text('Kerupuk kaleng'), findsOneWidget);
        expect(find.text('Hemat Rp26.000 · 3 catatan'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Layar 63, 64, 65 bebas overflow pada lebar 320dp dan 390dp dengan textScale 1.3',
      (tester) async {
        for (final width in [320.0, 390.0]) {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          for (final tab in GroupDateDetailTab.values) {
            await tester.pumpWidget(
              buildDetailApp(
                initialTab: tab,
                textScale: 1.3,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  });
}

