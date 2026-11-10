import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putar_jajan/core/notifications/models/notification_intent.dart';
import 'package:putar_jajan/core/notifications/storage/notified_claim_store.dart';
import 'package:putar_jajan/core/notifications/coordinator/notification_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationCoordinator coordinator;
  late InMemoryNotifiedClaimStore claimStore;

  final renderedBanners = <NotificationIntent>[];
  final renderedSystems = <NotificationIntent>[];
  final cancelledGroupIds = <String>[];

  setUp(() {
    coordinator = NotificationCoordinator.instance;
    claimStore = InMemoryNotifiedClaimStore();
    coordinator.setClaimStore(claimStore);
    coordinator.clearDecisionHistory();
    coordinator.resetAggregationBuffers();

    renderedBanners.clear();
    renderedSystems.clear();
    cancelledGroupIds.clear();

    coordinator.currentUidGetter = () => 'me_uid';
    coordinator.isGroupMutedGetter = (_) => false;
    coordinator.isCategoryEnabledGetter = (_) => true;
    coordinator.hasSystemNotificationPermissionGetter = () async => true;

    coordinator.onRenderBanner = (intent) async {
      renderedBanners.add(intent);
    };

    coordinator.onRenderSystem = (intent) async {
      renderedSystems.add(intent);
    };

    coordinator.onCancelSystemGroup = (gid) async {
      cancelledGroupIds.add(gid);
    };
  });

  tearDown(() {
    coordinator.resetAggregationBuffers();
    coordinator.onScreenClosed('grp_1');
  });

  group('N4: Watermark & Old Event Tests (UPDATE 2C Section 2)', () {
    test('Events created more than 5 minutes before app launch are dropped with reason oldEvent', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      final oldCreatedAt = coordinator.appLaunchTime.subtract(const Duration(minutes: 6));
      final intent = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_old_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Pengeluaran Baru',
        subtitle: 'Dina mencatat Rp25.000',
        systemBody: 'Dina menambahkan Rp25.000 untuk kopi.',
        createdAt: oldCreatedAt,
      );

      final decision = await coordinator.dispatch(intent);

      expect(decision.surface, equals(NotificationSurface.dropped));
      expect(decision.reason, equals(NotificationDropReason.oldEvent));
      expect(renderedBanners, isEmpty);
      expect(renderedSystems, isEmpty);
    });

    test('Events older than persisted group watermark are dropped after restart simulation', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      final now = DateTime.now();
      // Simulasikan watermark sudah tersimpan pada jam sekarang
      await claimStore.setLastDeliveredEventAt('grp_1', now);

      // Event dengan timestamp 10 detik lalu (lebih tua dari watermark)
      final pastIntent = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_past_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Pengeluaran Baru',
        subtitle: 'Dina mencatat Rp15.000',
        systemBody: 'Dina mencatat Rp15.000',
        createdAt: now.subtract(const Duration(seconds: 10)),
      );

      final decision = await coordinator.dispatch(pastIntent);

      expect(decision.surface, equals(NotificationSurface.dropped));
      expect(decision.reason, equals(NotificationDropReason.oldEvent));
      expect(renderedBanners, isEmpty);
    });

    test('Fresh event updates group watermark to its createdAt timestamp', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      final freshTime = DateTime.now();
      final freshIntent = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_fresh_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Pengeluaran Baru',
        subtitle: 'Dina mencatat Rp50.000',
        systemBody: 'Dina mencatat Rp50.000',
        createdAt: freshTime,
      );

      final decision = await coordinator.dispatch(freshIntent);

      expect(decision.surface, equals(NotificationSurface.banner));
      expect(decision.reason, equals(NotificationDropReason.none));
      final savedWatermark = await claimStore.getLastDeliveredEventAt('grp_1');
      expect(savedWatermark, equals(freshTime));
    });
  });

  group('N4: 3-Second Banner Aggregation Tests', () {
    test('Two rapid events within 3s merge into single updated banner with count', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      final now = DateTime.now();
      final evt1 = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_rapid_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Dina',
        subtitle: 'Rp20.000 untuk es krim',
        systemBody: 'Dina mencatat Rp20.000',
        createdAt: now,
      );

      final evt2 = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_rapid_2',
        eventType: 'expense',
        actorUid: 'other_uid_2',
        actorName: 'Budi',
        title: 'Budi',
        subtitle: 'Rp30.000 untuk bakso',
        systemBody: 'Budi mencatat Rp30.000',
        createdAt: now.add(const Duration(milliseconds: 500)),
      );

      final dec1 = await coordinator.dispatch(evt1);
      final dec2 = await coordinator.dispatch(evt2);

      // Event pertama berhasil tampil mandiri
      expect(dec1.surface, equals(NotificationSurface.banner));
      expect(dec1.reason, equals(NotificationDropReason.none));

      // Event kedua dalam 3 detik ter-merge dan memperbarui banner
      expect(dec2.surface, equals(NotificationSurface.banner));
      expect(dec2.reason, equals(NotificationDropReason.merged));

      expect(renderedBanners.length, equals(2));
      expect(renderedBanners.last.title, equals('2 aktivitas baru di Date Jumat'));
      expect(renderedBanners.last.subtitle, contains('Budi'));
    });
  });

  group('N4: 60-Second System Aggregation Tests', () {
    test('Multiple background events within 60s merge into single updated notification per group', () async {
      coordinator.setLifecycleState(AppLifecycleState.paused); // Background

      final now = DateTime.now();
      final evt1 = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_bg_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Dina',
        subtitle: 'Rp20.000',
        systemBody: 'Dina menambahkan Rp20.000 untuk jus.',
        createdAt: now,
      );

      final evt2 = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_bg_2',
        eventType: 'expense',
        actorUid: 'other_uid_2',
        actorName: 'Budi',
        title: 'Budi',
        subtitle: 'Rp50.000',
        systemBody: 'Budi menambahkan Rp50.000 untuk sate.',
        createdAt: now.add(const Duration(seconds: 5)),
      );

      final dec1 = await coordinator.dispatch(evt1);
      final dec2 = await coordinator.dispatch(evt2);

      expect(dec1.surface, equals(NotificationSurface.system));
      expect(dec1.reason, equals(NotificationDropReason.none));

      expect(dec2.surface, equals(NotificationSurface.system));
      expect(dec2.reason, equals(NotificationDropReason.merged));

      expect(renderedSystems.length, equals(2));
      expect(renderedSystems.last.systemTitle, equals('2 aktivitas baru di Date Jumat'));
      expect(renderedSystems.last.systemBody, contains('dan 1 lainnya.'));
    });
  });

  group('N4: Offline Return Summary & Screen Cleanup Tests', () {
    test('dispatchBatch aggregates 5 stacked offline events into exactly 1 summary', () async {
      coordinator.setLifecycleState(AppLifecycleState.paused);

      final now = DateTime.now();
      final batch = List.generate(5, (i) {
        return NotificationIntent.groupEvent(
          gid: 'grp_1',
          groupName: 'Date Jumat',
          eventId: 'evt_offline_$i',
          eventType: 'expense',
          actorUid: 'other_uid',
          actorName: 'Dina',
          title: 'Dina',
          subtitle: 'Item $i',
          systemBody: 'Dina belanja item $i',
          createdAt: now.add(Duration(seconds: i)),
        );
      });

      final decisions = await coordinator.dispatchBatch(batch);

      // Semua 5 event individual tercatat ter-merge
      expect(decisions.where((d) => d.reason == NotificationDropReason.merged).length, equals(5));

      // Hanya tepat 1 notifikasi sistem summary yang dirender
      expect(renderedSystems.length, equals(1));
      expect(renderedSystems.first.systemBody, equals('5 aktivitas baru di Date Jumat'));

      // Semua 5 dedupeKey sudah terklaim di store (anti-double)
      for (final it in batch) {
        expect(await claimStore.isClaimed(it.dedupeKey), isTrue);
      }
    });

    test('Opening Activity screen cancels group system notification and suppresses active screen banners', () async {
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      // 1. Pengguna membuka layar aktivitas grp_1
      await coordinator.onActivityScreenOpened('grp_1');

      expect(cancelledGroupIds, contains('grp_1'));
      expect(coordinator.activeScreenGid, equals('grp_1'));

      // 2. Event baru datang saat pengguna sedang di layar aktivitas grp_1
      final liveEvent = NotificationIntent.groupEvent(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        eventId: 'evt_onscreen_1',
        eventType: 'expense',
        actorUid: 'other_uid',
        actorName: 'Dina',
        title: 'Dina',
        subtitle: 'Rp10.000',
        systemBody: 'Dina mencatat Rp10.000',
        createdAt: DateTime.now(),
      );

      final dec = await coordinator.dispatch(liveEvent);

      // Diklaim agar tidak double, namun banner TIDAK ditampilkan karena sudah aktif di layar
      expect(dec.surface, equals(NotificationSurface.banner));
      expect(renderedBanners, isEmpty);
    });
  });
}

