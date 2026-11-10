import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';
import 'package:putar_jajan/core/widgets/sticker_button.dart';
import 'package:putar_jajan/features/group/screens/group_capsule_screen.dart';
import 'package:putar_jajan/features/group/screens/group_envelope_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupGameService testGameService;

  const String testGid = 'group_d4_test';
  const String ownerUid = 'user_owner_1';
  const String memberUid = 'user_member_2';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    await testPrefs.setString(GroupAuthService.keyFallbackUid, ownerUid);
    await testPrefs.setString(GroupAuthService.keyDisplayName, 'Owner Tester');

    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(firestore: null, authService: testAuthService, prefs: testPrefs);
    testGameService = GroupGameService(groupService: testGroupService, authService: testAuthService);
  });

  Widget createTestWidget({
    required Widget child,
    required GroupModel group,
    List<GroupMemberModel> members = const [],
    String currentUid = ownerUid,
    double width = 390,
    double textScale = 1.0,
  }) {
    testGroupService.saveLocalGroup(group);
    testGroupService.setActiveGroupId(group.id);

    return ProviderScope(
      overrides: [
        groupServiceProvider.overrideWithValue(testGroupService),
        groupAuthServiceProvider.overrideWithValue(testAuthService),
        groupGameServiceProvider.overrideWithValue(testGameService),
        activeGroupIdProvider.overrideWith((ref) => group.id),
        activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
        activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
        unreadActivityCountProvider.overrideWith((ref) => 0),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('Fase D4: Layar 58 (Gacha Kapsul Grup)', () {
    testWidgets('Displays Layar 58 components and PUTAR TUAS button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        pools: const {
          'capsule': [15000, 25000, 50000, 75000],
        },
      );

      final members = [
        GroupMemberModel(
          uid: ownerUid,
          name: 'Budi',
          colorIndex: 0,
          role: 'owner',
          joinedAt: DateTime.now(),
          lastReadAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        child: const GroupCapsuleScreen(),
        group: group,
        members: members,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Gacha Kapsul'), findsOneWidget);
      expect(find.text('Isi kapsul rahasia, nominal acak'), findsOneWidget);
      expect(find.textContaining('Date Jumat'), findsOneWidget);
      expect(find.text('Putar tuas untuk buka kapsul'), findsOneWidget);
      expect(find.text('Budget grup untuk date ini'), findsOneWidget);
      expect(find.text('PUTAR TUAS'), findsOneWidget);
    });

    testWidgets('Enforces playPolicy == owner on Layar 58', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
        pools: const {
          'capsule': [20000, 30000, 50000],
        },
      );

      // Simulasikan pengguna non-owner
      await testPrefs.setString(GroupAuthService.keyFallbackUid, memberUid);
      await testPrefs.setString(GroupAuthService.keyDisplayName, 'Member Anggota');
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
      testGroupService = GroupService(firestore: null, authService: testAuthService, prefs: testPrefs);
      testGameService = GroupGameService(groupService: testGroupService, authService: testAuthService);

      await tester.pumpWidget(createTestWidget(
        child: const GroupCapsuleScreen(),
        group: group,
        currentUid: memberUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hanya pemilik yang bisa memainkan'), findsOneWidget);

      final button = tester.widget<StickerButton>(find.byType(StickerButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Enforces lockPolicy == lock on Layar 58 when date is active', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 50000,
          game: 'capsule',
          startedByUid: ownerUid,
          startedByName: 'Budi',
          startedAt: DateTime.now(),
          locked: true,
        ),
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupCapsuleScreen(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Date berjalan · permainan terkunci'), findsOneWidget);
      expect(find.text('Rp50.000'), findsNWidgets(2)); // Result card & budget bar
    });

    testWidgets('Responsive without overflow on 320dp and 390dp (Layar 58)', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        pools: const {
          'capsule': [10000, 20000, 30000, 40000, 50000],
        },
      );

      for (final width in [320.0, 390.0]) {
        await tester.pumpWidget(createTestWidget(
          child: const GroupCapsuleScreen(),
          group: group,
          width: width,
          textScale: 1.3,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Fase D4: Layar 59 (Pilih Amplop Grup)', () {
    testWidgets('Displays Layar 59 components and BUKA AMPLOP button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        pools: const {
          'envelope': [20000, 40000, 60000, 80000],
        },
      );

      final members = [
        GroupMemberModel(
          uid: ownerUid,
          name: 'Budi',
          colorIndex: 0,
          role: 'owner',
          joinedAt: DateTime.now(),
          lastReadAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        child: const GroupEnvelopeScreen(),
        group: group,
        members: members,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pilih Amplop'), findsOneWidget);
      expect(find.text('Satu amplop, isinya rahasia'), findsOneWidget);
      expect(find.textContaining('Date Jumat'), findsOneWidget);
      expect(find.text('Amplop tengah yang kamu pilih'), findsOneWidget);
      expect(find.text('Pilih amplop dan tekan buka'), findsOneWidget);
      expect(find.text('Budget grup untuk date ini'), findsOneWidget);
      expect(find.text('BUKA AMPLOP'), findsOneWidget);
    });

    testWidgets('Can select envelope by tapping (Layar 59)', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        pools: const {
          'envelope': [20000, 40000, 60000],
        },
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupEnvelopeScreen(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Default adalah tengah
      expect(find.text('Amplop tengah yang kamu pilih'), findsOneWidget);

      // Tap amplop pertama (kiri)
      await tester.tap(find.byKey(const ValueKey('envelope_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Amplop kiri yang kamu pilih'), findsOneWidget);
    });

    testWidgets('Enforces playPolicy == owner on Layar 59', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
        pools: const {
          'envelope': [20000, 40000, 60000],
        },
      );

      // Simulasikan pengguna non-owner
      await testPrefs.setString(GroupAuthService.keyFallbackUid, memberUid);
      await testPrefs.setString(GroupAuthService.keyDisplayName, 'Member Anggota');
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
      testGroupService = GroupService(firestore: null, authService: testAuthService, prefs: testPrefs);
      testGameService = GroupGameService(groupService: testGroupService, authService: testAuthService);

      await tester.pumpWidget(createTestWidget(
        child: const GroupEnvelopeScreen(),
        group: group,
        currentUid: memberUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hanya pemilik yang bisa memainkan'), findsOneWidget);

      final button = tester.widget<StickerButton>(find.byType(StickerButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Enforces lockPolicy == lock on Layar 59 when date is active', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 40000,
          game: 'envelope',
          startedByUid: ownerUid,
          startedByName: 'Budi',
          startedAt: DateTime.now(),
          locked: true,
        ),
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupEnvelopeScreen(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Date berjalan · permainan terkunci'), findsOneWidget);
      expect(find.text('Rp40.000'), findsNWidgets(2)); // Result card & budget bar
    });

    testWidgets('Responsive without overflow on 320dp and 390dp (Layar 59)', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        pools: const {
          'envelope': [10000, 20000, 30000, 40000],
        },
      );

      for (final width in [320.0, 390.0]) {
        await tester.pumpWidget(createTestWidget(
          child: const GroupEnvelopeScreen(),
          group: group,
          width: width,
          textScale: 1.3,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      }
    });
  });
}
