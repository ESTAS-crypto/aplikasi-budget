import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/invite_code_boxes.dart';
import 'package:putar_jajan/core/group/widgets/member_avatar.dart';
import 'package:putar_jajan/core/group/widgets/dashed_member_slot.dart';
import 'package:putar_jajan/features/group/screens/join_or_create_group_screen.dart';
import 'package:putar_jajan/features/group/screens/group_invite_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;

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

  group('G2: GroupService Unit Tests', () {
    test('createGroup validates name and creates group locally', () async {
      expect(
        () => testGroupService.createGroup(
          groupName: '',
          creatorName: 'Budi',
          colorIndex: 0,
        ),
        throwsArgumentError,
      );

      final gid = await testGroupService.createGroup(
        groupName: 'Ngedate Weekend',
        creatorName: 'Budi',
        colorIndex: 2,
      );

      expect(gid, startsWith('grp_'));
      expect(testGroupService.getActiveGroupId(), equals(gid));
      expect(testAuthService.displayName, equals('Budi'));
      expect(testAuthService.colorIndex, equals(2));
    });

    test('joinGroupByCode normalizes code and validates format', () async {
      expect(
        () => testGroupService.joinGroupByCode(
          rawCode: '12',
          memberName: 'Siti',
          colorIndex: 1,
        ),
        throwsFormatException,
      );

      final gid = await testGroupService.joinGroupByCode(
        rawCode: ' abc99k ',
        memberName: 'Siti',
        colorIndex: 1,
      );

      expect(gid, equals('grp_mock_ABC99K'));
      expect(testGroupService.getActiveGroupId(), equals(gid));
    });
  });

  group('G2: UI Component Tests', () {
    testWidgets('InviteCodeBoxes renders 6 boxes and updates input', (tester) async {
      String typed = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InviteCodeBoxes(
              code: 'ABC',
              onChanged: (val) {
                typed = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'XYZ789');
      expect(typed, equals('XYZ789'));
    });

    testWidgets('MemberAvatar renders initials and owner crown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MemberAvatar(name: 'Budi Santoso', colorIndex: 0, isOwner: true),
                MemberAvatar(name: 'Andi', colorIndex: 3, isOwner: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('BS'), findsOneWidget);
      expect(find.text('AN'), findsOneWidget);
    });

    testWidgets('DashedMemberSlot paints without exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashedMemberSlot(label: 'Slot Kosong'),
          ),
        ),
      );

      expect(find.text('Slot Kosong'), findsOneWidget);
    });
  });

  group('G2: Screen 16 & 17 Widget Tests', () {
    testWidgets('JoinOrCreateGroupScreen renders form and controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
          ],
          child: const MaterialApp(
            home: JoinOrCreateGroupScreen(),
          ),
        ),
      );

      expect(find.text('Grup Bersama'), findsOneWidget);
      expect(find.text('Buat Grup Baru'), findsOneWidget);
      expect(find.text('Gabung Grup Teman'), findsOneWidget);
      expect(find.text('Buat Grup'), findsOneWidget);
      expect(find.text('Gabung Grup'), findsOneWidget);
    });

    testWidgets('GroupInviteScreen renders code and member list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
          ],
          child: const MaterialApp(
            home: GroupInviteScreen(groupId: 'grp_test'),
          ),
        ),
      );

      expect(find.text('Kode Undangan Grup'), findsOneWidget);
      expect(find.text('Salin Kode'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);
      expect(find.text('Mulai Pakai Grup'), findsOneWidget);
    });

    testWidgets('Layar 16 & 17 render on 320dp and 390dp with textScale 1.3 without overflow', (tester) async {
      const widths = [320.0, 390.0];

      for (final w in widths) {
        tester.view.physicalSize = Size(w * 2.0, 800 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        // Layar 16
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(testPrefs),
              groupAuthServiceProvider.overrideWithValue(testAuthService),
              groupServiceProvider.overrideWithValue(testGroupService),
            ],
            child: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: JoinOrCreateGroupScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layar 16 no overflow on $w dp');

        // Layar 17
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(testPrefs),
              groupAuthServiceProvider.overrideWithValue(testAuthService),
              groupServiceProvider.overrideWithValue(testGroupService),
            ],
            child: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: GroupInviteScreen(groupId: 'grp_test'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layar 17 no overflow on $w dp');
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}

