import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';
import 'package:putar_jajan/features/group/screens/group_games_hub_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;

  const String ownerUid = 'uid_owner_1';
  const String memberUid = 'uid_member_2';
  const String testGid = 'grp_hub_test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
  });

  Widget createTestWidget({
    required GroupModel group,
    required List<GroupMemberModel> members,
    String currentUid = ownerUid,
    double width = 390,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(testPrefs),
        groupServiceProvider.overrideWithValue(testGroupService),
        groupAuthServiceProvider.overrideWithValue(testAuthService),
        activeGroupIdProvider.overrideWith((ref) => testGid),
        activeGroupStreamProvider.overrideWith((ref) => Stream.value(group)),
        activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(members)),
        unreadActivityCountProvider.overrideWithValue(2),
        appScopeProvider.overrideWith((ref) => AppScope.grup),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const GroupGamesHubView(),
        ),
      ),
    );
  }

  group('Fase D2: Layar 55 (Home Grup Belum Ada Budget)', () {
    testWidgets('Displays Layar 55 layout correctly with 5 games and Shuffle button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        enabledGames: const ['wheel', 'dice', 'capsule', 'envelope', 'coin'],
      );

      final members = [
        GroupMemberModel(
          uid: ownerUid,
          name: 'Kelvin',
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

      await tester.pumpWidget(createTestWidget(group: group, members: members));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header checks
      expect(find.text('Malam ini mau main apa?'), findsOneWidget);
      expect(find.text('Pilih permainan'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // unread badge

      // ScopeSwitcher checks
      expect(find.text('Pribadi'), findsOneWidget);
      expect(find.text('Grup · Date Jumat'), findsOneWidget);

      // Games checks
      expect(find.text('Roda Putar'), findsOneWidget);
      expect(find.text('Kocok Dadu'), findsOneWidget);
      expect(find.text('Gacha Kapsul'), findsOneWidget);
      expect(find.text('Pilih Amplop'), findsOneWidget);
      expect(find.text('Lempar Koin'), findsOneWidget);

      // Status info card (Layar 55: Belum ada budget)
      expect(find.text('Date ini belum punya budget'), findsOneWidget);
      expect(find.text('Mainkan satu permainan. Hasilnya jadi budget grup.'), findsOneWidget);

      // Action button
      expect(find.text('Acak aja, serahkan ke aplikasi'), findsOneWidget);
    });

    testWidgets('Disabled game by owner shows "Dimatikan pemilik"', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        enabledGames: const ['wheel', 'dice', 'envelope', 'coin'], // capsule disabled
      );

      await tester.pumpWidget(createTestWidget(group: group, members: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dimatikan pemilik'), findsOneWidget);
    });

    testWidgets('playPolicy == owner disables action button for non-owner member', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
        playPolicy: 'owner',
      );

      // Member signed in
      await testPrefs.setString(GroupAuthService.keyFallbackUid, memberUid);
      testAuthService = GroupAuthService(auth: null, prefs: testPrefs);

      await tester.pumpWidget(createTestWidget(
        group: group,
        members: [],
        currentUid: memberUid,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hanya pemilik yang bisa memainkan'), findsOneWidget);
    });
  });

  group('Fase D2: Layar 56 (Home Grup Sesi Terkunci / Date Berjalan)', () {
    testWidgets('Displays Layar 56 locked session state', (tester) async {
      final activeSession = GroupSessionModel(
        sessionId: 'sess_123',
        budget: 80000,
        game: 'dice',
        startedByUid: memberUid,
        startedByName: 'Dina',
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
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

      await tester.pumpWidget(createTestWidget(group: group, members: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Info card shows locked player & game
      expect(find.text('Terkunci'), findsOneWidget);
      expect(find.text('Date berjalan · permainan terkunci'), findsOneWidget);
      expect(find.textContaining('memainkan Kocok Dadu', findRichText: true), findsOneWidget);
      expect(find.textContaining('Rp80.000'), findsOneWidget);
    });
  });

  group('Fase D2: Mode Budget Tetap (Fixed Budget)', () {
    testWidgets('Fixed budget mode shows card and MULAI DATE button', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Tetap',
        ownerUid: ownerUid,
        code: 'FIX123',
        createdAt: DateTime.now(),
        budgetMode: 'fixed',
        fixedBudget: 250000,
      );

      await tester.pumpWidget(createTestWidget(group: group, members: []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Budget tetap Rp250.000'), findsOneWidget);
      expect(find.text('MULAI DATE'), findsOneWidget);
    });
  });

  group('Fase D2: Responsiveness & Overflow Test', () {
    testWidgets('Renders without overflow on 320dp width and textScale 1.3', (tester) async {
      final group = GroupModel(
        id: testGid,
        name: 'Date Jumat Weekend',
        ownerUid: ownerUid,
        code: 'FRIDAY',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(
        group: group,
        members: [],
        width: 320,
        textScale: 1.3,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No overflow errors
      expect(tester.takeException(), isNull);
    });
  });
}
