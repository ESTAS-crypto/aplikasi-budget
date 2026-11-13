import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/models/group_history_models.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UPDATE 3B - H1: Model, Kalkulasi Riwayat Grup, dan Migrasi sessionId', () {
    test('1. Status Lolos vs Lewat, Hemat, dan format lencana Lewat Rp12rb (Rgrup1 & Rgrup2)', () {
      // Sesi 23 Okt: Budget Rp80.000, Terpakai Rp54.000 -> Lolos, Hemat Rp26.000
      final sessionLolos = GroupSessionModel(
        sessionId: 'sess_23_okt',
        gid: 'grp_jumat',
        budget: 80000,
        game: 'dice',
        startedByUid: 'uid_kamu',
        startedByName: 'Kamu',
        startedAt: DateTime(2026, 10, 23, 18, 55),
        endedAt: DateTime(2026, 10, 23, 21, 10),
        endedByUid: 'uid_kamu',
        endedByName: 'Kamu',
        budgetByUid: 'uid_dina',
        budgetByName: 'Dina',
        detail: {
          'rolls': [5, 3],
          'multiplier': 10000,
        },
        status: 'lolos',
        totalSpent: 54000,
      );

      expect(sessionLolos.isLolos, isTrue);
      expect(sessionLolos.isLewat, isFalse);
      expect(sessionLolos.hemat, equals(26000));
      expect(sessionLolos.overBudgetAmount, equals(0));
      expect(
        GroupHistoryCalculator.formatGameResultDetail(sessionLolos),
        equals('5 + 3 = 8 × Rp10.000 = Rp80.000'),
      );

      // Sesi 30 Okt: Budget Rp200.000, Terpakai Rp212.000 -> Lewat Rp12rb
      final sessionLewat = GroupSessionModel(
        sessionId: 'sess_30_okt',
        gid: 'grp_jumat',
        budget: 200000,
        game: 'wheel',
        startedByUid: 'uid_raka',
        startedByName: 'Raka',
        startedAt: DateTime(2026, 10, 30, 19, 0),
        endedAt: DateTime(2026, 10, 30, 21, 0),
        status: 'lewat',
        totalSpent: 212000,
      );

      expect(sessionLewat.isLolos, isFalse);
      expect(sessionLewat.isLewat, isTrue);
      expect(sessionLewat.hemat, equals(-12000));
      expect(sessionLewat.overBudgetAmount, equals(12000));
      expect(
        GroupHistoryCalculator.formatLewatBadge(sessionLewat.overBudgetAmount),
        equals('Lewat Rp12rb'),
      );

      // Batas tepat totalSpent == budget -> tetap Lolos
      final sessionExact = sessionLolos.copyWith(totalSpent: 80000);
      expect(sessionExact.isLolos, isTrue);
      expect(sessionExact.hemat, equals(0));
    });

    test('2. Sisa setelah catatan ke-n dengan urutan server (createdAt lalu noteId) sesuai Rgrup3', () {
      // Masukkan catatan secara acak (tidak berurutan) untuk menguji determinisme sort
      final notes = [
        GroupNoteModel(
          noteId: 'note_3',
          sessionId: 'sess_23_okt',
          authorUid: 'uid_raka',
          authorName: 'Raka',
          title: 'Kentang goreng',
          amount: 12000,
          createdAt: DateTime(2026, 10, 23, 19, 42),
        ),
        GroupNoteModel(
          noteId: 'note_1',
          sessionId: 'sess_23_okt',
          authorUid: 'uid_dina',
          authorName: 'Dina',
          title: 'Sate taichan',
          amount: 30000,
          createdAt: DateTime(2026, 10, 23, 19, 20),
        ),
        GroupNoteModel(
          noteId: 'note_2',
          sessionId: 'sess_23_okt',
          authorUid: 'uid_kamu',
          authorName: 'Kamu',
          title: 'Es teh jumbo',
          amount: 12000,
          createdAt: DateTime(2026, 10, 23, 19, 38),
        ),
      ];

      final withRemaining = GroupHistoryCalculator.computeNotesWithRemaining(
        budget: 80000,
        notes: notes,
      );

      expect(withRemaining.length, equals(3));

      // Catatan 1: Sate taichan Rp30.000 -> sisa Rp50.000 (62.5%)
      expect(withRemaining[0].note.title, equals('Sate taichan'));
      expect(withRemaining[0].sequenceNumber, equals(1));
      expect(withRemaining[0].totalNotes, equals(3));
      expect(withRemaining[0].remainingAfter, equals(50000));
      expect(withRemaining[0].remainingFraction(80000), closeTo(0.625, 0.001));

      // Catatan 2: Es teh jumbo Rp12.000 -> sisa Rp38.000
      expect(withRemaining[1].note.title, equals('Es teh jumbo'));
      expect(withRemaining[1].sequenceNumber, equals(2));
      expect(withRemaining[1].remainingAfter, equals(38000));

      // Catatan 3: Kentang goreng Rp12.000 -> sisa Rp26.000
      expect(withRemaining[2].note.title, equals('Kentang goreng'));
      expect(withRemaining[2].sequenceNumber, equals(3));
      expect(withRemaining[2].remainingAfter, equals(26000));
    });

    test('3. Tie-breaker deterministik saat dua catatan memiliki createdAt identik (urut noteId)', () {
      final sameTime = DateTime(2026, 10, 23, 19, 30);
      final notes = [
        GroupNoteModel(
          noteId: 'note_b',
          sessionId: 'sess_1',
          authorUid: 'u2',
          authorName: 'Bima',
          title: 'Minuman',
          amount: 15000,
          createdAt: sameTime,
        ),
        GroupNoteModel(
          noteId: 'note_a',
          sessionId: 'sess_1',
          authorUid: 'u1',
          authorName: 'Dina',
          title: 'Makanan',
          amount: 25000,
          createdAt: sameTime,
        ),
      ];

      final res = GroupHistoryCalculator.computeNotesWithRemaining(
        budget: 100000,
        notes: notes,
      );

      expect(res[0].note.noteId, equals('note_a'));
      expect(res[0].remainingAfter, equals(75000));
      expect(res[1].note.noteId, equals('note_b'));
      expect(res[1].remainingAfter, equals(60000));
    });

    test('4. Pengeluaran per orang: anggota tanpa catatan (Rp0) & persentase dari totalSpent (Rgrup2)', () {
      final members = [
        GroupMemberModel(
          uid: 'uid_dina',
          name: 'Dina',
          colorIndex: 0,
          role: 'member',
          joinedAt: DateTime(2026, 10, 1),
          lastReadAt: DateTime(2026, 10, 1),
        ),
        GroupMemberModel(
          uid: 'uid_kamu',
          name: 'Kamu',
          colorIndex: 2,
          role: 'owner',
          joinedAt: DateTime(2026, 10, 1),
          lastReadAt: DateTime(2026, 10, 1),
        ),
        GroupMemberModel(
          uid: 'uid_raka',
          name: 'Raka',
          colorIndex: 1,
          role: 'member',
          joinedAt: DateTime(2026, 10, 1),
          lastReadAt: DateTime(2026, 10, 1),
        ),
        GroupMemberModel(
          uid: 'uid_bima',
          name: 'Bima',
          colorIndex: 4,
          role: 'member',
          joinedAt: DateTime(2026, 10, 1),
          lastReadAt: DateTime(2026, 10, 1),
        ),
      ];

      final notes = [
        GroupNoteModel(
          noteId: 'n1',
          sessionId: 's1',
          authorUid: 'uid_dina',
          authorName: 'Dina',
          title: 'Sate taichan',
          amount: 30000,
          createdAt: DateTime(2026, 10, 23, 19, 20),
        ),
        GroupNoteModel(
          noteId: 'n2',
          sessionId: 's1',
          authorUid: 'uid_kamu',
          authorName: 'Kamu',
          title: 'Es teh jumbo',
          amount: 12000,
          createdAt: DateTime(2026, 10, 23, 19, 38),
        ),
        GroupNoteModel(
          noteId: 'n3',
          sessionId: 's1',
          authorUid: 'uid_raka',
          authorName: 'Raka',
          title: 'Kentang goreng',
          amount: 12000,
          createdAt: DateTime(2026, 10, 23, 19, 42),
        ),
        // Catatan deleted tidak boleh dihitung
        GroupNoteModel(
          noteId: 'n4_del',
          sessionId: 's1',
          authorUid: 'uid_bima',
          authorName: 'Bima',
          title: 'Cilok batal',
          amount: 20000,
          createdAt: DateTime(2026, 10, 23, 19, 50),
          deleted: true,
        ),
      ];

      final spending = GroupHistoryCalculator.computeMemberSpending(
        members: members,
        notes: notes,
      );

      expect(spending.length, equals(4));

      // Dina: 30.000 / 54.000 = 55.56% (~56%)
      expect(spending[0].name, equals('Dina'));
      expect(spending[0].amountSpent, equals(30000));
      expect(spending[0].percentagePercent, equals(56));
      expect(spending[0].hasRecorded, isTrue);

      // Kamu: 12.000 / 54.000 = 22.22% (~22%)
      expect(spending[1].name, equals('Kamu'));
      expect(spending[1].amountSpent, equals(12000));
      expect(spending[1].percentagePercent, equals(22));

      // Raka: 12.000 / 54.000 = 22.22% (~22%)
      expect(spending[2].name, equals('Raka'));
      expect(spending[2].amountSpent, equals(12000));
      expect(spending[2].percentagePercent, equals(22));

      // Bima: Rp0 · Belum mencatat
      expect(spending[3].name, equals('Bima'));
      expect(spending[3].amountSpent, equals(0));
      expect(spending[3].percentageOfTotalSpent, equals(0.0));
      expect(spending[3].hasRecorded, isFalse);
    });

    test('5. Duplikat noteId & Tombstone: tombstone menang dan rekalkulasi setelah hapus bekerja akurat', () {
      final t1 = DateTime(2026, 10, 23, 19, 20);
      final t2 = DateTime(2026, 10, 23, 19, 30);

      // Simulasikan salinan duplikat n1 (satu belum deleted, satu sudah deleted/tombstone)
      final rawNotes = [
        GroupNoteModel(
          noteId: 'n1',
          sessionId: 's1',
          authorUid: 'u1',
          authorName: 'Dina',
          title: 'Sate',
          amount: 30000,
          createdAt: t1,
          deleted: false,
        ),
        GroupNoteModel(
          noteId: 'n1',
          sessionId: 's1',
          authorUid: 'u1',
          authorName: 'Dina',
          title: 'Sate',
          amount: 30000,
          createdAt: t1,
          deleted: true, // Tombstone
        ),
        GroupNoteModel(
          noteId: 'n2',
          sessionId: 's1',
          authorUid: 'u2',
          authorName: 'Kamu',
          title: 'Es Teh',
          amount: 12000,
          createdAt: t2,
          deleted: false,
        ),
      ];

      final remainingList = GroupHistoryCalculator.computeNotesWithRemaining(
        budget: 80000,
        notes: rawNotes,
      );

      expect(remainingList.length, equals(1));
      expect(remainingList.first.note.noteId, equals('n2'));
      expect(remainingList.first.remainingAfter, equals(68000));
    });

    test('6. Migrasi aman sessionId mengisi sessionId dari rentang waktu sesi pada catatan & event lama', () {
      final sessionStart = DateTime(2026, 10, 16, 18, 0);
      final sessionEnd = DateTime(2026, 10, 16, 21, 0);

      final legacySession = GroupSessionModel(
        sessionId: 'sess_16_okt',
        gid: 'grp_1',
        budget: 150000,
        game: 'capsule',
        startedByUid: 'uid_kamu',
        startedByName: 'Kamu',
        startedAt: sessionStart,
        endedAt: sessionEnd,
        status: 'lolos',
      );

      // Catatan lama tanpa sessionId di dalam rentang waktu sesi 16 Okt
      final legacyNote = GroupNoteModel(
        noteId: 'note_legacy_1',
        sessionId: '', // kosong
        authorUid: 'uid_kamu',
        authorName: 'Kamu',
        title: 'Kopi Susu',
        amount: 25000,
        createdAt: DateTime(2026, 10, 16, 19, 15),
      );

      // Event lama tanpa sessionId di dalam rentang waktu sesi 16 Okt
      final legacyEvent = GroupEventModel(
        eventId: 'evt_legacy_1',
        type: GroupEventType.expense,
        actorUid: 'uid_kamu',
        actorName: 'Kamu',
        payload: {
          'title': 'Kopi Susu',
          'amount': 25000,
        },
        createdAt: DateTime(2026, 10, 16, 19, 15),
      );

      final migrated = GroupHistoryCalculator.migrateMissingSessionIds(
        gid: 'grp_1',
        sessions: [legacySession],
        notes: [legacyNote],
        events: [legacyEvent],
      );

      expect(migrated.hasChanges, isTrue);
      expect(migrated.notes.first.sessionId, equals('sess_16_okt'));
      expect(migrated.events.first.sessionId, equals('sess_16_okt'));
      expect(migrated.sessions.first.totalSpent, equals(25000));
      expect(migrated.sessions.first.status, equals('lolos'));
    });

    test('7. Integrasi GroupService: pembekuan sesi saat endSession & perhitungan ulang saat hapus catatan', () async {
      SharedPreferences.setMockInitialValues({
        'group_fallback_uid': 'uid_owner',
        'group_display_name': 'Kamu',
      });
      final prefs = await SharedPreferences.getInstance();
      final authService = GroupAuthService(prefs: prefs);
      final groupService = GroupService(
        firestore: null,
        supabase: null,
        authService: authService,
        prefs: prefs,
      );

      const gid = 'grp_test_h1';
      await groupService.saveLocalGroup(
        GroupModel(
          id: gid,
          name: 'Date Jumat',
          ownerUid: 'uid_owner',
          code: 'JUMAT1',
          createdAt: DateTime(2026, 10, 1),
        ),
      );

      // 1. Mulai sesi dengan budget Rp80.000
      await groupService.startFixedSession(gid: gid, fixedBudget: 80000);
      final activeGroup = groupService.getLocalGroup(gid)!;
      final sessionId = activeGroup.activeSession!.sessionId;

      // 2. Tambah 2 catatan: Rp50.000 + Rp40.000 = Rp90.000 (Lewat Rp10.000)
      final note1Id = await groupService.addNote(
        gid: gid,
        sessionId: sessionId,
        title: 'Burger',
        amount: 50000,
        sessionBudget: 80000,
      );
      final note2Id = await groupService.addNote(
        gid: gid,
        sessionId: sessionId,
        title: 'Kentang',
        amount: 40000,
        sessionBudget: 80000,
      );

      // 3. Akhiri sesi -> Sesi dibekukan (TIDAK dihapus), status 'lewat', totalSpent 90000
      await groupService.endSession(gid: gid);
      expect(groupService.getLocalGroup(gid)!.activeSession, isNull);

      final sessionsAfterEnd = await groupService.getGroupSessionsWithMigration(gid);
      expect(sessionsAfterEnd.length, equals(1));
      expect(sessionsAfterEnd.first.sessionId, equals(sessionId));
      expect(sessionsAfterEnd.first.isEnded, isTrue);
      expect(sessionsAfterEnd.first.totalSpent, equals(90000));
      expect(sessionsAfterEnd.first.status, equals('lewat'));

      // 4. Hapus catatan kedua (Rp40.000) -> totalSpent dihitung ulang menjadi Rp50.000, status berubah jadi 'lolos'!
      await groupService.deleteNote(
        gid: gid,
        noteId: note2Id,
        title: 'Kentang',
        amount: 40000,
        sessionBudget: 80000,
      );

      final sessionsAfterDelete = await groupService.getGroupSessionsWithMigration(gid);
      expect(sessionsAfterDelete.first.totalSpent, equals(50000));
      expect(sessionsAfterDelete.first.status, equals('lolos'));
      expect(sessionsAfterDelete.first.hemat, equals(30000));
      expect(note1Id, isNotEmpty);
    });
  });
}

