import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/widgets/in_app_banner.dart';

import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/theme/theme_controller.dart';
import 'package:putar_jajan/core/utils/sound_service.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/services/group_notification_settings_service.dart';
import 'package:putar_jajan/core/group/widgets/setting_toggle.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';
import 'package:putar_jajan/features/settings/screens/settings_screen.dart';
import 'package:putar_jajan/features/settings/screens/theme_selection_screen.dart';
import 'package:putar_jajan/features/settings/widgets/bookmark_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;
  late GroupAuthService testAuthService;
  late GroupService testGroupService;
  late GroupNotificationSettingsService testSettingsService;

  const notifChannel = MethodChannel('dexterous.com/flutter/local_notifications');
  const tzChannel = MethodChannel('flutter_timezone');

  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
        case 'canScheduleExactNotifications':
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
      if (call.method == 'getLocalTimezone') return 'Asia/Jakarta';
      return null;
    });
    SharedPreferences.setMockInitialValues({
      'group_display_name': 'Evan Testing',
      'pj_sound_enabled': true,
      'pj_vibration_enabled': true,
      'pj_sound_volume': 0.8,
      'pj_friday_reminder_enabled': true,
    });
    testPrefs = await SharedPreferences.getInstance();
    testAuthService = GroupAuthService(auth: null, prefs: testPrefs);
    testGroupService = GroupService(
      firestore: null,
      authService: testAuthService,
      prefs: testPrefs,
    );
    testSettingsService = GroupNotificationSettingsService(testPrefs);
    await SoundService.instance.setSoundPack(SoundService.defaultSoundPackId);
    NotificationService.instance.resetThemeForTest();
  });

  tearDown(() async {
    InAppBanner.dismiss();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tzChannel, null);
    await SoundService.instance.setSoundPack(SoundService.defaultSoundPackId);
    NotificationService.instance.resetThemeForTest();
  });

  Widget createSettingsTestWidget({int initialTab = 0}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(testPrefs),
        initialThemeProvider.overrideWithValue(PutarTheme.pasarMalam),
        groupAuthServiceProvider.overrideWithValue(testAuthService),
        groupServiceProvider.overrideWithValue(testGroupService),
        groupNotificationSettingsServiceProvider.overrideWithValue(testSettingsService),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final activeTheme = ref.watch(themeControllerProvider);
          return MaterialApp(
            theme: AppTheme.buildTheme(activeTheme),
            home: SettingsScreen(initialTab: initialTab),
          );
        },
      ),
    );
  }

  group('Unified SettingsScreen Tests (Setelan1.dc.html)', () {
    testWidgets('Renders header and BookmarkTabBar tabs correctly', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.byType(BookmarkTabBar), findsOneWidget);
      expect(find.text('Aplikasi'), findsOneWidget);
      expect(find.text('Grup'), findsOneWidget);

      // Section Cards in Aplikasi Tab
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Dipakai: Pasar Malam'), findsOneWidget);
      expect(find.text('Pasar Malam'), findsOneWidget);
      expect(find.text('Kucing Manis'), findsOneWidget);
      expect(find.text('Lihat semua tema'), findsOneWidget);

      expect(find.text('Suara dan getar'), findsOneWidget);
      expect(find.text('Suara'), findsOneWidget);
      expect(find.text('Getar'), findsOneWidget);
      expect(find.text('Volume efek'), findsOneWidget);

      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Pengingat Jumat malam'), findsOneWidget);
      expect(find.text('Notifikasi grup'), findsOneWidget);
      expect(find.text('Izin notifikasi'), findsOneWidget);

      expect(find.text('Nama tampilan'), findsOneWidget);
      expect(find.text('Evan Testing'), findsOneWidget);
      expect(find.text('Ubah'), findsOneWidget);

      expect(find.text('Putar Jajan v1.0'), findsOneWidget);
    });

    testWidgets('Tapping Kucing Manis switches theme live and persists selection', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      // Tap "Kucing Manis"
      await tester.tap(find.text('Kucing Manis'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dipakai: Kucing Manis'), findsOneWidget);
      expect(find.text('Tema Diganti'), findsOneWidget);
      expect(
        testPrefs.getString(kThemePreferenceKey),
        equals(PutarTheme.kucingManis.id),
      );
      expect(SoundService.instance.activeSoundPack, equals('kucing'));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Tapping Lihat semua tema opens ThemeSelectionScreen', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      // Tap "Lihat semua tema"
      await tester.tap(find.text('Lihat semua tema'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ThemeSelectionScreen), findsOneWidget);
      expect(find.text('Tema aplikasi'), findsOneWidget);
      expect(find.text('Yang ikut berubah'), findsOneWidget);
    });

    testWidgets('Suara and Getar toggles update soundSettingsProvider state', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      final toggles = find.byType(SettingToggle);
      expect(toggles, findsAtLeastNWidgets(2));

      // Toggle Suara off
      await tester.tap(toggles.at(0));
      await tester.pumpAndSettle();

      expect(SoundService.instance.isSoundEnabled, isFalse);

      // Toggle Suara on
      await tester.tap(toggles.at(0));
      await tester.pumpAndSettle();

      expect(SoundService.instance.isSoundEnabled, isTrue);

      // Toggle Getar off
      await tester.tap(toggles.at(1));
      await tester.pumpAndSettle();

      expect(SoundService.instance.isVibrationEnabled, isFalse);

      // Toggle Getar on
      await tester.tap(toggles.at(1));
      await tester.pumpAndSettle();

      expect(SoundService.instance.isVibrationEnabled, isTrue);
    });

    testWidgets('Editing display name via Ubah dialog persists new name', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ubah'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Evan Testing'), findsOneWidget);

      // Tap Ubah
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Ubah Nama Tampilan'), findsOneWidget);

      // Enter new name
      await tester.enterText(find.byType(TextField), 'Rian Baru');
      await tester.pumpAndSettle();

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Rian Baru'), findsOneWidget);
      expect(testAuthService.displayName, equals('Rian Baru'));
    });

    testWidgets('Switching between Aplikasi and Grup tabs via BookmarkTabBar works smoothly', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      // In Aplikasi tab initially
      expect(find.text('Tema'), findsOneWidget);

      // Tap Grup tab
      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      // Now in Grup tab (empty group state or group options)
      expect(find.text('Belum Bergabung ke Grup'), findsOneWidget);
      expect(find.text('Gabung atau Buat Grup'), findsOneWidget);

      // Tap back to Aplikasi tab
      await tester.tap(find.text('Aplikasi'));
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsOneWidget);
    });

    testWidgets('Tapping Notifikasi grup row automatically slides to Grup tab', (tester) async {
      await tester.pumpWidget(createSettingsTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Notifikasi grup'),
        50.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Notifikasi grup row
      await tester.tap(find.text('Notifikasi grup'));
      await tester.pumpAndSettle();

      // Slides to Grup tab
      expect(find.text('Belum Bergabung ke Grup'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders on 320dp and 390dp with textScale 1.3 without overflow', (tester) async {
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width * 2.0, 844.0 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              textScaler: const TextScaler.linear(1.3),
              size: Size(width, 844.0),
            ),
            child: createSettingsTestWidget(),
          ),
        );
        await tester.pumpAndSettle();

        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('OVERFLOW EXC: $exc');
        }
        expect(exc, isNull);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
