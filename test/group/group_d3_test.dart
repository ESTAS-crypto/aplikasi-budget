import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';
import 'package:putar_jajan/features/group/screens/group_wheel_view.dart';
import 'package:putar_jajan/features/group/screens/group_dice_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupGameService testGameService;

  const String testGid = 'group_d3_test';
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

  group('Fase D3: Layar 18 (Roda Bersama)', () {
    testWidgets('Displays Layar 18 components and PUTAR RODA button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        pools: const {
          'wheel': [20000, 40000, 60000, 100000],
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
        child: const GroupWheelView(),
        group: group,
        members: members,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Putar Jajan'), findsOneWidget);
      expect(find.text('PUTAR RODA'), findsOneWidget);
      expect(find.text('4 Pilihan'), findsOneWidget);
    });

    testWidgets('Locked session displays "Date berjalan · permainan terkunci"', (tester) async {
      final activeSession = GroupSessionModel(
        sessionId: 'sess_999',
        budget: 60000,
        game: 'wheel',
        startedByUid: ownerUid,
        startedByName: 'Budi',
        startedAt: DateTime.now(),
        locked: true,
      );

      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        activeSession: activeSession,
        lockPolicy: 'lock',
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupWheelView(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Date berjalan · permainan terkunci'), findsOneWidget);
      expect(find.text('Sisa budget grup'), findsOneWidget);
    });

    testWidgets('playPolicy == owner disables spin for non-owner member', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
      );

      await testPrefs.setString(GroupAuthService.keyFallbackUid, memberUid);
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);

      await tester.pumpWidget(createTestWidget(
        child: const GroupWheelView(),
        group: group,
        currentUid: memberUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hanya pemilik yang bisa memainkan'), findsOneWidget);
    });
  });

  group('Fase D3: Layar 57 (Kocok Dadu Grup)', () {
    testWidgets('Displays Layar 57 layout with dice, multiplier chips, and action button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        diceConfig: const {'count': 2, 'multiplier': 10000},
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
        GroupMemberModel(
          uid: memberUid,
          name: 'Dina',
          colorIndex: 1,
          role: 'member',
          joinedAt: DateTime.now(),
          lastReadAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        child: const GroupDiceScreen(),
        group: group,
        members: members,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header & Subtitle
      expect(find.text('Kocok Dadu'), findsOneWidget);
      expect(find.text('2 dadu × nominal pilihanmu'), findsOneWidget);

      // Group Status Strip
      expect(find.text('Grup · Date Jumat'), findsOneWidget);
      expect(find.textContaining('online'), findsOneWidget);
      expect(find.textContaining('hasil dilihat semua'), findsOneWidget);

      // Multiplier Section
      expect(find.text('Kelipatan'), findsOneWidget);
      expect(find.text('Rp5.000'), findsOneWidget);
      expect(find.text('Rp10.000'), findsOneWidget);
      expect(find.text('Rp20.000'), findsOneWidget);

      // Budget status
      expect(find.text('Budget grup untuk date ini'), findsOneWidget);
      expect(find.text('Permainan lain terkunci sampai date selesai.'), findsOneWidget);

      // Action Button
      expect(find.text('KOCOK DADU'), findsOneWidget);
    });

    testWidgets('Locked session disables KOCOK DADU button with locked label', (tester) async {
      final activeSession = GroupSessionModel(
        sessionId: 'sess_dice_1',
        budget: 80000,
        game: 'dice',
        startedByUid: ownerUid,
        startedByName: 'Budi',
        startedAt: DateTime.now(),
        locked: true,
      );

      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        activeSession: activeSession,
        lockPolicy: 'lock',
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupDiceScreen(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Date berjalan · permainan terkunci'), findsOneWidget);
      expect(find.text('Rp80.000'), findsWidgets);
    });

    testWidgets('playPolicy == owner disables roll button for member', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
      );

      await testPrefs.setString(GroupAuthService.keyFallbackUid, memberUid);
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);

      await tester.pumpWidget(createTestWidget(
        child: const GroupDiceScreen(),
        group: group,
        currentUid: memberUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hanya pemilik yang bisa memainkan'), findsOneWidget);
    });

    testWidgets('Renders without overflow on 320dp width and textScale 1.3', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat Weekend',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupDiceScreen(),
        group: group,
        width: 320,
        textScale: 1.3,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}

