import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupGameService testGameService;

  const String ownerUid = 'uid_owner_123';
  const String memberUid = 'uid_member_456';
  const String testGid = 'grp_test_group';

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

  group('Fase D1: Group Model & Pools Tests', () {
    test('GroupModel default pools, diceConfig, coinBase, policies', () {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Ngedate',
        ownerUid: ownerUid,
        code: 'ABCDEF',
        createdAt: DateTime.now(),
      );

      expect(group.playPolicy, equals('all'));
      expect(group.lockPolicy, equals('lock'));
      expect(group.budgetMode, equals('game'));
      expect(group.fixedBudget, equals(200000));
      expect(group.coinBase, equals(50000));
      expect(group.diceCount, equals(2));
      expect(group.diceMultiplier, equals(10000));
      expect(group.enabledGames.length, equals(5));
      expect(group.isGameEnabled('wheel'), isTrue);
      expect(group.isGameEnabled('dice'), isTrue);
      expect(group.isGameEnabled('capsule'), isTrue);
      expect(group.isGameEnabled('envelope'), isTrue);
      expect(group.isGameEnabled('coin'), isTrue);

      // Pools
      expect(group.getWheelPool().length, greaterThanOrEqualTo(2));
      expect(group.getCapsulePool().length, greaterThanOrEqualTo(2));
      expect(group.getEnvelopePool().length, greaterThanOrEqualTo(3));
    });

    test('GroupModel backward compatibility: wheelSlots mapped to wheel pool', () {
      final map = {
        'name': 'Grup Lama',
        'ownerUid': ownerUid,
        'code': 'XYZ123',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'wheelSlots': [50000, 100000, 150000],
        'spinPolicy': 'owner',
      };

      final group = GroupModel.fromMap('grp_old', map);
      expect(group.playPolicy, equals('owner'));
      expect(group.getWheelPool(), equals([50000, 100000, 150000]));
      expect(group.getCapsulePool(), equals(GroupModel.defaultCapsulePool));
      expect(group.getEnvelopePool(), equals(GroupModel.defaultEnvelopePool));
    });

    test('Pool sanitization clamps values and ensures constraints', () {
      final map = {
        'name': 'Grup Custom Pool',
        'ownerUid': ownerUid,
        'code': 'POOL99',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'pools': {
          'wheel': [500, 25000, 50000, 20000000], // 500 & 20M invalid (<1000 or >10M)
          'envelope': [30000, 60000], // only 2 items, envelope requires min 3
        },
        'diceConfig': {'count': 5, 'multiplier': 25000}, // count clamped to max 3
        'coinBase': 150000,
      };

      final group = GroupModel.fromMap('grp_custom', map);
      // Wheel pool has 2 valid items (25000, 50000)
      expect(group.getWheelPool(), equals([25000, 50000]));
      // Envelope fell back to default because it had < 3 valid items
      expect(group.getEnvelopePool(), equals(GroupModel.defaultEnvelopePool));
      // Dice count clamped to 3
      expect(group.diceCount, equals(3));
      expect(group.diceMultiplier, equals(25000));
      expect(group.coinBase, equals(150000));
    });
  });

  group('Fase D1: PlayPolicy (All vs Owner)', () {
    test('playPolicy == all allows both owner and regular members', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Bebas Main',
        ownerUid: ownerUid,
        code: 'ALL001',
        createdAt: DateTime.now(),
        playPolicy: 'all',
      );
      await testGroupService.saveLocalGroup(group);

      expect(testGameService.canUserPlay(group: group, uid: ownerUid), isTrue);
      expect(testGameService.canUserPlay(group: group, uid: memberUid), isTrue);
    });

    test('playPolicy == owner allows owner but rejects regular members', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Khusus Pemilik',
        ownerUid: ownerUid,
        code: 'OWN001',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
      );
      await testGroupService.saveLocalGroup(group);

      expect(testGameService.canUserPlay(group: group, uid: ownerUid), isTrue);
      expect(testGameService.canUserPlay(group: group, uid: memberUid), isFalse);

      // Attempt claim by regular member
      await switchUser(memberUid, 'Anggota Biasa');

      final result = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'dice',
        amount: 80000,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Hanya pemilik yang bisa memutar'));
    });
  });

  group('Fase D1: LockPolicy & Multi-client Race Condition', () {
    test('lockPolicy == lock: first player claims session, second player loses race condition', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Lock',
        ownerUid: ownerUid,
        code: 'LCK001',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
      );
      await testGroupService.saveLocalGroup(group);

      // Player A (Budi) plays and claims session
      await switchUser('uid_budi', 'Budi');

      final resultA = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'dice',
        amount: 60000,
        detail: {'dice': [3, 3]},
      );

      expect(resultA.success, isTrue);
      expect(resultA.activeSession, isNotNull);
      expect(resultA.activeSession!.budget, equals(60000));
      expect(resultA.activeSession!.locked, isTrue);
      expect(resultA.event, isNotNull);
      expect(resultA.event!.type, equals(GroupEventType.gameResult));
      expect(resultA.event!.payload['valid'], isTrue);

      // Player B (Siti) plays at same time and tries to claim while session is locked
      await switchUser('uid_siti', 'Siti');

      final resultB = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'capsule',
        amount: 100000,
        detail: {'capsuleIndex': 2},
      );

      // Player B loses race condition
      expect(resultB.success, isFalse);
      expect(resultB.isRaceConditionLost, isTrue);
      expect(resultB.message, contains('Sesi sudah dimulai oleh Budi'));
      expect(resultB.message, contains('Hasilmu tidak berlaku'));

      // Event written for Player B is marked valid: false
      expect(resultB.event, isNotNull);
      expect(resultB.event!.payload['valid'], isFalse);

      // Active session in group remains Budi's 60000 budget
      final updatedGroup = testGroupService.getLocalGroup(testGid);
      expect(updatedGroup!.activeSession!.budget, equals(60000));
      expect(updatedGroup.activeSession!.startedByUid, equals('uid_budi'));
    });

    test('lockPolicy == free: subsequent games update session budget freely', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Free Policy',
        ownerUid: ownerUid,
        code: 'FRE001',
        createdAt: DateTime.now(),
        lockPolicy: 'free',
      );
      await testGroupService.saveLocalGroup(group);

      // Player A plays
      await switchUser('uid_budi', 'Budi');

      final resultA = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'wheel',
        amount: 40000,
      );
      expect(resultA.success, isTrue);

      // Player B plays: with free policy, result replaces session budget
      await switchUser('uid_siti', 'Siti');

      final resultB = await testGameService.claimSessionAndWriteResult(
        gid: testGid,
        game: 'envelope',
        amount: 75000,
      );
      expect(resultB.success, isTrue);

      final updatedGroup = testGroupService.getLocalGroup(testGid);
      expect(updatedGroup!.activeSession!.budget, equals(75000));
      expect(updatedGroup.activeSession!.startedByUid, equals('uid_siti'));
    });
  });

  group('Fase D1: Lempar Koin Turn Locking', () {
    test('coin game turn lock prevents simultaneous throws by different members', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Koin',
        ownerUid: ownerUid,
        code: 'COIN01',
        createdAt: DateTime.now(),
      );
      await testGroupService.saveLocalGroup(group);

      // User A claims coin turn
      final claimA = await testGameService.claimCoinTurn(
        gid: testGid,
        uid: 'uid_budi',
        userName: 'Budi',
      );
      expect(claimA, isTrue);

      var cur = testGroupService.getLocalGroup(testGid);
      expect(cur!.activeSession!.isTurnLockedBy('uid_budi'), isTrue);

      // User B tries to claim coin turn while Budi holds the lock
      final claimB = await testGameService.claimCoinTurn(
        gid: testGid,
        uid: 'uid_siti',
        userName: 'Siti',
      );
      expect(claimB, isFalse);

      // User A can claim again / continue flipping
      final claimA2 = await testGameService.claimCoinTurn(
        gid: testGid,
        uid: 'uid_budi',
        userName: 'Budi',
      );
      expect(claimA2, isTrue);

      // User A releases turn
      await testGameService.releaseCoinTurn(
        gid: testGid,
        uid: 'uid_budi',
      );

      cur = testGroupService.getLocalGroup(testGid);
      expect(cur!.activeSession!.isTurnLocked, isFalse);

      // Now User B can successfully claim turn
      final claimB2 = await testGameService.claimCoinTurn(
        gid: testGid,
        uid: 'uid_siti',
        userName: 'Siti',
      );
      expect(claimB2, isTrue);
    });
  });

  group('Fase D1: Fixed Budget Mode', () {
    test('fixed budget mode starts session WITHOUT creating game_result event', () async {
      final group = GroupModel(
        id: testGid,
        name: 'Grup Fixed Budget',
        ownerUid: ownerUid,
        code: 'FIX001',
        createdAt: DateTime.now(),
        budgetMode: 'fixed',
        fixedBudget: 250000,
      );
      await testGroupService.saveLocalGroup(group);

      await switchUser(ownerUid, 'Pemilik');

      final result = await testGameService.startFixedBudgetSession(
        gid: testGid,
        fixedBudget: 250000,
      );

      expect(result.success, isTrue);
      expect(result.activeSession, isNotNull);
      expect(result.activeSession!.budget, equals(250000));
      expect(result.activeSession!.game, equals('fixed'));

      // Event MUST be sessionStart, NOT gameResult (Section 5)
      expect(result.event, isNotNull);
      expect(result.event!.type, equals(GroupEventType.sessionStart));
      expect(result.event!.type, isNot(equals(GroupEventType.gameResult)));

      final events = testGroupService.getLocalEvents(testGid);
      expect(events.any((e) => e.type == GroupEventType.gameResult), isFalse);
      expect(events.any((e) => e.type == GroupEventType.sessionStart), isTrue);
    });
  });
}
