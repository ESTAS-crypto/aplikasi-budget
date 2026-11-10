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
import 'package:putar_jajan/features/group/screens/group_coin_screen.dart';
import 'package:putar_jajan/features/group/screens/group_games_hub_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupGameService testGameService;

  const String testGid = 'group_d5_test';
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

  group('Fase D5: Layar 60 (Lempar Koin Grup)', () {
    testWidgets('Displays Layar 60 components and LEMPAR KOIN button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        coinBase: 50000,
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
        child: const GroupCoinScreen(),
        group: group,
        members: members,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lempar Koin'), findsOneWidget);
      expect(find.text('Gambar x2 · Angka setengah'), findsOneWidget);
      expect(find.textContaining('Date Jumat'), findsOneWidget);
      expect(find.text('Lemparan 0 dari 3'), findsOneWidget);
      expect(find.text('Nominal dasar'), findsOneWidget);
      expect(find.text('Rp50.000'), findsOneWidget);
      expect(find.text('Budget grup untuk date ini'), findsOneWidget);
      expect(find.text('LEMPAR KOIN'), findsOneWidget);
    });

    testWidgets('Enforces playPolicy == owner on Layar 60', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
        coinBase: 50000,
      );

      // Simulasikan pengguna non-owner
      await testPrefs.setString(GroupAuthService.keyFallbackUid, memberUid);
      await testPrefs.setString(GroupAuthService.keyDisplayName, 'Member Anggota');
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
      testGroupService = GroupService(firestore: null, authService: testAuthService, prefs: testPrefs);
      testGameService = GroupGameService(groupService: testGroupService, authService: testAuthService);

      await tester.pumpWidget(createTestWidget(
        child: const GroupCoinScreen(),
        group: group,
        currentUid: memberUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hanya pemilik yang bisa memainkan'), findsOneWidget);

      final button = tester.widget<StickerButton>(find.byType(StickerButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Enforces lockPolicy == lock on Layar 60 when date is active', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 100000,
          game: 'coin',
          startedByUid: ownerUid,
          startedByName: 'Budi',
          startedAt: DateTime.now(),
          locked: true,
        ),
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupCoinScreen(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Date berjalan · permainan terkunci'), findsOneWidget);
      expect(find.text('Rp100.000'), findsNWidgets(2)); // Result card & budget bar
    });

    testWidgets('Enforces turn lock on Layar 60 when another member is flipping', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 0,
          game: 'coin',
          startedByUid: memberUid,
          startedByName: 'Siti',
          startedAt: DateTime.now(),
          locked: false,
          turnLockedByUid: memberUid,
          turnLockedByName: 'Siti',
          turnLockedAt: DateTime.now(),
        ),
      );

      // User saat ini adalah ownerUid, sedangkan koin dikunci oleh memberUid 'Siti'
      await tester.pumpWidget(createTestWidget(
        child: const GroupCoinScreen(),
        group: group,
        currentUid: ownerUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Giliran dimainkan Siti'), findsOneWidget);

      final button = tester.widget<StickerButton>(find.byType(StickerButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Responsive without overflow on 320dp and 390dp (Layar 60)', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        coinBase: 50000,
      );

      for (final width in [320.0, 390.0]) {
        await tester.pumpWidget(createTestWidget(
          child: const GroupCoinScreen(),
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

  group('Fase D5: Mode Angka Tetap (Fixed Budget & MULAI DATE)', () {
    testWidgets('Displays Fixed Budget card and MULAI DATE button on Group Hub', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        budgetMode: 'fixed',
        fixedBudget: 75000,
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
        child: const GroupGamesHubView(),
        group: group,
        members: members,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Budget tetap Rp75.000'), findsOneWidget);
      expect(find.text('MULAI DATE'), findsOneWidget);
    });

    testWidgets('Starts fixed budget session when owner taps MULAI DATE', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        budgetMode: 'fixed',
        fixedBudget: 75000,
      );

      await tester.pumpWidget(createTestWidget(
        child: const GroupGamesHubView(),
        group: group,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('MULAI DATE'));
      await tester.tap(find.text('MULAI DATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final updatedGroup = testGroupService.getLocalGroup(group.id);
      expect(updatedGroup?.activeSession?.budget, 75000);
      expect(updatedGroup?.activeSession?.game, 'fixed');
    });
  });
}
