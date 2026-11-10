import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/invite_code_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_note_model.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/sync/sync_state.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/widgets/sync_strip.dart';
import 'package:putar_jajan/core/group/widgets/sync_badge.dart';
import 'package:putar_jajan/core/group/widgets/sync_legend.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('G1: InviteCodeGenerator & InviteCodeModel Tests', () {
    test('generate produces 6-character string from safe alphabet', () {
      const allowedAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
      const forbiddenChars = ['0', 'O', '1', 'I', 'L', 'o', 'i', 'l'];

      for (int i = 0; i < 50; i++) {
        final code = InviteCodeGenerator.generate();
        expect(code.length, equals(6));

        for (final char in code.split('')) {
          expect(allowedAlphabet.contains(char), isTrue);
          expect(forbiddenChars.contains(char), isFalse);
        }
      }
    });

    test('1,000 generated codes have high entropy and reasonable uniqueness', () {
      final set = <String>{};
      for (int i = 0; i < 1000; i++) {
        set.add(InviteCodeGenerator.generate());
      }
      // Out of 31^6 (~887 million) combinations, 1,000 items should almost certainly have >= 998 unique values
      expect(set.length, greaterThanOrEqualTo(998));
    });

    test('normalize sanitizes user input (uppercase & trim) and validates format', () {
      expect(InviteCodeGenerator.normalize(' abc99x '), equals('ABC99X'));
      expect(InviteCodeGenerator.isValidFormat('ABC99X'), isTrue);
      expect(InviteCodeGenerator.isValidFormat('AB099X'), isFalse); // '0' is invalid
      expect(InviteCodeGenerator.isValidFormat('AB'), isFalse); // too short
      expect(InviteCodeGenerator.isValid('  ABC99X  '), isTrue);
    });

    test('InviteCodeModel maps correctly to and from Map', () {
      final now = DateTime.now();
      final codeModel = InviteCodeModel(
        code: 'ABCD23',
        gid: 'grp_123',
        createdAt: now,
      );
      expect(codeModel.code, equals('ABCD23'));
      expect(codeModel.gid, equals('grp_123'));

      final map = codeModel.toMap();
      final fromMap = InviteCodeModel.fromMap('ABCD23', map);
      expect(fromMap.code, equals('ABCD23'));
      expect(fromMap.gid, equals('grp_123'));
    });

    test('GroupMemberModel correctly serializes and detects owner role', () {
      final now = DateTime.now();
      final member = GroupMemberModel(
        uid: 'user_1',
        name: 'Rian',
        colorIndex: 2,
        role: 'owner',
        joinedAt: now,
        lastReadAt: now,
      );
      expect(member.isOwner, isTrue);

      final map = member.toMap();
      final fromMap = GroupMemberModel.fromMap('user_1', map);
      expect(fromMap.uid, equals('user_1'));
      expect(fromMap.name, equals('Rian'));
      expect(fromMap.colorIndex, equals(2));
      expect(fromMap.isOwner, isTrue);
    });
  });

  group('G1: SyncStateResolver & SyncStateService Tests', () {
    test('SyncStateResolver correctly resolves all state combinations', () {
      // 1. Error state takes highest precedence
      expect(
        SyncStateResolver.resolve(isOnline: true, hasPendingWrites: false, hasWriteError: true),
        equals(SyncState.gagal),
      );
      expect(
        SyncStateResolver.resolve(isOnline: false, hasPendingWrites: true, hasWriteError: true),
        equals(SyncState.gagal),
      );

      // 2. Offline with pending writes => menunggu
      expect(
        SyncStateResolver.resolve(isOnline: false, hasPendingWrites: true, hasWriteError: false),
        equals(SyncState.menunggu),
      );

      // 3. Offline without pending writes => offline
      expect(
        SyncStateResolver.resolve(isOnline: false, hasPendingWrites: false, hasWriteError: false),
        equals(SyncState.offline),
      );

      // 4. Online with pending writes => menyinkronkan
      expect(
        SyncStateResolver.resolve(isOnline: true, hasPendingWrites: true, hasWriteError: false),
        equals(SyncState.menyinkronkan),
      );

      // 5. Online without pending writes => tersinkron
      expect(
        SyncStateResolver.resolve(isOnline: true, hasPendingWrites: false, hasWriteError: false),
        equals(SyncState.tersinkron),
      );
    });

    testWidgets('SyncStateService debounces 1500ms before showing non-synced strip', (tester) async {
      final service = SyncStateService();
      expect(service.state, equals(SyncState.tersinkron));
      expect(service.isStripVisible, isFalse);

      // Network disconnects
      service.updateConditions(isOnline: false, hasPendingWrites: false);

      // Raw state immediately reflects offline, but debounced state is still tersinkron & strip hidden
      expect(service.rawState, equals(SyncState.offline));
      expect(service.state, equals(SyncState.tersinkron));
      expect(service.isStripVisible, isFalse);

      // Advance by 1000ms (still within 1500ms debounce)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(service.isStripVisible, isFalse);

      // Advance past 1500ms
      await tester.pump(const Duration(milliseconds: 600));
      expect(service.isStripVisible, isTrue);
      expect(service.state, equals(SyncState.offline));

      // Reconnects
      service.updateConditions(isOnline: true, hasPendingWrites: false);
      // Immediately shows 'Tersinkron'
      expect(service.state, equals(SyncState.tersinkron));
      expect(service.isStripVisible, isTrue);

      // After 2000ms, strip fades out
      await tester.pump(const Duration(milliseconds: 2100));
      expect(service.isStripVisible, isFalse);

      service.dispose();
    });
  });

  group('G1: GroupModel Deterministic Budget Calculation', () {
    test('calculateTotalSpent excludes deleted notes (tombstones)', () {
      final now = DateTime.now();
      const testSessionId = 'sess_1';

      final notes = [
        GroupNoteModel(
          noteId: 'note_1',
          sessionId: testSessionId,
          authorUid: 'uid_1',
          authorName: 'Budi',
          title: 'Kopi',
          amount: 25000,
          createdAt: now,
        ),
        GroupNoteModel(
          noteId: 'note_2',
          sessionId: testSessionId,
          authorUid: 'uid_2',
          authorName: 'Siti',
          title: 'Snack',
          amount: 15000,
          createdAt: now,
          deleted: true, // Deleted tombstone
        ),
        GroupNoteModel(
          noteId: 'note_3',
          sessionId: testSessionId,
          authorUid: 'uid_1',
          authorName: 'Budi',
          title: 'Es Krim',
          amount: 10000,
          createdAt: now,
        ),
      ];

      final total = GroupModel.calculateTotalSpent(testSessionId, notes);
      // 25000 + 10000 = 35000 (15000 ignored because deleted=true)
      expect(total, equals(35000));
    });

    test('calculateRemainingBudget computes sessionBudget - non_deleted_notes deterministically across random order', () {
      final now = DateTime.now();
      const testSessionId = 'sess_1';

      final session = GroupSessionModel(
        sessionId: testSessionId,
        budget: 100000,
        startedByUid: 'uid_1',
        startedByName: 'Budi',
        startedAt: now,
      );

      final n1 = GroupNoteModel(
        noteId: 'n1',
        sessionId: testSessionId,
        authorUid: 'u1',
        authorName: 'A',
        title: 'Item 1',
        amount: 40000,
        createdAt: now,
      );
      final n2 = GroupNoteModel(
        noteId: 'n2',
        sessionId: testSessionId,
        authorUid: 'u2',
        authorName: 'B',
        title: 'Item 2',
        amount: 20000,
        createdAt: now.add(const Duration(minutes: 1)),
      );

      // Order [n1, n2]
      final remainingForward = GroupModel.calculateRemainingBudget(
        sessionBudget: session.budget,
        sessionId: testSessionId,
        notes: [n1, n2],
      );
      expect(remainingForward, equals(40000)); // 100000 - 60000 = 40000

      // Order reversed [n2, n1] (out of order arrival in offline-sync)
      final remainingReverse = GroupModel.calculateRemainingBudget(
        sessionBudget: session.budget,
        sessionId: testSessionId,
        notes: [n2, n1],
      );
      expect(remainingReverse, equals(40000));
    });
  });

  group('G1: GroupAuthService Validation & Caching', () {
    test('isValidDisplayName enforces 1-20 characters without whitespace overflow', () {
      expect(GroupAuthService.isValidDisplayName(''), isFalse);
      expect(GroupAuthService.isValidDisplayName('   '), isFalse);
      expect(GroupAuthService.isValidDisplayName('A'), isTrue);
      expect(GroupAuthService.isValidDisplayName('Rizky Pratama'), isTrue);
      expect(GroupAuthService.isValidDisplayName('12345678901234567890'), isTrue); // 20 chars
      expect(GroupAuthService.isValidDisplayName('123456789012345678901'), isFalse); // 21 chars
    });

    test('setDisplayName and setColorIndex persist and validate values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = GroupAuthService(auth: null, prefs: prefs);

      expect(service.displayName, isNull);
      expect(service.hasCompletedProfile, isFalse);

      await service.setDisplayName('  Andi  ');
      expect(service.displayName, equals('Andi'));
      expect(service.hasCompletedProfile, isTrue);

      await service.setColorIndex(3);
      expect(service.colorIndex, equals(3));

      expect(() => service.setColorIndex(8), throwsRangeError);
      expect(() => service.setDisplayName(''), throwsArgumentError);
    });
  });

  group('G1: Neo-Brutalist Widgets Tests', () {
    testWidgets('SyncStrip renders correctly for offline & retry on gagal', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStrip(
              state: SyncState.offline,
              isVisible: true,
            ),
          ),
        ),
      );

      expect(find.text('Offline: Menggunakan data di HP ini'), findsOneWidget);

      // Rebuild with gagal and retry button
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStrip(
              state: SyncState.gagal,
              isVisible: true,
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Gagal sinkron ke server'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      expect(retried, isTrue);
    });

    testWidgets('SyncBadge displays Menunggu when pending, Terkirim when synced', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SyncBadge(hasPendingWrites: true),
                SyncBadge(hasPendingWrites: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Menunggu'), findsOneWidget);
      expect(find.text('Terkirim'), findsOneWidget);
    });

    testWidgets('SyncLegend displays all 5 sync state explanations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SyncLegend(),
            ),
          ),
        ),
      );

      expect(find.text('Arti status sinkron'), findsOneWidget);
      expect(find.text(SyncState.tersinkron.label), findsOneWidget);
      expect(find.text(SyncState.menunggu.label), findsOneWidget);
      expect(find.text(SyncState.menyinkronkan.label), findsOneWidget);
      expect(find.text(SyncState.offline.label), findsOneWidget);
      expect(find.text('Gagal'), findsOneWidget);
    });

    testWidgets('ScopeSwitcher toggles between Pribadi and Grup', (tester) async {
      AppScope selected = AppScope.pribadi;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: ScopeSwitcher(
                  currentScope: selected,
                  onScopeChanged: (newScope) {
                    setState(() {
                      selected = newScope;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Pribadi'), findsOneWidget);
      expect(find.text('Grup'), findsOneWidget);

      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      expect(selected, equals(AppScope.grup));
    });
  });
}
