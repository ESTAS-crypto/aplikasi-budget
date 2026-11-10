import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_game_service.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';
import 'package:putar_jajan/features/group/screens/group_games_hub_view.dart';
import 'package:putar_jajan/features/group/screens/group_notes_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;

  const String ownerUid = 'owner_uid';
  const String testGid = 'grp_end_test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      GroupAuthService.keyFallbackUid: ownerUid,
      'group_user_name': 'Pemilik',
      'group_active_gid': testGid,
    });
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
  });

  group('Fase D6: Fitur Akhiri Date Grup & Buka Kunci Permainan', () {
    testWidgets('GroupGamesHubView menampilkan tombol AKHIRI DATE GRUP saat date terkunci untuk pemilik',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Setup locked group
      final lockedGroup = GroupModel(
        id: testGid,
        name: 'Grup Pengujian',
        ownerUid: ownerUid,
        code: 'XYZ123',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 250000,
          game: 'wheel',
          startedByUid: ownerUid,
          startedByName: 'Pemilik',
          startedAt: DateTime.now(),
          locked: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            activeGroupIdProvider.overrideWith((ref) => testGid),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(lockedGroup)),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value([
              GroupMemberModel(
                uid: ownerUid,
                name: 'Pemilik',
                colorIndex: 0,
                role: 'owner',
                joinedAt: DateTime.now(),
                lastReadAt: DateTime.now(),
              ),
            ])),
            unreadActivityCountProvider.overrideWithValue(0),
            appScopeProvider.overrideWith((ref) => AppScope.grup),
            groupServiceProvider.overrideWithValue(testGroupService),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
          ],
          child: const MaterialApp(
            home: GroupGamesHubView(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Memastikan tombol AKHIRI DATE GRUP muncul di Hub
      expect(find.text('AKHIRI DATE GRUP'), findsOneWidget);

      // Tap tombol AKHIRI DATE GRUP
      await tester.ensureVisible(find.text('AKHIRI DATE GRUP'));
      await tester.tap(find.text('AKHIRI DATE GRUP'));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog konfirmasi muncul
      expect(find.text('Akhiri Date Grup?'), findsOneWidget);
      expect(find.text('Akhiri Date'), findsOneWidget);

      // Konfirmasi akhiri
      await tester.tap(find.text('Akhiri Date'));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('GroupNotesView menampilkan tombol AKHIRI DATE GRUP saat ada sesi aktif untuk pemilik',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Setup locked group
      final lockedGroup = GroupModel(
        id: testGid,
        name: 'Grup Pengujian',
        ownerUid: ownerUid,
        code: 'XYZ123',
        createdAt: DateTime.now(),
        lockPolicy: 'lock',
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 250000,
          game: 'wheel',
          startedByUid: ownerUid,
          startedByName: 'Pemilik',
          startedAt: DateTime.now(),
          locked: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            activeGroupIdProvider.overrideWith((ref) => testGid),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(lockedGroup)),
            activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value([
              GroupMemberModel(
                uid: ownerUid,
                name: 'Pemilik',
                colorIndex: 0,
                role: 'owner',
                joinedAt: DateTime.now(),
                lastReadAt: DateTime.now(),
              ),
            ])),
            activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value([])),
            unreadActivityCountProvider.overrideWithValue(0),
            appScopeProvider.overrideWith((ref) => AppScope.grup),
            groupServiceProvider.overrideWithValue(testGroupService),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
          ],
          child: const MaterialApp(
            home: GroupNotesView(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Memastikan tombol AKHIRI DATE GRUP muncul di catatan
      expect(find.text('AKHIRI DATE GRUP'), findsOneWidget);

      // Tap tombol AKHIRI DATE GRUP
      await tester.ensureVisible(find.text('AKHIRI DATE GRUP'));
      await tester.tap(find.text('AKHIRI DATE GRUP'));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog konfirmasi muncul
      expect(find.text('Akhiri Date Grup?'), findsOneWidget);
      expect(find.text('Akhiri Date'), findsOneWidget);

      // Konfirmasi
      await tester.tap(find.text('Akhiri Date'));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
