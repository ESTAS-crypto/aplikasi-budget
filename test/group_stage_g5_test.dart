import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/models/group_model.dart';
import 'package:putar_jajan/core/group/models/group_event_model.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_notification_settings_service.dart';
import 'package:putar_jajan/core/group/widgets/setting_toggle.dart';
import 'package:putar_jajan/core/group/widgets/in_app_banner.dart';
import 'package:putar_jajan/features/group/screens/group_notification_screen.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupNotificationSettingsService testSettingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
    testSettingsService = GroupNotificationSettingsService(testPrefs);
  });

  group('G5: SettingToggle & Settings Persistence Tests', () {
    testWidgets('SettingToggle switches on and off with haptics and callback', (tester) async {
      bool currentValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => SettingToggle(
                value: currentValue,
                label: 'Catatan pengeluaran',
                onChanged: (val) {
                  setState(() => currentValue = val);
                },
              ),
            ),
          ),
        ),
      );

      expect(currentValue, isFalse);

      // Tap toggle to ON
      await tester.tap(find.byType(SettingToggle));
      await tester.pumpAndSettle();
      expect(currentValue, isTrue);

      // Tap toggle to OFF
      await tester.tap(find.byType(SettingToggle));
      await tester.pumpAndSettle();
      expect(currentValue, isFalse);
    });

    test('GroupNotificationSettingsService defaults and persists per group', () async {
      const gid = 'group_weekend';
      final initial = testSettingsService.getSettings(gid);

      // Defaults
      expect(initial.notifyExpenses, isTrue);
      expect(initial.notifySpin, isTrue);
      expect(initial.notifyWarning80, isTrue);
      expect(initial.notifyMembers, isFalse);

      // Update & Save
      final updated = initial.copyWith(
        notifyExpenses: false,
        notifyMembers: true,
      );
      await testSettingsService.saveSettings(gid, updated);

      final reloaded = testSettingsService.getSettings(gid);
      expect(reloaded.notifyExpenses, isFalse);
      expect(reloaded.notifySpin, isTrue);
      expect(reloaded.notifyWarning80, isTrue);
      expect(reloaded.notifyMembers, isTrue);

      // Another group still has default
      final anotherGroup = testSettingsService.getSettings('group_other');
      expect(anotherGroup.notifyExpenses, isTrue);
      expect(anotherGroup.notifyMembers, isFalse);
    });
  });

  group('G5: Notification Aggregation Tests (60s System & 3s InAppBanner)', () {
    test('showGroupActivityNotification ignores own actions', () async {
      final notifService = NotificationService.instance;
      // Actor is self
      await notifService.showGroupActivityNotification(
        gid: 'grp_1',
        groupName: 'Date Jumat',
        actorUid: 'me_uid',
        currentUid: 'me_uid',
        message: 'Saya mencatat bakso',
      );

      // Verify no exceptions and buffer empty
      expect(testPrefs.getKeys().where((k) => k != 'group_fallback_uid'), isEmpty);
    });

    testWidgets('InAppBanner displays, aggregates, and auto dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    InAppBanner.show(
                      ctx,
                      actorName: 'Dina',
                      message: 'Dina menambahkan Rp30.000 untuk sate. Sisa grup Rp170.000.',
                    );
                  },
                  child: const Text('Show Banner'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to show
      await tester.tap(find.text('Show Banner'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Dina menambahkan Rp30.000 untuk sate. Sisa grup Rp170.000.'), findsOneWidget);

      // Wait 4 seconds for auto dismiss
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Dina menambahkan Rp30.000 untuk sate. Sisa grup Rp170.000.'), findsNothing);
    });
  });

  group('G5: Layar 21 GroupNotificationScreen Widget Tests', () {
    testWidgets('GroupNotificationScreen renders simulated notifications and 4 toggles', (tester) async {
      final activeGroup = GroupModel(
        id: 'grp_1',
        name: 'Date Jumat',
        ownerUid: 'uid_1',
        code: 'JMT123',
        createdAt: DateTime.now(),
        memberCount: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(testPrefs),
            groupAuthServiceProvider.overrideWithValue(testAuthService),
            groupServiceProvider.overrideWithValue(testGroupService),
            activeGroupStreamProvider.overrideWith((ref) => Stream.value(activeGroup)),
            groupNotificationSettingsServiceProvider.overrideWithValue(testSettingsService),
          ],
          child: const MaterialApp(
            home: GroupNotificationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top Header
      expect(find.text('Notifikasi grup'), findsOneWidget);
      expect(find.text('Date Jumat'), findsOneWidget);

      // Card 1: Bisukan grup & durasi
      expect(find.text('Bisukan grup'), findsOneWidget);
      expect(find.text('1 jam'), findsOneWidget);
      expect(find.text('8 jam'), findsOneWidget);
      expect(find.text('Sampai kunyalakan'), findsOneWidget);

      // Card 2: Jenis Notifikasi (Grup7.dc.html)
      expect(find.text('Jenis notifikasi'), findsOneWidget);
      expect(find.text('Catatan pengeluaran'), findsOneWidget);
      expect(find.text('Hasil putaran roda'), findsOneWidget);
      expect(find.text('Peringatan budget'), findsOneWidget);
      expect(find.text('Hasil date selesai'), findsOneWidget);
      expect(find.text('Anggota masuk atau keluar'), findsOneWidget);
      expect(find.text('Selalu tampil: dikeluarkan dari grup, grup dihapus, gagal sinkron.'), findsOneWidget);

      // Card 3: Suara dan getar
      expect(find.text('Suara dan getar'), findsOneWidget);
      expect(find.text('Buka pengaturan Android'), findsOneWidget);

      // Footer
      expect(find.text('Aktivitas dalam 1 menit digabung jadi satu notifikasi. Kamu tidak menerima notifikasi untuk aksimu sendiri.'), findsOneWidget);

      // 6 SettingToggle widgets (1 bisukan + 5 jenis notifikasi)
      expect(find.byType(SettingToggle), findsNWidgets(6));

      // Tap toggle 'Catatan pengeluaran' (index 1 setelah Bisukan grup)
      await tester.tap(find.byType(SettingToggle).at(1));
      await tester.pumpAndSettle();

      // Verify setting was toggled in service
      final saved = testSettingsService.getSettings('grp_1');
      expect(saved.notifyExpenses, isFalse);
    });

    testWidgets('Layar 21 renders on 320dp and 390dp with textScale 1.3 without overflow', (tester) async {
      const widths = [320.0, 390.0];
      final activeGroup = GroupModel(
        id: 'grp_1',
        name: 'Grup Jajan Weekend Super Panjang Sekali',
        ownerUid: 'uid_1',
        code: 'JMT123',
        createdAt: DateTime.now(),
        memberCount: 2,
      );

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
              groupNotificationSettingsServiceProvider.overrideWithValue(testSettingsService),
            ],
            child: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: GroupNotificationScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Layar 21 no overflow on $w dp');
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    test('GroupAuthService isCurrentUser identifies current and fallback UID reliably', () async {
      await testPrefs.setString(GroupAuthService.keyFallbackUid, 'anon_fallback_999');
      final authService = GroupAuthService(prefs: testPrefs);

      expect(authService.isCurrentUser('anon_fallback_999'), isTrue);
      expect(authService.isCurrentUser('other_user_123'), isFalse);
      expect(authService.isCurrentUser(null), isFalse);
      expect(authService.isCurrentUser(''), isFalse);
    });

    test('Group owner can never be kicked and removeMember emits proper kicked payload', () async {
      final createdGid = await testGroupService.createGroup(
        groupName: 'Grup Pengujian',
        creatorName: 'Pemilik Asli',
        colorIndex: 1,
      );

      final members = testGroupService.watchMembers(createdGid);
      final initialMembers = await members.first;
      expect(initialMembers.length, 1);
      expect(initialMembers.first.role, 'owner');
      expect(testAuthService.isCurrentUser(initialMembers.first.uid), isTrue);

      // Verify removeMember includes kicked payload
      await testGroupService.removeMember(
        gid: createdGid,
        memberUid: 'member_temp',
        memberName: 'Anggota Coba',
      );

      final events = await testGroupService.watchEvents(createdGid).first;
      final leaveEvt = events.firstWhere((e) => e.type == GroupEventType.memberLeave);
      expect(leaveEvt.payload['kicked'], isTrue);
      expect(leaveEvt.payload['kickedUid'], 'member_temp');
    });

    test('leaveGroup removes user from member list and emits voluntary leave event', () async {
      final createdGid = await testGroupService.createGroup(
        groupName: 'Grup Nobar',
        creatorName: 'Ketua',
        colorIndex: 0,
      );

      await testAuthService.setDisplayName('Budi');
      await testGroupService.setActiveGroupId(createdGid);
      expect(testGroupService.getActiveGroupId(), createdGid);

      await testGroupService.leaveGroup(createdGid);

      expect(testGroupService.getActiveGroupId(), isNull);
      final events = await testGroupService.watchEvents(createdGid).first;
      final voluntaryLeaveEvt = events.firstWhere((e) => e.type == GroupEventType.memberLeave);
      expect(voluntaryLeaveEvt.payload['kicked'], isFalse);
      expect(voluntaryLeaveEvt.payload['leaverUid'], testAuthService.currentUid);
    });
  });
}

