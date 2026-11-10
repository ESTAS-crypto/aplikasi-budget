import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupGameService testGameService;

  const String ownerUid = 'uid_owner_f1';
  const String memberUid = 'uid_member_f1';
  const String testGid = 'grp_test_f1';

  Future<void> switchUser(String uid, String name) async {
    await testPrefs.setString(GroupAuthService.keyFallbackUid, uid);
    await testPrefs.setString(GroupAuthService.keyDisplayName, name);
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGameService = GroupGameService(
      groupService: testGroupService,
      authService: testAuthService,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
    testGameService = GroupGameService(
      groupService: testGroupService,
      authService: testAuthService,
    );
  });

  group('F1 Mandatory Tests: Pemilik Tidak Boleh Terkunci & PlayDenied', () {
    test('(a) pemilik memutar, anggota memutar, pemilik memutar lagi: berhasil dengan konfirmasi', () async {
      // Setup grup dengan lockPolicy: lock
      final group = GroupModel(
        id: testGid,
        name: 'Grup Ngedate F1',
        ownerUid: ownerUid,
        code: 'DATE01',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
        playPolicy: 'all',
      );
      await testGroupService.saveLocalGroup(group);

      // 1. Pemilik memutar pertama kali (Raka Rp50.000)
      await switchUser(ownerUid, 'Raka (Owner)');
      final res1 = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'wheel',
        amount: 50000,
      );
      expect(res1.success, isTrue);
      expect(res1.activeSession!.budget, equals(50000));
      expect(res1.activeSession!.startedByUid, equals(ownerUid));
      expect(res1.activeSession!.locked, isTrue);

      // 2. Anggota mencoba memutar saat sesi terkunci
      await switchUser(memberUid, 'Sari (Member)');
      final permMember = evaluateCanPlay(
        group: testGroupService.getLocalGroup(testGid),
        uid: memberUid,
      );
      expect(permMember.allowed, isFalse);
      expect(permMember.deniedReason, equals(PlayDenied.sessionLocked));
      expect(permMember.message, contains('Date berjalan, budget sudah ditentukan oleh Raka'));

      final res2 = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'wheel',
        amount: 70000,
      );
      expect(res2.success, isFalse);
      expect(res2.isRaceConditionLost, isTrue);

      // 3. Pemilik memutar lagi (re-spin / ulangi budget Rp80.000)
      await switchUser(ownerUid, 'Raka (Owner)');
      final currentGroup = testGroupService.getLocalGroup(testGid)!;
      final permOwner = evaluateCanPlay(
        group: currentGroup,
        uid: ownerUid,
      );
      // Pemilik SELALU boleh memutar / mengulang, kapan pun, termasuk saat sesi terkunci!
      expect(permOwner.allowed, isTrue);
      expect(permOwner.deniedReason, equals(PlayDenied.none));

      final res3 = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'wheel',
        amount: 80000,
      );
      expect(res3.success, isTrue);
      expect(res3.activeSession!.budget, equals(80000));
      expect(res3.activeSession!.startedByUid, equals(ownerUid));

      // Verifikasi di local storage
      final finalGroup = testGroupService.getLocalGroup(testGid)!;
      expect(finalGroup.activeSession!.budget, equals(80000));
    });

    test('(b) anggota saat playPolicy owner: ditolak dengan pesan notOwner', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Khusus Pemilik',
        ownerUid: ownerUid,
        code: 'OWN999',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
        lockPolicy: 'lock',
      );
      await testGroupService.saveLocalGroup(group);

      // Anggota mengevaluasi izin bermain
      final perm = evaluateCanPlay(group: group, uid: memberUid);
      expect(perm.allowed, isFalse);
      expect(perm.deniedReason, equals(PlayDenied.notOwner));
      expect(perm.message, equals('Hanya pemilik yang bisa memutar'));

      // Saat anggota mencoba claim
      await switchUser(memberUid, 'Anggota Biasa');
      final res = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'wheel',
        amount: 50000,
      );
      expect(res.success, isFalse);
      expect(res.message, equals('Hanya pemilik yang bisa memutar'));
    });

    test('(c) anggota saat sesi terkunci: pesan sessionLocked', () async {
      final now = DateTime.now();
      final group = GroupModel(
        id: testGid,
        name: 'Grup Sesi Terkunci',
        ownerUid: ownerUid,
        code: 'LCK999',
        createdAt: now,
        playPolicy: 'all',
        lockPolicy: 'lock',
        activeSession: GroupSessionModel(
          sessionId: 'sess_123',
          budget: 80000,
          game: 'wheel',
          startedByUid: 'uid_raka',
          startedByName: 'Raka',
          startedAt: now,
          locked: true,
        ),
      );

      final perm = evaluateCanPlay(group: group, uid: memberUid);
      expect(perm.allowed, isFalse);
      expect(perm.deniedReason, equals(PlayDenied.sessionLocked));
      expect(perm.message, equals('Date berjalan, budget sudah ditentukan oleh Raka'));
    });

    test('(d) uid pemilik tidak berubah setelah anggota bermain', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Uji Immutability',
        ownerUid: ownerUid,
        code: 'IMM001',
        createdAt: DateTime.now(),
        playPolicy: 'all',
        lockPolicy: 'free',
      );
      await testGroupService.saveLocalGroup(group);

      // Anggota bermain dan berhasil menetapkan budget sesi
      await switchUser(memberUid, 'Anggota Satu');
      final res = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'wheel',
        amount: 40000,
      );
      expect(res.success, isTrue);

      // Verifikasi bahwa ownerUid tetap ownerUid asli dan tidak berubah
      final updatedGroup = testGroupService.getLocalGroup(testGid)!;
      expect(updatedGroup.ownerUid, equals(ownerUid));
      expect(updatedGroup.isOwner(ownerUid), isTrue);
      expect(updatedGroup.isOwner(memberUid), isFalse);

      // Sesi startedByUid adalah member, namun ownerUid tetap ownerUid!
      expect(updatedGroup.activeSession!.startedByUid, equals(memberUid));
      expect(updatedGroup.ownerUid, equals(ownerUid));
    });
  });
}

