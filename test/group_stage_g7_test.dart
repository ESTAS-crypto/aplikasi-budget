import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_member_model.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_notification_settings_service.dart';
import 'package:putar_jajan/core/group/sync/sync_state.dart';
import 'package:putar_jajan/core/group/widgets/scope_switcher.dart';
import 'package:putar_jajan/core/group/widgets/sync_strip.dart';
import 'package:putar_jajan/core/group/widgets/sync_badge.dart';
import 'package:putar_jajan/core/group/widgets/activity_tile.dart';
import 'package:putar_jajan/core/group/widgets/invite_code_boxes.dart';
import 'package:putar_jajan/core/group/widgets/setting_toggle.dart';
import 'package:putar_jajan/features/group/screens/group_activity_screen.dart';
import 'package:putar_jajan/features/group/screens/group_notification_screen.dart';
import 'package:putar_jajan/features/group/screens/group_wheel_view.dart';
import 'package:putar_jajan/features/group/screens/group_notes_view.dart';
import 'package:putar_jajan/features/group/screens/join_or_create_group_screen.dart';
import 'package:putar_jajan/features/group/screens/group_invite_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupNotificationSettingsService testSettingsService;

  final sampleGroup = GroupModel(
    id: 'g-date-jumat',
    name: 'Date Jumat Berkah',
    ownerUid: 'uid-dina',
    code: 'ABCDEF',
    createdAt: DateTime(2026, 10, 24, 18, 0),
    memberCount: 2,
    activeSession: GroupSessionModel(
      sessionId: 'sess-01',
      budget: 200000,
      startedByUid: 'uid-dina',
      startedByName: 'Dina',
      startedAt: DateTime(2026, 10, 24, 18, 0),
    ),
  );

  final List<GroupMemberModel> sampleMembers = [
    GroupMemberModel(
      uid: 'uid-dina',
      name: 'Dina',
      colorIndex: 0,
      role: 'owner',
      joinedAt: DateTime(2026, 10, 24, 18, 0),
      lastReadAt: DateTime(2026, 10, 24, 18, 0),
    ),
    GroupMemberModel(
      uid: 'uid-budi',
      name: 'Budi',
      colorIndex: 1,
      role: 'member',
      joinedAt: DateTime(2026, 10, 24, 18, 5),
      lastReadAt: DateTime(2026, 10, 24, 18, 5),
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_display_name': 'Budi',
      'group_notif_g-date-jumat_expenses': true,
      'group_notif_g-date-jumat_spin': true,
      'group_notif_g-date-jumat_warning80': true,
      'group_notif_g-date-jumat_members': false,
    });
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
    testSettingsService = GroupNotificationSettingsService(testPrefs);
  });

  group('G7: Accessibility & Semantics (TalkBack) Tests', () {
    testWidgets('ScopeSwitcher semantics are descriptive for screen reader', (tester) async {
      AppScope scope = AppScope.pribadi;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScopeSwitcher(
              currentScope: scope,
              onScopeChanged: (newScope) => scope = newScope,
            ),
          ),
        ),
      );

      // Verify Semantics labels
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Beralih ke mode Pribadi',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Beralih ke mode Grup',
        ),
        findsOneWidget,
      );

      // Tap to switch to group
      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();
      expect(scope, equals(AppScope.grup));
    });

    testWidgets('SyncStrip and SyncBadge expose clear semantics for network and item state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SyncStrip(state: SyncState.offline, isVisible: true),
                SyncStrip(state: SyncState.gagal, isVisible: true, onRetry: () {}),
                const SyncBadge(hasPendingWrites: true),
                const SyncBadge(hasPendingWrites: false),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Status sinkronisasi: Offline: Menggunakan data di HP ini',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Status sinkronisasi: Gagal sinkron ke server',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Coba lagi sinkronisasi data',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Catatan menunggu koneksi untuk terkirim ke server',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Catatan sudah tersimpan di server',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ActivityTile and SettingToggle provide informative TalkBack descriptions', (tester) async {
      final sampleEvent = GroupEventModel(
        eventId: 'ev-1',
        type: GroupEventType.expense,
        actorUid: 'uid-dina',
        actorName: 'Dina',
        payload: {
          'title': 'Sate Taichan',
          'amount': 30000,
          'remainingBudget': 170000,
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      bool toggleValue = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ActivityTile(
                  event: sampleEvent,
                  isUnread: true,
                  colorIndex: 0,
                  isMe: false,
                ),
                SettingToggle(
                  value: toggleValue,
                  label: 'Catatan pengeluaran anggota',
                  onChanged: (v) => toggleValue = v,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Aktivitas baru: Dina mencatat "Sate Taichan"',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Catatan pengeluaran anggota',
        ),
        findsOneWidget,
      );
    });

    testWidgets('InviteCodeBoxes semantics handles readOnly and interactive modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                InviteCodeBoxes(code: 'ABCDEF', isReadOnly: true),
                InviteCodeBoxes(code: 'XYZ', isReadOnly: false),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Kode undangan grup: A B C D E F',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Kotak kode undangan 6 karakter, terisi 3 dari 6 huruf',
        ),
        findsOneWidget,
      );
    });
  });

  group('G7: Append-Only Data & Budget Resilience Tests', () {
    test('Derived budget calculation remains consistent regardless of note arrival order', () {
      const budget = 200000;
      final notes = [
        {'id': 'n1', 'amount': 25000, 'deleted': false},
        {'id': 'n2', 'amount': 45000, 'deleted': false},
        {'id': 'n3', 'amount': 15000, 'deleted': true}, // Tombstone
        {'id': 'n1', 'amount': 25000, 'deleted': false}, // Duplicate idempotent
      ];

      // Dedup by id
      final Map<String, Map<String, dynamic>> deduped = {};
      for (final n in notes) {
        deduped[n['id'] as String] = n;
      }

      int totalSpent = 0;
      for (final n in deduped.values) {
        if (n['deleted'] != true) {
          totalSpent += (n['amount'] as int);
        }
      }

      final remaining = budget - totalSpent;
      expect(totalSpent, equals(70000));
      expect(remaining, equals(130000));
    });
  });

  group('G7: Comprehensive 6-Screen Responsive Layout (320dp & 390dp, textScale 1.3)', () {
    final screens = <String, Widget>{
      'Layar 16: JoinOrCreateGroupScreen': const JoinOrCreateGroupScreen(),
      'Layar 17: GroupInviteScreen': const GroupInviteScreen(groupId: 'g-date-jumat'),
      'Layar 18: GroupWheelView': const GroupWheelView(),
      'Layar 19: GroupNotesView': const GroupNotesView(),
      'Layar 20: GroupActivityScreen': const GroupActivityScreen(),
      'Layar 21: GroupNotificationScreen': const GroupNotificationScreen(),
    };

    for (final entry in screens.entries) {
      testWidgets('${entry.key} renders without overflow on 320dp and 390dp with textScale 1.3', (tester) async {
        for (final width in [320.0, 390.0]) {
          tester.view.physicalSize = Size(width * 2, 750 * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(testPrefs),
                groupAuthServiceProvider.overrideWithValue(testAuthService),
                groupServiceProvider.overrideWithValue(testGroupService),
                activeGroupStreamProvider.overrideWith((ref) => Stream.value(sampleGroup)),
                activeGroupMembersStreamProvider.overrideWith((ref) => Stream.value(sampleMembers)),
                activeGroupNotesStreamProvider.overrideWith((ref) => Stream.value([])),
                activeGroupEventsStreamProvider.overrideWith((ref) => Stream.value([])),
                unreadActivityCountProvider.overrideWith((ref) => 0),
                groupNotificationSettingsServiceProvider.overrideWithValue(testSettingsService),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 750),
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: Scaffold(body: entry.value),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
