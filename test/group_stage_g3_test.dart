import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/features/group/screens/group_notes_view.dart';
import 'package:putar_jajan/features/date/active_date_screen.dart';
import 'package:putar_jajan/data/database_provider.dart';

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

  group('G3: GroupService Note Append-Only Tests', () {
    test('addNote validates input and generates client-side UUID', () async {
      await testAuthService.setDisplayName('Rian');

      expect(
        () => testGroupService.addNote(
          gid: 'grp_1',
          sessionId: 'sess_1',
          title: '',
          amount: 20000,
        ),
        throwsArgumentError,
      );

      expect(
        () => testGroupService.addNote(
          gid: 'grp_1',
          sessionId: 'sess_1',
          title: 'Kopi',
          amount: 0,
        ),
        throwsArgumentError,
      );

      final noteId = await testGroupService.addNote(
        gid: 'grp_1',
        sessionId: 'sess_1',
        title: 'Kopi Susu',
        amount: 25000,
      );

      expect(noteId, startsWith('note_'));
    });
  });

  group('G3: GroupNotesView Widget Tests', () {
    testWidgets('GroupNotesView renders empty state when no group active', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
          ],
          child: const MaterialApp(
            home: GroupNotesView(),
          ),
        ),
      );

      expect(find.text('Belum Bergabung Grup'), findsOneWidget);
      expect(find.text('BUAT ATAU GABUNG GRUP'), findsOneWidget);
    });

    testWidgets('ActiveDateScreen switches to GroupNotesView via ScopeSwitcher', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(testPrefs),
          groupAuthServiceProvider.overrideWithValue(testAuthService),
          groupServiceProvider.overrideWithValue(testGroupService),
          activeDateStreamProvider.overrideWith((ref) => Stream.value(null)),
          activeDateItemsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ActiveDateScreen(),
          ),
        ),
      );

      // Default Pribadi
      expect(find.text('Pribadi'), findsOneWidget);
      expect(find.text('Grup'), findsOneWidget);
      expect(find.text('Belum ada date yang berjalan'), findsOneWidget);

      // Tap Grup
      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      // Now shows GroupNotesView
      expect(find.text('Belum Bergabung Grup'), findsOneWidget);
    });

    testWidgets('GroupNotesView renders active session budget hero card', (tester) async {
      final now = DateTime.now();
      final activeGroup = GroupModel(
        id: 'grp_1',
        name: 'Grup Jajan Malam',
        ownerUid: 'uid_1',
        code: 'XYZ123',
        createdAt: now,
        memberCount: 2,
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 150000,
          startedByUid: 'uid_1',
          startedByName: 'Budi',
          startedAt: now,
        ),
      );

      final testNotes = [
        GroupNoteModel(
          noteId: 'n1',
          sessionId: 'sess_1',
          authorUid: 'uid_1',
          authorName: 'Budi',
          title: 'Ayam Geprek',
          amount: 35000,
          createdAt: now,
          hasPendingWrites: false,
        ),
        GroupNoteModel(
          noteId: 'n2',
          sessionId: 'sess_1',
          authorUid: 'uid_2',
          authorName: 'Siti',
          title: 'Bobba Tea',
          amount: 25000,
          createdAt: now.add(const Duration(minutes: 2)),
          hasPendingWrites: true, // Pending offline write
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
            activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value(testNotes)),
          ],
          child: const MaterialApp(
            home: GroupNotesView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Grup Jajan Malam'), findsOneWidget);
      expect(find.text('SISA BUDGET GRUP'), findsOneWidget);
      // 150.000 - 60.000 = 90.000
      expect(find.text('Rp90.000'), findsOneWidget);
      expect(find.text('Catat jajan'), findsOneWidget);
      expect(find.text('Ayam Geprek'), findsOneWidget);
      expect(find.text('Bobba Tea'), findsOneWidget);

      // Verify pending write badge
      expect(find.text('Menunggu'), findsWidgets);
    });

    testWidgets('Layar 19 renders on 320dp and 390dp with textScale 1.3 without overflow', (tester) async {
      const widths = [320.0, 390.0];
      final now = DateTime.now();

      final activeGroup = GroupModel(
        id: 'grp_1',
        name: 'Grup Jajan Weekend Super Panjang Sekali',
        ownerUid: 'uid_1',
        code: 'XYZ123',
        createdAt: now,
        memberCount: 2,
        activeSession: GroupSessionModel(
          sessionId: 'sess_1',
          budget: 200000,
          startedByUid: 'uid_1',
          startedByName: 'Budi Santoso',
          startedAt: now,
        ),
      );

      final testNotes = [
        GroupNoteModel(
          noteId: 'n1',
          sessionId: 'sess_1',
          authorUid: 'uid_1',
          authorName: 'Budi Santoso',
          title: 'Martabak Manis Keju Coklat Spesial',
          amount: 65000,
          createdAt: now,
          hasPendingWrites: false,
        ),
      ];

      for (final w in widths) {
        tester.view.physicalSize = Size(w * 2.0, 800 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(testPrefs),
              groupAuthServiceProvider.overrideWithValue(testAuthService),
              groupServiceProvider.overrideWithValue(testGroupService),
              activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
              activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value(testNotes)),
            ],
            child: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: GroupNotesView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layar 19 no overflow on $w dp');
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}

