import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_notification_settings_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/group/widgets/in_app_banner.dart';
import 'package:putar_jajan/core/painters/mochi_painter.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/theme/theme_controller.dart';
import 'package:putar_jajan/core/utils/sound_service.dart';
import 'package:putar_jajan/core/widgets/in_app_toast.dart';
import 'package:putar_jajan/data/database.dart';
import 'package:putar_jajan/data/database_provider.dart';
import 'package:putar_jajan/features/date/active_date_screen.dart';
import 'package:putar_jajan/features/date/date_result_screen.dart';
import 'package:putar_jajan/features/games/capsule_screen.dart';
import 'package:putar_jajan/features/games/coin_screen.dart';
import 'package:putar_jajan/features/games/dice_screen.dart';
import 'package:putar_jajan/features/games/envelope_screen.dart';
import 'package:putar_jajan/features/games/games_hub_screen.dart';
import 'package:putar_jajan/features/group/screens/group_date_result_screen.dart';
import 'package:putar_jajan/features/group/screens/join_or_create_group_screen.dart';
import 'package:putar_jajan/features/history/history_screen.dart';
import 'package:putar_jajan/features/notifications/notification_service.dart';
import 'package:putar_jajan/features/onboarding/onboarding_screen.dart';
import 'package:putar_jajan/features/settings/screens/settings_screen.dart';
import 'package:putar_jajan/features/settings/screens/theme_selection_screen.dart';
import 'package:putar_jajan/features/wheel/brand_system_screen.dart';
import 'package:putar_jajan/features/wheel/custom_wheel_screen.dart';
import 'package:putar_jajan/features/wheel/wheel_screen.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('T5: Unit Uji Peta Copy, Kontras Kucing Manis & Audit Ikon Bawaan', () {
    test('Peta copy di semua PutarTheme tidak kehilangan satu pun kunci wajib', () {
      for (final theme in PutarTheme.allThemes) {
        for (final key in PutarCopyKeys.requiredKeys) {
          expect(
            theme.copy.containsKey(key),
            isTrue,
            reason: 'Tema ${theme.id} kehilangan kunci copy "$key"',
          );
          expect(
            theme.copy[key]?.trim().isNotEmpty,
            isTrue,
            reason: 'Tema ${theme.id} memiliki nilai kosong untuk "$key"',
          );
        }
      }
    });

    test('Rasio kontras warna Kucing Manis memenuhi WCAG AA (>= 4.5:1)', () {
      const k = PutarTheme.kucingManis;
      final pairs = <String, (Color, Color)>{
        'ink di Sakura (#FF8FB1)': (k.ink, k.primary),
        'ink di Mentega (#FFE27A)': (k.ink, k.secondary),
        'ink di Mint (#9BE8D0)': (k.ink, k.success),
        'ink di latar (#FFF0F5)': (k.ink, k.bg),
        'ink di Lavender (#CDB4FF)': (k.ink, k.accentPurple),
        'textSecondary di latar (#FFF0F5)': (k.textSecondary, k.bg),
        'textSecondary di kartu (#FFFFFF)': (k.textSecondary, k.surface),
      };

      for (final entry in pairs.entries) {
        final ratio = _contrastRatio(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Kontras ${entry.key} hanya ${ratio.toStringAsFixed(2)}',
        );
      }
    });

    test('Seluruh layar & widget user-facing bebas dari Material Icons.*', () {
      final violations = <String>[];
      final root = Directory('lib');
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized.endsWith('notification_debug_screen.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('Icons.')) {
            violations.add('$normalized:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Masih ditemukan ikon Material bawaan:\n${violations.join('\n')}',
      );
    });
  });

  group('T5: Layar Pilih Tema (Layar 22), Ganti Tema Live & TalkBack', () {
    late SharedPreferences prefs;
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
        kThemePreferenceKey: PutarTheme.pasarMalam.id,
        'group_display_name': 'Kamu',
        'pj_friday_reminder_enabled': true,
      });
      prefs = await SharedPreferences.getInstance();
      setGlobalSharedPreferences(prefs);
      await SoundService.instance.setSoundPack(SoundService.defaultSoundPackId);
      NotificationService.instance.resetThemeForTest();
    });

    tearDown(() async {
      InAppToast.dismiss();
      InAppBanner.dismiss();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(tzChannel, null);
      await SoundService.instance.setSoundPack(SoundService.defaultSoundPackId);
      NotificationService.instance.resetThemeForTest();
    });

    Widget buildApp({required Widget home}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialThemeProvider.overrideWithValue(PutarTheme.pasarMalam),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final theme = ref.watch(themeControllerProvider);
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildTheme(theme),
              home: home,
            );
          },
        ),
      );
    }

    testWidgets(
      'ThemeSelectionScreen menampilkan kartu dinamis sesuai PutarTheme.allThemes & mengganti tema live',
      (tester) async {
        await tester.pumpWidget(buildApp(home: const ThemeSelectionScreen()));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Tema aplikasi'), findsOneWidget);
        expect(find.text('Ganti suasana. Semua fitur tetap sama.'), findsOneWidget);
        expect(find.text('Yang ikut berubah'), findsOneWidget);
        expect(find.text('Warna dan roda'), findsOneWidget);
        expect(find.text('Maskot tema'), findsOneWidget);
        expect(find.text('Logo dan ikon'), findsOneWidget);
        expect(find.text('Splash screen'), findsOneWidget);

        for (final option in PutarTheme.allThemes) {
          expect(find.text(option.displayName), findsOneWidget);
        }

        // Awalnya Pasar Malam aktif & tombol berlabel Pakai Pasar Malam
        expect(find.text('Dipakai'), findsOneWidget);
        expect(find.text('Baru'), findsOneWidget);
        expect(find.text('Pakai Pasar Malam'), findsOneWidget);

        // Pilih kartu Kucing Manis -> label tombol berubah jadi "Pakai Kucing Manis"
        await tester.tap(find.text('Kucing Manis'));
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.text('Pakai Kucing Manis'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('theme_selected_check_kucing_manis')),
          findsOneWidget,
        );

        // Tekan "Pakai Kucing Manis" -> berlaku live tanpa restart, tersimpan & ganti sound pack
        await tester.tap(
          find.byKey(const ValueKey('apply_selected_theme_button')),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          prefs.getString(kThemePreferenceKey),
          equals(PutarTheme.kucingManis.id),
        );
        expect(SoundService.instance.activeSoundPack, equals('kucing'));
        expect(
          NotificationService.instance.activeTheme.id,
          equals(PutarTheme.kucingManis.id),
        );
        expect(find.text('Dipakai'), findsOneWidget);
        expect(
          find.text('Tema Kucing Manis sekarang dipakai.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('TalkBack semantics pada ThemeSelectionScreen dan MochiWidget lengkap', (tester) async {
      await tester.pumpWidget(
        buildApp(
          home: const ThemeSelectionScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel('Kembali'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Tema Pasar Malam.*sedang dipakai$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Tema Kucing Manis.*$')),
        findsOneWidget,
      );

      // Re-verifikasi Mochi semantics: interaktif dibaca "Mochi", dekoratif di-exclude
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(PutarTheme.kucingManis),
          home: const Scaffold(
            body: Column(
              children: [
                MochiWidget(size: 80, enableTap: true),
                MochiWidget(size: 64, decorative: true, enableTap: false),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Mochi'), findsOneWidget);
    });
  });

  group('T5: Golden & Anti-Overflow Dua Tema (320dp & 390dp, textScale 1.3)', () {
    late SharedPreferences prefs;
    late GroupAuthService authService;
    late GroupService groupService;
    late GroupNotificationSettingsService notifSettingsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'group_display_name': 'Kamu',
        'pj_sound_enabled': true,
        'pj_vibration_enabled': true,
        'pj_sound_volume': 0.8,
        'pj_friday_reminder_enabled': true,
      });
      prefs = await SharedPreferences.getInstance();
      setGlobalSharedPreferences(prefs);
      authService = GroupAuthService(auth: null, prefs: prefs);
      groupService = GroupService(
        firestore: null,
        authService: authService,
        prefs: prefs,
      );
      notifSettingsService = GroupNotificationSettingsService(prefs);
    });

    Widget wrapThemed({
      required PutarTheme theme,
      required double width,
      required Widget child,
      Key? scopeKey,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        key: scopeKey,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialThemeProvider.overrideWithValue(theme),
          groupAuthServiceProvider.overrideWithValue(authService),
          groupServiceProvider.overrideWithValue(groupService),
          groupNotificationSettingsServiceProvider
              .overrideWithValue(notifSettingsService),
          ...overrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildTheme(theme),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: const TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: child,
          ),
        ),
      );
    }

    Future<void> verifyDualThemeScreen(
      WidgetTester tester, {
      required String name,
      required Widget Function() builder,
      bool needsDb = true,
      bool captureGoldens = true,
    }) async {
      for (final theme in PutarTheme.allThemes) {
        for (final width in const [320.0, 390.0]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;

          final db = needsDb ? AppDatabase(NativeDatabase.memory()) : null;
          await tester.pumpWidget(
            wrapThemed(
              scopeKey: ValueKey('scope_${name}_${theme.id}_${width.toInt()}'),
              theme: theme,
              width: width,
              overrides: [
                if (db != null) databaseProvider.overrideWithValue(db),
              ],
              child: builder(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          InAppToast.dismiss();
          InAppBanner.dismiss();
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow/error pada $name (${theme.id}, ${width.toInt()}dp, 1.3x)',
          );

          if (captureGoldens) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/t5_matrix/${name}_${theme.id}_${width.toInt()}.png',
              ),
            );
          }

          if (db != null) {
            await db.close();
          }
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }
    }

    testWidgets('theme_selection dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'theme_selection',
        builder: () => const ThemeSelectionScreen(),
        needsDb: false,
      );
    });

    testWidgets('settings dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'settings',
        builder: () => const SettingsScreen(),
        needsDb: false,
      );
    });

    testWidgets('wheel_screen dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'wheel',
        builder: () => const WheelScreen(),
      );
    });

    testWidgets('active_date dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'active_date',
        builder: () => const ActiveDateScreen(),
      );
    });

    testWidgets('games_hub dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'games_hub',
        builder: () => const GamesHubScreen(),
      );
    });

    testWidgets('history dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'history',
        builder: () => const HistoryScreen(),
      );
    });

    testWidgets('brand_system dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'brand_system',
        builder: () => const BrandSystemScreen(),
        needsDb: false,
      );
    });

    testWidgets('onboarding dual-theme 320/390 golden & 1.3x overflow-free', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'onboarding',
        builder: () => const OnboardingScreen(),
        needsDb: false,
      );
    });

    testWidgets('layar tambahan (permainan, editor, hasil, grup) bebas overflow di kedua tema', (tester) async {
      await verifyDualThemeScreen(
        tester,
        name: 'dice',
        builder: () => const DiceScreen(),
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'capsule',
        builder: () => const CapsuleScreen(),
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'envelope',
        builder: () => const EnvelopeScreen(),
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'coin',
        builder: () => const CoinScreen(),
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'custom_wheel',
        builder: () => const CustomWheelScreen(),
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'date_result_lewat',
        builder: () => const DateResultScreen(dateId: 9999),
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'join_create_group',
        builder: () => const JoinOrCreateGroupScreen(),
        needsDb: false,
        captureGoldens: false,
      );
      await verifyDualThemeScreen(
        tester,
        name: 'group_date_result_lolos',
        builder: () => const GroupDateResultScreen(
          groupName: 'Kucing Date',
          budget: 150000,
          totalSpent: 100000,
          itemCount: 3,
        ),
        needsDb: false,
        captureGoldens: false,
      );
    });
  });
}
