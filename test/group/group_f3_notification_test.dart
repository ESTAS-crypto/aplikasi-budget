import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/notifications/coordinator/notification_coordinator.dart';
import 'package:putar_jajan/core/notifications/models/notification_intent.dart';
import 'package:putar_jajan/core/notifications/storage/notified_claim_store.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationCoordinator coordinator;
  late InMemoryNotifiedClaimStore testClaimStore;

  const String hostUid = 'uid_host_raka';
  const String memberUid = 'uid_member_dini';
  const String testGid = 'grp_test_f3';

  final List<NotificationIntent> renderedBanners = [];
  final List<NotificationIntent> renderedSystem = [];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    coordinator = NotificationCoordinator.instance;
    testClaimStore = InMemoryNotifiedClaimStore();
    coordinator.setClaimStore(testClaimStore);
    coordinator.clearDecisionHistory();
    coordinator.resetAggregationBuffers();

    renderedBanners.clear();
    renderedSystem.clear();

    coordinator.onRenderBanner = (intent) async {
      renderedBanners.add(intent);
    };
    coordinator.onRenderSystem = (intent) async {
      renderedSystem.add(intent);
    };

    coordinator.currentUidGetter = () => memberUid;
    coordinator.isGroupMutedGetter = (gid) => false;
    coordinator.isCategoryEnabledGetter = (cat) => true;
  });

  group('F3 Mandatory Tests: Notifikasi Luar Aplikasi, Deduplikasi & Koordinator', () {
    test('1. Generator eventId menghasilkan ID unik deterministik untuk setiap event', () {
      final id1 = GroupService.generateEventId();
      final id2 = GroupService.generateEventId();
      final id3 = GroupService.generateEventId();

      expect(id1, startsWith('evt_'));
      expect(id2, startsWith('evt_'));
      expect(id3, startsWith('evt_'));

      expect(id1, isNot(equals(id2)));
      expect(id2, isNot(equals(id3)));

      final intent1 = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: id1,
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Pengeluaran baru',
        subtitle: 'Bakso 20k',
        systemBody: 'Raka mencatat Bakso Rp20.000',
      );
      final intent2 = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: id2,
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Pengeluaran baru',
        subtitle: 'Es Teh 5k',
        systemBody: 'Raka mencatat Es Teh Rp5.000',
      );

      // dedupeKey unik per event: 'evt:{gid}:{eventId}'
      expect(intent1.dedupeKey, equals('evt:$testGid:$id1'));
      expect(intent2.dedupeKey, equals('evt:$testGid:$id2'));
      expect(intent1.dedupeKey, isNot(equals(intent2.dedupeKey)));
    });

    test('2. Host tidak menerima notifikasi untuk aksinya sendiri (ownAction drop)', () async {
      coordinator.currentUidGetter = () => hostUid;
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      final ownIntent = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: 'evt_own_1',
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka (Host)',
        title: 'Kamu mencatat pengeluaran',
        subtitle: 'Kopi 25k',
        systemBody: 'Kamu mencatat Kopi Rp25.000',
      );

      final decision = await coordinator.dispatch(ownIntent);

      expect(decision.surface, equals(NotificationSurface.dropped));
      expect(decision.reason, equals(NotificationDropReason.ownAction));
      expect(renderedBanners, isEmpty);
      expect(renderedSystem, isEmpty);

      // Verifikasi log keputusan tercatat
      final lastLog = coordinator.recentDecisions.last;
      expect(lastLog.reason, equals(NotificationDropReason.ownAction));
      expect(lastLog.dedupeKey, equals('evt:$testGid:evt_own_1'));
    });

    test('3. HP anggota di latar/tertutup (paused): notifikasi muncul di sistem dan tepat satu', () async {
      coordinator.currentUidGetter = () => memberUid;
      // Simulasikan HP anggota sedang di latar belakang atau ditutup
      coordinator.setLifecycleState(AppLifecycleState.paused);

      final intent = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: 'evt_host_note_1',
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Raka mencatat pengeluaran',
        subtitle: 'Martabak 35k',
        systemBody: 'Raka mencatat Martabak Rp35.000',
      );

      final decision = await coordinator.dispatch(intent);

      expect(decision.surface, equals(NotificationSurface.system));
      expect(decision.reason, equals(NotificationDropReason.none));
      expect(renderedSystem.length, equals(1));
      expect(renderedBanners, isEmpty);
      expect(renderedSystem.first.systemBody, contains('Martabak'));
    });

    test('4. Tiga catatan berurutan dari host menghasilkan ringkasan agregasi dalam 60 detik di sistem', () async {
      coordinator.currentUidGetter = () => memberUid;
      coordinator.setLifecycleState(AppLifecycleState.paused);

      final now = DateTime.now();
      final intent1 = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: 'evt_seq_1',
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Raka mencatat Batagor',
        subtitle: 'Rp15.000',
        systemBody: 'Raka mencatat Batagor Rp15.000',
        createdAt: now,
      );

      final intent2 = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: 'evt_seq_2',
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Raka mencatat Siomay',
        subtitle: 'Rp20.000',
        systemBody: 'Raka mencatat Siomay Rp20.000',
        createdAt: now.add(const Duration(seconds: 5)),
      );

      final intent3 = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: 'evt_seq_3',
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Raka mencatat Es Doger',
        subtitle: 'Rp10.000',
        systemBody: 'Raka mencatat Es Doger Rp10.000',
        createdAt: now.add(const Duration(seconds: 10)),
      );

      // Event 1 terkirim
      final d1 = await coordinator.dispatch(intent1);
      expect(d1.surface, equals(NotificationSurface.system));
      expect(d1.reason, equals(NotificationDropReason.none));

      // Event 2 terkirim (tergabung dalam 60 detik)
      final d2 = await coordinator.dispatch(intent2);
      expect(d2.surface, equals(NotificationSurface.system));
      expect(d2.reason, equals(NotificationDropReason.merged));

      // Event 3 terkirim (tergabung dalam 60 detik)
      final d3 = await coordinator.dispatch(intent3);
      expect(d3.surface, equals(NotificationSurface.system));
      expect(d3.reason, equals(NotificationDropReason.merged));

      // Seluruh 3 event diterima dan sistem di-update
      expect(renderedSystem.length, equals(3));
      final finalNotification = renderedSystem.last;
      expect(finalNotification.systemTitle, equals('3 aktivitas baru di Date Seru'));
      expect(finalNotification.systemBody, contains('dan 2 lainnya'));
    });

    test('5. Buka aplikasi tidak memunculkan banner susulan untuk event yang sudah dinotifikasi sistem', () async {
      coordinator.currentUidGetter = () => memberUid;

      // 1. Notifikasi masuk saat aplikasi di latar
      coordinator.setLifecycleState(AppLifecycleState.paused);
      final intent = NotificationIntent.groupEvent(
        gid: testGid,
        groupName: 'Date Seru',
        eventId: 'evt_bg_delivered',
        eventType: 'expense',
        actorUid: hostUid,
        actorName: 'Raka',
        title: 'Raka mencatat Kopi',
        subtitle: 'Rp18.000',
        systemBody: 'Raka mencatat Kopi Rp18.000',
      );
      final dBackground = await coordinator.dispatch(intent);
      expect(dBackground.surface, equals(NotificationSurface.system));
      expect(renderedSystem.length, equals(1));

      // 2. Pengguna membuka aplikasi (resumed)
      coordinator.setLifecycleState(AppLifecycleState.resumed);

      // Event yang sama dikirimkan lagi oleh realtime stream listener saat connect
      final dForeground = await coordinator.dispatch(intent);

      // Ditolak sebagai duplikat, tidak menampilkan banner susulan!
      expect(dForeground.surface, equals(NotificationSurface.dropped));
      expect(dForeground.reason, equals(NotificationDropReason.duplicate));
      expect(renderedBanners, isEmpty);
    });
  });
}

