import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/services/group_notification_settings_service.dart';
import 'package:putar_jajan/core/group/services/group_service.dart';
import 'package:putar_jajan/core/painters/logo_painter.dart';
import 'package:putar_jajan/core/painters/nav_icons_painter.dart';
import 'package:putar_jajan/core/theme/app_colors.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/widgets/in_app_toast.dart';
import 'package:putar_jajan/core/widgets/sticker_button.dart';
import 'package:putar_jajan/core/widgets/sticker_card.dart';
import 'package:putar_jajan/core/widgets/sticker_chip.dart';
import 'package:putar_jajan/data/database.dart';
import 'package:putar_jajan/data/database_provider.dart';
import 'package:putar_jajan/features/date/active_date_screen.dart';
import 'package:putar_jajan/features/date/date_result_screen.dart';
import 'package:putar_jajan/features/games/capsule_screen.dart';
import 'package:putar_jajan/features/games/coin_screen.dart';
import 'package:putar_jajan/features/games/dice_screen.dart';
import 'package:putar_jajan/features/games/envelope_screen.dart';
import 'package:putar_jajan/features/games/games_hub_screen.dart';
import 'package:putar_jajan/features/history/history_screen.dart';
import 'package:putar_jajan/features/onboarding/onboarding_screen.dart';
import 'package:putar_jajan/features/settings/screens/settings_screen.dart';
import 'package:putar_jajan/features/wheel/brand_system_screen.dart';
import 'package:putar_jajan/features/wheel/custom_wheel_screen.dart';
import 'package:putar_jajan/features/wheel/wheel_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const viewport = Size(390, 844);

  Future<void> configureViewport(WidgetTester tester) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
  }

  Widget wrapScreen({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: child,
        ),
      ),
    );
  }

  group('Pasar Malam Golden Baseline (Pre/Post T1)', () {
    late SharedPreferences prefs;

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
    });

    testWidgets('sticker_components golden matches baseline', (tester) async {
      await configureViewport(tester);
      await tester.pumpWidget(
        wrapScreen(
          child: Scaffold(
            backgroundColor: AppColors.cream,
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StickerCard.hero(
                    child: Column(
                      children: [
                        const StickerChip(label: 'Date ke-7'),
                        const SizedBox(height: 12),
                        StickerButton.large(
                          text: 'PUTAR RODA',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  StickerCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const LogoWidget(size: 40),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(painter: WheelNavPainter()),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(painter: ReceiptNavPainter()),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(painter: HistoryNavPainter()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  StickerButton(
                    text: 'Simpan',
                    backgroundColor: AppColors.mint,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/sticker_components.png'),
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('brand_system_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      await tester.pumpWidget(wrapScreen(child: const BrandSystemScreen()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/brand_system.png'),
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('wheel_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const WheelScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      InAppToast.dismiss();
      await tester.pump(const Duration(milliseconds: 50));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/wheel.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('custom_wheel_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const CustomWheelScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/custom_wheel.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('active_date_empty golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const ActiveDateScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/active_date_empty.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('active_date_populated golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      final dateId = await db.createDate(100000);
      await db.addItem(dateId: dateId, name: 'Sate Taichan', price: 32000);
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const ActiveDateScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/active_date_populated.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('date_result_lolos golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      final dateId = await db.createDate(50000);
      await db.addItem(dateId: dateId, name: 'Kopi', price: 20000);
      await db.finishDate(dateId, true);
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: DateResultScreen(dateId: dateId),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/date_result_lolos.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('history_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const HistoryScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/history.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('games_hub_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const GamesHubScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/games_hub.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('dice_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const DiceScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/dice.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('capsule_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const CapsuleScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/capsule.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('envelope_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const EnvelopeScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/envelope.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('coin_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        wrapScreen(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const CoinScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/coin.png'),
      );
      await db.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('onboarding_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      await tester.pumpWidget(wrapScreen(child: const OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/onboarding.png'),
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('settings_screen golden matches baseline', (tester) async {
      await configureViewport(tester);
      final authService = GroupAuthService(auth: null, prefs: prefs);
      final groupService = GroupService(
        firestore: null,
        authService: authService,
        prefs: prefs,
      );
      final notifSettingsService = GroupNotificationSettingsService(prefs);

      await tester.pumpWidget(
        wrapScreen(
          overrides: [
            groupAuthServiceProvider.overrideWithValue(authService),
            groupServiceProvider.overrideWithValue(groupService),
            groupNotificationSettingsServiceProvider
                .overrideWithValue(notifSettingsService),
          ],
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pasar_malam/settings.png'),
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

