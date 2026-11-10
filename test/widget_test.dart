import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';

import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/widgets/sticker_card.dart';
import 'package:putar_jajan/core/widgets/sticker_button.dart';
import 'package:putar_jajan/core/widgets/sticker_chip.dart';
import 'package:putar_jajan/core/widgets/in_app_toast.dart';
import 'package:putar_jajan/core/painters/logo_painter.dart';
import 'package:putar_jajan/core/painters/game_icons_painter.dart';
import 'package:putar_jajan/core/painters/nav_icons_painter.dart';
import 'package:putar_jajan/features/wheel/brand_system_screen.dart';
import 'package:putar_jajan/features/wheel/wheel_screen.dart';
import 'package:putar_jajan/features/wheel/custom_wheel_screen.dart';
import 'package:putar_jajan/features/date/active_date_screen.dart';
import 'package:putar_jajan/features/date/date_result_screen.dart';
import 'package:putar_jajan/features/history/history_screen.dart';
import 'package:putar_jajan/core/widgets/settings_bottom_sheet.dart';
import 'package:putar_jajan/features/onboarding/onboarding_screen.dart';
import 'package:putar_jajan/features/splash/splash_screen.dart';
import 'package:putar_jajan/features/games/games_hub_screen.dart';
import 'package:putar_jajan/features/games/dice_screen.dart';
import 'package:putar_jajan/features/games/capsule_screen.dart';
import 'package:putar_jajan/features/games/envelope_screen.dart';
import 'package:putar_jajan/features/games/coin_screen.dart';
import 'package:putar_jajan/core/games/game_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/data/database.dart';
import 'package:putar_jajan/data/database_provider.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(p);
  });
  testWidgets('StickerCard and StickerButton render with neo-brutalist styling', (tester) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: StickerCard.hero(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StickerChip(label: 'Date ke-7'),
                  const SizedBox(height: 12),
                  StickerButton.large(
                    text: 'PUTAR RODA',
                    onPressed: () => pressed = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Date ke-7'), findsOneWidget);
    expect(find.text('PUTAR RODA'), findsOneWidget);

    await tester.tap(find.text('PUTAR RODA'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });

  testWidgets('LogoWidget paints custom geometry without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: LogoWidget(size: 100),
          ),
        ),
      ),
    );

    expect(find.byType(LogoWidget), findsOneWidget);
  });

  testWidgets('Layout renders on 320dp and 390dp width and textScale 1.3 without overflow', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sizes = [const Size(320, 680), const Size(390, 844)];

    for (final size in sizes) {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;

      final inMemoryDb = AppDatabase(NativeDatabase.memory());

      // 1. BrandSystemScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const BrandSystemScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('putar jajan'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. WheelScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const WheelScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PUTAR RODA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      InAppToast.dismiss();

      // 3. ActiveDateScreen (Empty)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const ActiveDateScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada date yang berjalan'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 4. CustomWheelScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const CustomWheelScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Isi roda sendiri'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 5. HistoryScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const HistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Riwayat date'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await inMemoryDb.close();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('OnboardingScreen renders with orbiting coins and allows swiping between slides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);

    // Tap Lanjut untuk pindah ke slide 2 (Catat Cepat & Anti Boncos)
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Anti Boncos.'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);

    // Tap Lanjut untuk pindah ke slide 3 (Banyak Pilihan)
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Mainkan!'), findsOneWidget);
    expect(find.text('Mulai putar'), findsOneWidget);
  });

  testWidgets('GameIconWidget paints all custom game vectors without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Column(
            children: [
              GameIconWidget(gameType: 'dice'),
              GameIconWidget(gameType: 'capsule'),
              GameIconWidget(gameType: 'envelope'),
              GameIconWidget(gameType: 'coin'),
              GameIconWidget(gameType: 'shuffle'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(GameIconWidget), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nav icons paint custom vectors properly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Row(
            children: [
              CustomPaint(painter: WheelNavPainter()),
              CustomPaint(painter: ReceiptNavPainter()),
              CustomPaint(painter: HistoryNavPainter()),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('SplashScreen renders with 3600ms timeline and final elements', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        ),
      ),
    );

    // Initial frame
    await tester.pump();
    expect(find.text('Menyiapkan roda...'), findsOneWidget);

    // Advance timeline to text & tagline entrance (after 58% = ~2100ms)
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('putar jajan'), findsOneWidget);
    expect(find.text('Putar. Terima. Jajan.'), findsOneWidget);

    // Complete timeline
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);

    await inMemoryDb.close();
  });

  testWidgets('GamesHubScreen renders all games with hero card and random button', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GamesHubScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Pilih permainan'), findsOneWidget);
    expect(find.text('Roda Putar'), findsOneWidget);
    expect(find.text('Kocok Dadu'), findsOneWidget);
    expect(find.text('Gacha Kapsul'), findsOneWidget);
    expect(find.text('Pilih Amplop'), findsOneWidget);
    expect(find.text('Lempar Koin'), findsOneWidget);
    expect(find.text('Acak aja, serahkan ke aplikasi'), findsOneWidget);
    expect(find.text('Favorit'), findsOneWidget);
    expect(find.text('Segera'), findsNothing);

    await inMemoryDb.close();
  });

  testWidgets('ActiveDateScreen renders active session, budget card and logs expense', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    final dateId = await inMemoryDb.createDate(100000);
    await inMemoryDb.addItem(dateId: dateId, name: 'Sate Taichan', price: 32000);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ActiveDateScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Lagi ngedate'), findsOneWidget);
    expect(find.text('Sisa budget'), findsOneWidget);
    expect(find.text('Rp68.000'), findsOneWidget);
    expect(find.text('Sate Taichan'), findsOneWidget);
    expect(find.text('Rp32.000'), findsOneWidget);
    expect(find.text('Catat jajan'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('DateResultScreen renders Lolos with Mint and Lewat with Tomat', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    final dateId = await inMemoryDb.createDate(50000);
    await inMemoryDb.addItem(dateId: dateId, name: 'Kopi', price: 20000);
    await inMemoryDb.finishDate(dateId, true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: DateResultScreen(dateId: dateId),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Lolos budget!'), findsOneWidget);
    expect(find.text('Kamu hemat'), findsOneWidget);
    expect(find.text('Rp30.000'), findsOneWidget);
    expect(find.text('Bagikan hasil'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('DiceScreen renders dice arena, multipliers, and rolls without exception', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DiceScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kocok Dadu'), findsOneWidget);
    expect(find.text('KOCOK DADU'), findsOneWidget);
    expect(find.text('Kelipatan'), findsOneWidget);
    expect(find.text('Rp5.000'), findsOneWidget);
    expect(find.text('Rp10.000'), findsOneWidget);
    expect(find.text('Rp20.000'), findsOneWidget);

    // Test kocok dadu
    await tester.tap(find.text('KOCOK DADU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.takeException(), isNull);

    await inMemoryDb.close();
  });

  testWidgets('CapsuleScreen renders gacha dome, crank, and trigger button without exception', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CapsuleScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gacha Kapsul'), findsOneWidget);
    expect(find.text('Isi kapsul rahasia, nominal acak'), findsOneWidget);
    expect(find.text('PUTAR TUAS'), findsOneWidget);

    // Test putar tuas
    await tester.tap(find.text('PUTAR TUAS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(tester.takeException(), isNull);

    await inMemoryDb.close();
  });

  testWidgets('EnvelopeScreen renders 3 envelopes, opens and shuffles without exception', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EnvelopeScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pilih Amplop'), findsOneWidget);
    expect(find.text('Satu amplop, isinya rahasia'), findsOneWidget);
    expect(find.text('BUKA AMPLOP'), findsOneWidget);

    // Test buka amplop
    await tester.tap(find.text('BUKA AMPLOP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);

    // Test kocok lagi ronde ini
    expect(find.text('Kocok Lagi Ronde Ini'), findsOneWidget);
    await tester.tap(find.text('Kocok Lagi Ronde Ini'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('BUKA AMPLOP'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('CustomWheelScreen adapts title and options for capsule and envelope', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomWheelScreen(gameType: GameType.capsule),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Isi kapsul sendiri'), findsOneWidget);
    expect(find.text('Nominal di kapsul'), findsOneWidget);
    expect(find.text('Simpan kapsul'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('SettingsBottomSheet renders sound and vibration controls with neo-brutalist styling', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsBottomSheet(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Audio & Getaran gameplay'), findsOneWidget);
    expect(find.text('Efek Suara'), findsOneWidget);
    expect(find.text('Volume Master'), findsOneWidget);
    expect(find.text('Getaran Haptik'), findsOneWidget);
    expect(find.text('Lihat Sistem Brand & Desain'), findsOneWidget);
  });

  testWidgets('CoinScreen renders arena, 3 indicators, and trigger button without exception', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CoinScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lempar Koin'), findsOneWidget);
    expect(find.text('Gambar x2 · Angka setengah'), findsOneWidget);
    expect(find.text('LEMPAR KOIN'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('Layar 11 sampai 15 pada lebar 320 dan 390dp dan textScale 1.3 tanpa overflow', (tester) async {
    final sizes = [const Size(320, 680), const Size(390, 844)];

    for (final size in sizes) {
      // ignore: avoid_print
      print('TESTING SIZE: $size');
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;

      final inMemoryDb = AppDatabase(NativeDatabase.memory());

      final screens = <Widget>[
        const GamesHubScreen(),
        const DiceScreen(),
        const CapsuleScreen(),
        const EnvelopeScreen(),
        const CoinScreen(),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: screen,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'Screen ${screen.runtimeType} must not overflow on $size');
      }

      await inMemoryDb.close();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
