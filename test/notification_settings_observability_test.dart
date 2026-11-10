import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/notifications/coordinator/notification_coordinator.dart';
import 'package:putar_jajan/core/notifications/models/notification_intent.dart';
import 'package:putar_jajan/core/notifications/storage/notified_claim_store.dart';
import 'package:putar_jajan/features/notifications/screens/notification_debug_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationCoordinator coordinator;
  late InMemoryNotifiedClaimStore claimStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    coordinator = NotificationCoordinator.instance;
    claimStore = InMemoryNotifiedClaimStore();
    coordinator.setClaimStore(claimStore);
    coordinator.clearDecisionHistory();
    coordinator.resetAggregationBuffers();

    coordinator.currentUidGetter = () => 'user_test_me';
    coordinator.isGroupMutedGetter = (_) => false;
    coordinator.isCategoryEnabledGetter = (_) => true;
    coordinator.hasSystemNotificationPermissionGetter = () async => true;
  });

  tearDown(() {
    coordinator.resetAggregationBuffers();
  });

  group('N5: Settings Toggles & Dynamic Muting (UPDATE 2C Section 4)', () {
    test('Toggle change immediately applies in coordinator filter without restart', () async {
      bool allowExpenses = true;
      coordinator.isCategoryEnabledGetter = (cat) {
        if (cat == NotificationCategory.expense) return allowExpenses;
        return true;
      };

      final expenseIntent1 = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Seru',
        eventId: 'evt_toggle_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Dina',
        subtitle: 'Rp20.000',
        systemBody: 'Dina mencatat Rp20.000',
        createdAt: DateTime.now(),
      );

      // 1. Saat toggle ON: notifikasi diterima (banner)
      final dec1 = await coordinator.dispatch(expenseIntent1);
      expect(dec1.surface, equals(NotificationSurface.banner));
      expect(dec1.reason, equals(NotificationDropReason.none));

      // 2. Pengguna mematikan sakelar pengeluaran di Pengaturan
      allowExpenses = false;

      final expenseIntent2 = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Seru',
        eventId: 'evt_toggle_2',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Dina',
        subtitle: 'Rp30.000',
        systemBody: 'Dina mencatat Rp30.000',
        createdAt: DateTime.now(),
      );

      // Seketika di-drop tanpa restart aplikasi!
      final dec2 = await coordinator.dispatch(expenseIntent2);
      expect(dec2.surface, equals(NotificationSurface.dropped));
      expect(dec2.reason, equals(NotificationDropReason.toggleDisabled));
    });

    test('Muting group immediately suppresses notifications without restart', () async {
      bool isMuted = false;
      coordinator.isGroupMutedGetter = (gid) => isMuted;

      final intent1 = NotificationIntent.groupEvent(
        gid: 'grp_mute_test',
        groupName: 'Date Mute',
        eventId: 'evt_mute_1',
        eventType: 'spin',
        actorUid: 'other_uid',
        actorName: 'Budi',
        title: 'Budi',
        subtitle: 'Putar roda',
        systemBody: 'Budi memutar roda',
        createdAt: DateTime.now(),
      );

      final dec1 = await coordinator.dispatch(intent1);
      expect(dec1.surface, equals(NotificationSurface.banner));

      // Pengguna membisukan grup di Pengaturan
      isMuted = true;

      final intent2 = NotificationIntent.groupEvent(
        gid: 'grp_mute_test',
        groupName: 'Date Mute',
        eventId: 'evt_mute_2',
        eventType: 'spin',
        actorUid: 'other_uid',
        actorName: 'Budi',
        title: 'Budi',
        subtitle: 'Putar roda 2',
        systemBody: 'Budi memutar roda lagi',
        createdAt: DateTime.now(),
      );

      final dec2 = await coordinator.dispatch(intent2);
      expect(dec2.surface, equals(NotificationSurface.dropped));
      expect(dec2.reason, equals(NotificationDropReason.muted));
    });
  });

  group('N5: Observability Screen Widget Tests (UPDATE 2C Section 5)', () {
    testWidgets('NotificationDebugScreen renders empty state when no decisions', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NotificationDebugScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Debug Notifikasi'), findsOneWidget);
      expect(find.text('Belum Ada Keputusan'), findsOneWidget);
      expect(find.textContaining('Keputusan (0)'), findsOneWidget);
    });

    testWidgets('NotificationDebugScreen displays decisions and switches to Tabel Notified', (tester) async {
      // Buat 3 keputusan buatan
      final now = DateTime.now();
      await coordinator.dispatch(NotificationIntent.groupEvent(
        gid: 'grp_debug',
        groupName: 'Date Debug',
        eventId: 'evt_dbg_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Dina mencatat',
        subtitle: 'Kopi',
        systemBody: 'Dina mencatat kopi',
        createdAt: now,
      ));

      // Aksi sendiri (dropped ownAction)
      await coordinator.dispatch(NotificationIntent.groupEvent(
        gid: 'grp_debug',
        groupName: 'Date Debug',
        eventId: 'evt_dbg_2',
        eventType: 'spin',
        actorUid: 'user_test_me',
        actorName: 'Saya',
        title: 'Saya',
        subtitle: 'Putar',
        systemBody: 'Saya memutar roda',
        createdAt: now,
      ));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NotificationDebugScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memeriksa tab Keputusan
      expect(find.textContaining('Keputusan (2)'), findsOneWidget);
      expect(find.text('BANNER'), findsOneWidget);
      expect(find.text('DROPPED'), findsOneWidget);
      expect(find.text('reason: ownAction'), findsOneWidget);

      // Beralih ke tab Tabel Notified
      await tester.tap(find.textContaining('Tabel Notified'));
      await tester.pumpAndSettle();

      // Cek baris tab tabel notified
      expect(find.byType(NotificationDebugScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });
  });
}
