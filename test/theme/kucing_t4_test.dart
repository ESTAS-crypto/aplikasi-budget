import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/painters/mochi_painter.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/theme/theme_controller.dart';
import 'package:putar_jajan/core/utils/sound_service.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notifChannel = MethodChannel('dexterous.com/flutter/local_notifications');
  const tzChannel = MethodChannel('flutter_timezone');

  final List<MethodCall> recordedNotifCalls = [];

  setUp(() async {
    recordedNotifCalls.clear();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'pj_friday_reminder_enabled': true,
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, (MethodCall call) async {
      recordedNotifCalls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'createNotificationChannel':
          return null;
        case 'canScheduleExactNotifications':
          return true;
        case 'cancel':
        case 'zonedSchedule':
        case 'show':
          return true;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tzChannel, (MethodCall call) async {
      if (call.method == 'getLocalTimezone') {
        return 'Asia/Jakarta';
      }
      return null;
    });

    NotificationService.instance.resetThemeForTest();
    await SoundService.instance.setSoundPack(SoundService.defaultSoundPackId);
    SoundService.instance.resetPurrThrottle();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tzChannel, null);
    NotificationService.instance.resetThemeForTest();
    await SoundService.instance.setSoundPack(SoundService.defaultSoundPackId);
    SoundService.instance.resetPurrThrottle();
  });

  group('T4: Aset Paket Audio & Sumber Daya Android', () {
    test('Kedua paket audio memiliki seluruh 23 SFX resmi + 4 suara ekstra Kucing', () {
      for (final sfx in Sfx.values) {
        final pmFile = File('assets/${sfx.assetPathForPack('pasar_malam')}');
        final ktFile = File('assets/${sfx.assetPathForPack('kucing')}');
        expect(
          pmFile.existsSync(),
          isTrue,
          reason: 'Hilang di pasar_malam: ${pmFile.path}',
        );
        expect(
          pmFile.lengthSync(),
          greaterThan(0),
          reason: 'Kosong di pasar_malam: ${pmFile.path}',
        );
        expect(
          ktFile.existsSync(),
          isTrue,
          reason: 'Hilang di kucing: ${ktFile.path}',
        );
        expect(
          ktFile.lengthSync(),
          greaterThan(0),
          reason: 'Kosong di kucing: ${ktFile.path}',
        );
      }

      for (final extra in const [
        'meow_1.wav',
        'meow_2.wav',
        'meow_3.wav',
        'purr.wav',
      ]) {
        final file = File('assets/audio/kucing/$extra');
        expect(file.existsSync(), isTrue, reason: 'Hilang ekstra: ${file.path}');
        expect(file.lengthSync(), greaterThan(0));
      }
    });

    test('Android res/raw suara notifikasi Kucing & ic_stat_notification_kucing tersedia', () {
      for (final rawFile in const [
        'android/app/src/main/res/raw/notif_warning.wav',
        'android/app/src/main/res/raw/notif_reminder.wav',
        'android/app/src/main/res/raw/notif_warning_kucing.wav',
        'android/app/src/main/res/raw/notif_reminder_kucing.wav',
      ]) {
        final file = File(rawFile);
        expect(file.existsSync(), isTrue, reason: 'Missing raw: $rawFile');
        expect(file.lengthSync(), greaterThan(0));
      }

      final statIcon = File(
        'android/app/src/main/res/drawable/ic_stat_notification_kucing.xml',
      );
      expect(statIcon.existsSync(), isTrue);
      final xml = statIcon.readAsStringSync();
      expect(xml.contains('<vector'), isTrue);
      expect(xml.contains('#FFFFFFFF'), isTrue);
    });
  });

  group('T4: SoundService Paket Suara Per Tema & Purr', () {
    test('Sfx.assetPathForPack dan SoundService.setSoundPack berpindah bersih', () async {
      expect(
        Sfx.splashJingle.assetPathForPack('pasar_malam'),
        equals('audio/pasar_malam/splash_jingle.wav'),
      );
      expect(
        Sfx.splashJingle.assetPathForPack('kucing'),
        equals('audio/kucing/splash_jingle.wav'),
      );
      expect(
        Sfx.splashJingle.assetPathForPack('tidak_dikenal'),
        equals('audio/pasar_malam/splash_jingle.wav'),
      );

      final svc = SoundService.instance;
      expect(svc.activeSoundPack, equals('pasar_malam'));
      expect(svc.resolveAssetPath(Sfx.wheelLand), equals('audio/pasar_malam/wheel_land.wav'));

      await svc.setSoundPack('kucing');
      expect(svc.activeSoundPack, equals('kucing'));
      expect(svc.resolveAssetPath(Sfx.wheelLand), equals('audio/kucing/wheel_land.wav'));

      await svc.setSoundPack('pasar_malam');
      expect(svc.activeSoundPack, equals('pasar_malam'));
      expect(svc.resolveAssetPath(Sfx.wheelLand), equals('audio/pasar_malam/wheel_land.wav'));
    });

    test('SoundService.playPurr melakukan throttle ketat 800ms', () {
      final svc = SoundService.instance;
      svc.resetPurrThrottle();
      final t0 = DateTime(2026, 11, 14, 18, 0, 0);

      expect(svc.playPurr(now: t0, haptic: false), isTrue);
      expect(svc.purrTriggerCount, equals(1));

      expect(
        svc.playPurr(now: t0.add(const Duration(milliseconds: 400)), haptic: false),
        isFalse,
      );
      expect(svc.purrTriggerCount, equals(1));

      expect(
        svc.playPurr(now: t0.add(const Duration(milliseconds: 799)), haptic: false),
        isFalse,
      );
      expect(svc.purrTriggerCount, equals(1));

      expect(
        svc.playPurr(now: t0.add(const Duration(milliseconds: 800)), haptic: false),
        isTrue,
      );
      expect(svc.purrTriggerCount, equals(2));
    });

    testWidgets('MochiWidget long-press memicu SoundService.playPurr', (tester) async {
      SoundService.instance.resetPurrThrottle();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(PutarTheme.kucingManis),
          home: const Scaffold(
            body: Center(
              child: MochiWidget(
                size: 120,
                enableTap: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(MochiWidget));
      await tester.pump(const Duration(milliseconds: 300));
      expect(SoundService.instance.purrTriggerCount, equals(1));
    });
  });

  group('T4: NotificationService Channel Per Tema & Rescheduling', () {
    test('channelConfigForTheme menjaga channel Pasar Malam & menyediakan channel Kucing unik', () {
      final pmIds = <String>{};
      final ktIds = <String>{};

      for (final slot in NotificationChannelSlot.values) {
        final pmCfg =
            NotificationService.channelConfigForTheme(PutarTheme.pasarMalam, slot);
        final ktCfg =
            NotificationService.channelConfigForTheme(PutarTheme.kucingManis, slot);

        pmIds.add(pmCfg.channelId);
        ktIds.add(ktCfg.channelId);

        expect(pmCfg.smallIcon, equals(NotificationService.smallIconDefault));
        expect(ktCfg.smallIcon, equals(NotificationService.smallIconKucing));
        expect(pmCfg.accentColor, equals(PutarTheme.kPasarMalamTomat));
        expect(ktCfg.accentColor, equals(PutarTheme.kucingManis.primary));
        expect(ktCfg.channelId, isNot(equals(pmCfg.channelId)));

        if (pmCfg.soundResource != null) {
          expect(ktCfg.soundResource, equals('${pmCfg.soundResource}_kucing'));
        } else {
          expect(ktCfg.soundResource, isNull);
        }
      }

      expect(pmIds.length, equals(5));
      expect(ktIds.length, equals(5));
      expect(
        NotificationService.channelConfigForTheme(
          PutarTheme.pasarMalam,
          NotificationChannelSlot.warning,
        ).channelId,
        equals(NotificationService.channelWarningId),
      );
      expect(
        NotificationService.channelConfigForTheme(
          PutarTheme.kucingManis,
          NotificationChannelSlot.warning,
        ).channelId,
        equals(NotificationService.channelWarningKucingId),
      );
    });

    test('initialize mendaftarkan 10 channel tema & applyTheme menjadwalkan ulang Jumat', () async {
      final service = NotificationService.instance;
      await service.initialize(initialTheme: PutarTheme.pasarMalam);

      final createdChannels = recordedNotifCalls
          .where((c) => c.method == 'createNotificationChannel')
          .map((c) => Map<String, dynamic>.from(c.arguments as Map))
          .toList();

      expect(createdChannels.length, equals(10));
      final createdIds = createdChannels.map((m) => m['id'] as String).toSet();
      expect(createdIds.contains(NotificationService.channelWarningId), isTrue);
      expect(createdIds.contains(NotificationService.channelReminderId), isTrue);
      expect(createdIds.contains(NotificationService.channelWarningKucingId), isTrue);
      expect(createdIds.contains(NotificationService.channelReminderKucingId), isTrue);

      recordedNotifCalls.clear();
      final prefs = await SharedPreferences.getInstance();

      await service.applyTheme(PutarTheme.kucingManis, prefs: prefs);
      expect(service.activeTheme.id, equals(PutarTheme.kucingManis.id));
      expect(service.applyThemeRescheduleCount, equals(1));

      final scheduleCalls = recordedNotifCalls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduleCalls.length, equals(1));
      final scheduledArgs = Map<String, dynamic>.from(scheduleCalls.first.arguments as Map);
      final platformSpecifics = Map<String, dynamic>.from(
        scheduledArgs['platformSpecifics'] as Map,
      );
      expect(
        platformSpecifics['channelId'],
        equals(NotificationService.channelReminderKucingId),
      );
      expect(
        platformSpecifics['icon'],
        equals(NotificationService.smallIconKucing),
      );
      expect(platformSpecifics['sound'], equals('notif_reminder_kucing'));
    });

    test('applyTheme tidak menjadwalkan ulang jika pengingat Jumat dimatikan', () async {
      SharedPreferences.setMockInitialValues({
        'pj_friday_reminder_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = NotificationService.instance;
      await service.initialize(initialTheme: PutarTheme.pasarMalam);

      recordedNotifCalls.clear();
      await service.applyTheme(PutarTheme.kucingManis, prefs: prefs);

      expect(service.activeTheme.id, equals(PutarTheme.kucingManis.id));
      expect(service.applyThemeRescheduleCount, equals(0));
      expect(
        recordedNotifCalls.where((c) => c.method == 'zonedSchedule'),
        isEmpty,
      );
    });

    test('themeControllerProvider memicu perpindahan soundPack dan channel notifikasi', () async {
      final prefs = await SharedPreferences.getInstance();
      await NotificationService.instance.initialize(
        initialTheme: PutarTheme.pasarMalam,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialThemeProvider.overrideWithValue(PutarTheme.pasarMalam),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeControllerProvider).id, equals(PutarTheme.pasarMalam.id));
      expect(SoundService.instance.activeSoundPack, equals('pasar_malam'));

      await container
          .read(themeControllerProvider.notifier)
          .setTheme(PutarTheme.kucingManis);

      expect(container.read(themeControllerProvider).id, equals(PutarTheme.kucingManis.id));
      expect(SoundService.instance.activeSoundPack, equals('kucing'));
      expect(
        NotificationService.instance.activeTheme.id,
        equals(PutarTheme.kucingManis.id),
      );

      await container
          .read(themeControllerProvider.notifier)
          .setTheme(PutarTheme.pasarMalam);

      expect(SoundService.instance.activeSoundPack, equals('pasar_malam'));
      expect(
        NotificationService.instance.activeTheme.id,
        equals(PutarTheme.pasarMalam.id),
      );
    });
  });
}
