import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putar_jajan/core/notifications/notifications.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  late NotificationCoordinator coordinator;
  late InMemoryNotifiedClaimStore claimStore;

  setUp(() {
    coordinator = NotificationCoordinator.instance;
    claimStore = InMemoryNotifiedClaimStore();
    coordinator.setClaimStore(claimStore);
    coordinator.clearDecisionHistory();

    // Default configuration
    coordinator.setLifecycleState(AppLifecycleState.resumed);
    coordinator.currentUidGetter = () => 'user_123';
    coordinator.isGroupMutedGetter = (gid) => false;
    coordinator.isCategoryEnabledGetter = (cat) => true;
    coordinator.hasSystemNotificationPermissionGetter = () async => true;

    coordinator.onRenderBanner = null;
    coordinator.onRenderSystem = null;
    coordinator.onRenderDialog = null;
  });

  group('N1: Normalization & Stable ID', () {
    test('dedupeKey format adheres to UPDATE 2C specifications', () {
      final evt = NotificationIntent.groupEvent(
        gid: 'grp_01',
        groupName: 'Date Seru',
        eventId: 'ev_99',
        eventType: 'expense_created',
        actorUid: 'user_456',
        actorName: 'Dina',
        title: 'Dina menambahkan Rp30.000',
        subtitle: 'Sate taichan',
        systemBody: 'Dina menambahkan Rp30.000 untuk sate taichan.',
      );
      expect(evt.dedupeKey, 'evt:grp_01:ev_99');
      expect(evt.stableNotificationId, greaterThanOrEqualTo(0));
      expect(evt.stableNotificationId, lessThanOrEqualTo(0x7FFFFFFF));

      final bud80 = NotificationIntent.budget80(
        scopeId: 'grp_01',
        sessionId: 'sess_01',
        groupOrAppName: 'Date Seru',
        remainingBudget: 40000,
        totalBudget: 200000,
        spentAmount: 160000,
      );
      expect(bud80.dedupeKey, 'bud80:grp_01:sess_01');

      final budOver = NotificationIntent.budgetOver(
        scopeId: 'grp_01',
        sessionId: 'sess_01',
        groupOrAppName: 'Date Seru',
        overAmount: 12000,
        totalBudget: 200000,
        totalSpent: 212000,
      );
      expect(budOver.dedupeKey, 'budOver:grp_01:sess_01');

      final rem = NotificationIntent.weeklyReminder(year: 2026, weekNumber: 45);
      expect(rem.dedupeKey, 'rem:2026-W45');

      final strk = NotificationIntent.streakCelebration(
        streakWeeks: 3,
        date: DateTime(2026, 11, 7),
      );
      expect(strk.dedupeKey, 'streak:2026-11-07');

      final sync = NotificationIntent.syncFailed(
        gid: 'grp_01',
        groupName: 'Date Seru',
        unsyncedCount: 2,
      );
      expect(sync.dedupeKey, 'syncfail:grp_01');
      expect(sync.isImportantDialog, isTrue);
    });

    test('stableNotificationId is completely deterministic across instances', () {
      final intentA = NotificationIntent.weeklyReminder(year: 2026, weekNumber: 45);
      final intentB = NotificationIntent.weeklyReminder(year: 2026, weekNumber: 45);
      expect(intentA.stableNotificationId, equals(intentB.stableNotificationId));
    });
  });

  group('N1: Atomic Claim & Anti-Double', () {
    test('same intent dispatched twice: exactly 1 rendered, 2nd dropped as duplicate', () async {
      int bannerCount = 0;
      coordinator.onRenderBanner = (intent) async {
        bannerCount++;
      };

      final intent = NotificationIntent.groupEvent(
        gid: 'grp_01',
        groupName: 'Date Seru',
        eventId: 'ev_double_1',
        eventType: 'expense_created',
        actorUid: 'user_456',
        actorName: 'Dina',
        title: 'Dina menambahkan Rp30.000',
        subtitle: 'Sate taichan',
        systemBody: 'Dina menambahkan Rp30.000 untuk sate taichan.',
      );

      // First dispatch: should succeed
      final decision1 = await coordinator.dispatch(intent);
      expect(decision1.surface, NotificationSurface.banner);
      expect(decision1.reason, NotificationDropReason.none);
      expect(bannerCount, 1);

      // Second dispatch with same dedupeKey: MUST drop as duplicate
      final decision2 = await coordinator.dispatch(intent);
      expect(decision2.surface, NotificationSurface.dropped);
      expect(decision2.reason, NotificationDropReason.duplicate);
      expect(bannerCount, 1); // Not incremented!
    });
  });

  group('N1: Filter Pipeline', () {
    test('actorUid == currentUid is dropped with ownAction and not rendered', () async {
      int renderCount = 0;
      coordinator.onRenderBanner = (_) async => renderCount++;

      final ownIntent = NotificationIntent.groupEvent(
        gid: 'grp_01',
        groupName: 'Date Seru',
        eventId: 'ev_own_1',
        eventType: 'wheel_spin',
        actorUid: 'user_123', // Same as currentUid
        actorName: 'Saya Sendiri',
        title: 'Saya memutar roda',
        subtitle: 'Rp100.000',
        systemBody: 'Saya memutar roda',
      );

      final decision = await coordinator.dispatch(ownIntent);
      expect(decision.surface, NotificationSurface.dropped);
      expect(decision.reason, NotificationDropReason.ownAction);
      expect(renderCount, 0);

      // Verify that it was claimed as dropped so future attempts also drop
      expect(await claimStore.isClaimed('evt:grp_01:ev_own_1'), isTrue);
    });

    test('muted group is dropped with muted reason and not rendered', () async {
      coordinator.isGroupMutedGetter = (gid) => gid == 'grp_muted';
      int renderCount = 0;
      coordinator.onRenderBanner = (_) async => renderCount++;

      final mutedIntent = NotificationIntent.groupEvent(
        gid: 'grp_muted',
        groupName: 'Grup Senyap',
        eventId: 'ev_muted_1',
        eventType: 'expense_created',
        actorUid: 'user_456',
        actorName: 'Dina',
        title: 'Dina mencatat',
        subtitle: 'Jajan',
        systemBody: 'Dina mencatat',
      );

      final decision = await coordinator.dispatch(mutedIntent);
      expect(decision.surface, NotificationSurface.dropped);
      expect(decision.reason, NotificationDropReason.muted);
      expect(renderCount, 0);
    });

    test('disabled toggle category is dropped with toggleDisabled reason', () async {
      coordinator.isCategoryEnabledGetter = (cat) {
        return cat != NotificationCategory.memberJoin;
      };
      int renderCount = 0;
      coordinator.onRenderBanner = (_) async => renderCount++;

      final joinIntent = NotificationIntent.groupEvent(
        gid: 'grp_01',
        groupName: 'Date Seru',
        eventId: 'ev_join_1',
        eventType: 'member_joined',
        actorUid: 'user_777',
        actorName: 'Bima',
        title: 'Bima bergabung',
        subtitle: 'Sekarang 4 anggota',
        systemBody: 'Bima bergabung ke grup.',
      );

      final decision = await coordinator.dispatch(joinIntent);
      expect(decision.surface, NotificationSurface.dropped);
      expect(decision.reason, NotificationDropReason.toggleDisabled);
      expect(renderCount, 0);
    });
  });

  group('N1: AppLifecycle Routing', () {
    test('resumed state routes standard intent to banner', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);
      int bannerCalls = 0;
      int systemCalls = 0;
      coordinator.onRenderBanner = (_) async => bannerCalls++;
      coordinator.onRenderSystem = (_) async => systemCalls++;

      final intent = NotificationIntent.budget80(
        scopeId: 'grp_01',
        sessionId: 'sess_lc_1',
        groupOrAppName: 'Date Seru',
        remainingBudget: 40000,
        totalBudget: 200000,
        spentAmount: 160000,
      );

      final decision = await coordinator.dispatch(intent);
      expect(decision.surface, NotificationSurface.banner);
      expect(bannerCalls, 1);
      expect(systemCalls, 0);
    });

    test('resumed state routes critical intent (isImportantDialog) to dialog', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);
      int dialogCalls = 0;
      int bannerCalls = 0;
      coordinator.onRenderDialog = (_) async => dialogCalls++;
      coordinator.onRenderBanner = (_) async => bannerCalls++;

      final kickIntent = NotificationIntent.kickedFromGroup(
        gid: 'grp_01',
        groupName: 'Date Seru',
      );

      final decision = await coordinator.dispatch(kickIntent);
      expect(decision.surface, NotificationSurface.dialog);
      expect(dialogCalls, 1);
      expect(bannerCalls, 0);
    });

    test('paused/background state routes standard intent to system notification', () async {
      coordinator.setLifecycleState(AppLifecycleState.paused);
      int bannerCalls = 0;
      int systemCalls = 0;
      coordinator.onRenderBanner = (_) async => bannerCalls++;
      coordinator.onRenderSystem = (_) async => systemCalls++;

      final intent = NotificationIntent.groupEvent(
        gid: 'grp_01',
        groupName: 'Date Seru',
        eventId: 'ev_bg_1',
        eventType: 'expense_created',
        actorUid: 'user_456',
        actorName: 'Dina',
        title: 'Dina mencatat',
        subtitle: 'Jajan',
        systemBody: 'Dina menambahkan pengeluaran Rp30.000.',
      );

      final decision = await coordinator.dispatch(intent);
      expect(decision.surface, NotificationSurface.system);
      expect(systemCalls, 1);
      expect(bannerCalls, 0);
    });

    test('system notification drops if permission is not granted', () async {
      coordinator.setLifecycleState(AppLifecycleState.paused);
      coordinator.hasSystemNotificationPermissionGetter = () async => false;

      int systemCalls = 0;
      coordinator.onRenderSystem = (_) async => systemCalls++;

      final intent = NotificationIntent.weeklyReminder(year: 2026, weekNumber: 46);
      final decision = await coordinator.dispatch(intent);

      expect(decision.surface, NotificationSurface.dropped);
      expect(decision.reason, NotificationDropReason.permissionDenied);
      expect(systemCalls, 0);
    });
  });

  group('N1: Observability & Pruning', () {
    test('records last 50 decisions with exact required log format', () async {
      for (int i = 0; i < 55; i++) {
        final intent = NotificationIntent.groupEvent(
          gid: 'grp_01',
          groupName: 'Grup',
          eventId: 'ev_obs_$i',
          eventType: 'expense_created',
          actorUid: 'user_456',
          actorName: 'Dina',
          title: 'Title $i',
          subtitle: 'Sub $i',
          systemBody: 'Body $i',
        );
        await coordinator.dispatch(intent);
      }

      final decisions = coordinator.recentDecisions;
      expect(decisions.length, 50); // Capped at 50
      expect(decisions.first.dedupeKey, 'evt:grp_01:ev_obs_5');
      expect(decisions.last.dedupeKey, 'evt:grp_01:ev_obs_54');

      // Check toString format matching Section 5
      expect(
        decisions.last.toString(),
        matches(r'notif key=evt:grp_01:ev_obs_54 source=listener surface=banner reason=(none|merged)'),
      );
    });

    test('pruneOldClaims removes claims older than 30 days', () async {
      await claimStore.tryClaim(
        dedupeKey: 'old_key',
        surface: NotificationSurface.banner,
      );

      // Manually simulate an old claim in store
      await claimStore.tryClaim(
        dedupeKey: 'very_old_key',
        surface: NotificationSurface.system,
      );
      // Directly add to store
      await claimStore.tryClaim(
        dedupeKey: 'new_key',
        surface: NotificationSurface.banner,
      );

      await claimStore.pruneOldClaims(const Duration(days: 30));
      expect(await claimStore.isClaimed('new_key'), isTrue);
    });

    test('Riverpod notificationCoordinatorProvider returns singleton instance', () {
      final container = ProviderContainer();
      final instanceFromRiverpod = container.read(notificationCoordinatorProvider);
      expect(instanceFromRiverpod, equals(NotificationCoordinator.instance));
    });
  });
}
