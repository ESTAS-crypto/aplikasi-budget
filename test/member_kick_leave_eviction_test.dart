import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';
import 'package:putar_jajan/features/group/screens/group_invite_screen.dart';
import 'package:putar_jajan/features/group/screens/group_wheel_view.dart';
import 'package:putar_jajan/features/group/screens/group_notes_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Member Kick and Leave Eviction Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('leaveGroup clears active group and removes member', () async {
      final authService = GroupAuthService(prefs: prefs);
      await authService.ensureSignedIn();

      final service = GroupService(
        authService: authService,
        prefs: prefs,
      );

      // Create group with owner
      final gid = await service.createGroup(
        groupName: 'Grup Tes',
        creatorName: 'Pemilik',
        colorIndex: 0,
      );

      expect(service.getActiveGroupId(), gid);

      // Voluntarily leave group
      await service.leaveGroup(gid);

      expect(service.getActiveGroupId(), isNull);
      expect(prefs.getString(GroupService.keyActiveGroupId), isNull);
    });

    testWidgets('GroupInviteScreen immediately evicts non-member user and redirects', (tester) async {
      final authService = GroupAuthService(prefs: prefs);
      await authService.ensureSignedIn();

      final service = GroupService(
        authService: authService,
        prefs: prefs,
      );

      // Create group owned by SOMEONE ELSE
      const otherOwnerUid = 'owner_999';
      const gid = 'grp_test_evict';
      final now = DateTime.now();

      // Only owner is in member list (myUid is NOT in members, i.e. was kicked or not joined)
      await prefs.setString('local_group_$gid', '''{
        "name": "Grup Ngabuburit",
        "ownerUid": "$otherOwnerUid",
        "code": "JYGVEQ",
        "createdAt": ${now.millisecondsSinceEpoch},
        "memberCount": 1
      }''');
      await prefs.setString('local_members_$gid', '''[
        {
          "uid": "$otherOwnerUid",
          "name": "evan",
          "colorIndex": 0,
          "role": "owner",
          "joinedAt": ${now.millisecondsSinceEpoch},
          "lastReadAt": ${now.millisecondsSinceEpoch}
        }
      ]''');
      await service.setActiveGroupId(gid);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupAuthServiceProvider.overrideWithValue(authService),
          groupServiceProvider.overrideWithValue(service),
        ],
      );

      // Put scope in grup
      container.read(appScopeProvider.notifier).state = AppScope.grup;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GroupInviteScreen(groupId: gid),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Because user is NOT owner and NOT in members, eviction should trigger:
      // activeGroupId is cleared to null
      expect(container.read(activeGroupIdProvider), isNull);
      // appScope is reset to pribadi
      expect(container.read(appScopeProvider), AppScope.pribadi);
    });

    testWidgets('GroupWheelView immediately renders no-group state for kicked/non-member user', (tester) async {
      final authService = GroupAuthService(prefs: prefs);
      await authService.ensureSignedIn();

      final service = GroupService(
        authService: authService,
        prefs: prefs,
      );

      const otherOwnerUid = 'owner_999';
      const gid = 'grp_wheel_evict';
      final now = DateTime.now();

      await prefs.setString('local_group_$gid', '''{
        "name": "Grup Roda",
        "ownerUid": "$otherOwnerUid",
        "code": "XYZ123",
        "createdAt": ${now.millisecondsSinceEpoch},
        "memberCount": 1
      }''');
      await prefs.setString('local_members_$gid', '''[
        {
          "uid": "$otherOwnerUid",
          "name": "evan",
          "colorIndex": 0,
          "role": "owner",
          "joinedAt": ${now.millisecondsSinceEpoch},
          "lastReadAt": ${now.millisecondsSinceEpoch}
        }
      ]''');
      await service.setActiveGroupId(gid);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupAuthServiceProvider.overrideWithValue(authService),
          groupServiceProvider.overrideWithValue(service),
        ],
      );

      container.read(appScopeProvider.notifier).state = AppScope.grup;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GroupWheelView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays "Belum Bergabung Grup" rather than the group wheel
      expect(find.text('Belum Bergabung Grup'), findsOneWidget);
      // activeGroupId is cleared
      expect(container.read(activeGroupIdProvider), isNull);
      // appScope is reset to pribadi
      expect(container.read(appScopeProvider), AppScope.pribadi);
    });

    testWidgets('GroupNotesView immediately renders no-group state for kicked/non-member user', (tester) async {
      final authService = GroupAuthService(prefs: prefs);
      await authService.ensureSignedIn();

      final service = GroupService(
        authService: authService,
        prefs: prefs,
      );

      const otherOwnerUid = 'owner_999';
      const gid = 'grp_notes_evict';
      final now = DateTime.now();

      await prefs.setString('local_group_$gid', '''{
        "name": "Grup Catatan",
        "ownerUid": "$otherOwnerUid",
        "code": "ABC789",
        "createdAt": ${now.millisecondsSinceEpoch},
        "memberCount": 1
      }''');
      await prefs.setString('local_members_$gid', '''[
        {
          "uid": "$otherOwnerUid",
          "name": "evan",
          "colorIndex": 0,
          "role": "owner",
          "joinedAt": ${now.millisecondsSinceEpoch},
          "lastReadAt": ${now.millisecondsSinceEpoch}
        }
      ]''');
      await service.setActiveGroupId(gid);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          groupAuthServiceProvider.overrideWithValue(authService),
          groupServiceProvider.overrideWithValue(service),
        ],
      );

      container.read(appScopeProvider.notifier).state = AppScope.grup;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GroupNotesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays "Belum Bergabung Grup"
      expect(find.text('Belum Bergabung Grup'), findsOneWidget);
      expect(container.read(activeGroupIdProvider), isNull);
      expect(container.read(appScopeProvider), AppScope.pribadi);
    });
  });
}
