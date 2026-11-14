import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/painters/confetti_painter.dart';
import 'package:putar_jajan/core/painters/logo_painter.dart';
import 'package:putar_jajan/core/painters/mochi_painter.dart';
import 'package:putar_jajan/core/painters/paw_painter.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/utils/sound_service.dart';
import 'package:putar_jajan/core/widgets/in_app_toast.dart';
import 'package:putar_jajan/data/database.dart';
import 'package:putar_jajan/data/database_provider.dart';
import 'package:putar_jajan/features/date/active_date_screen.dart';
import 'package:putar_jajan/features/date/date_result_screen.dart';
import 'package:putar_jajan/features/group/screens/group_date_result_screen.dart';
import 'package:putar_jajan/features/onboarding/onboarding_screen.dart';
import 'package:putar_jajan/features/splash/splash_screen.dart';
import 'package:putar_jajan/features/wheel/wheel_painter.dart';
import 'package:putar_jajan/features/wheel/wheel_screen.dart';

ui.Picture _recordPaint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  return recorder.endRecording();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(prefs);
    SoundService.instance.resetMeowThrottle();
  });

  group('Stage T3 - MochiPainter, animasi, aksesibilitas & audio meong', () {
    test('kelima ekspresi MochiPainter menggambar tanpa error', () {
      for (final expr in MochiExpression.values) {
        final painter = MochiPainter.fromTheme(
          PutarTheme.kucingManis,
          expression: expr,
          blinkScaleY: expr == MochiExpression.normal ? 0.1 : 1.0,
          earTwitchAngle: 0.14,
          bellSwingRadians: 0.2,
        );
        final pic = _recordPaint(painter, const Size(120, 120));
        pic.dispose();
      }

      const normalPainter = MochiPainter(expression: MochiExpression.normal);
      expect(
        normalPainter.shouldRepaint(
          const MochiPainter(expression: MochiExpression.happy),
        ),
        isTrue,
      );
      expect(
        normalPainter.shouldRepaint(
          const MochiPainter(
            expression: MochiExpression.normal,
            blinkScaleY: 0.12,
          ),
        ),
        isTrue,
      );
      expect(
        normalPainter.shouldRepaint(
          const MochiPainter(
            expression: MochiExpression.normal,
            earTwitchAngle: 0.12,
          ),
        ),
        isTrue,
      );
      expect(
        normalPainter.shouldRepaint(const MochiPainter()),
        isFalse,
      );
    });

    test('SoundService.playMeow melakukan throttle ketat 600ms', () {
      final svc = SoundService.instance..resetMeowThrottle();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);

      expect(svc.playMeow(now: t0, haptic: false), isTrue);
      expect(svc.meowTriggerCount, 1);

      expect(
        svc.playMeow(now: t0.add(const Duration(milliseconds: 250)), haptic: false),
        isFalse,
      );
      expect(svc.meowTriggerCount, 1);

      expect(
        svc.playMeow(now: t0.add(const Duration(milliseconds: 599)), haptic: false),
        isFalse,
      );
      expect(svc.meowTriggerCount, 1);

      expect(
        svc.playMeow(now: t0.add(const Duration(milliseconds: 600)), haptic: false),
        isTrue,
      );
      expect(svc.meowTriggerCount, 2);
    });

    testWidgets('MochiWidget mendukung kedip 4s, ketuk meong, TalkBack & decorative ExcludeSemantics',
        (tester) async {
      SoundService.instance.clockNowProvider = () => tester.binding.clock.now();
      addTearDown(SoundService.instance.resetMeowThrottle);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(PutarTheme.kucingManis),
          home: const Scaffold(
            body: Column(
              children: [
                MochiWidget(size: 100),
                MochiWidget(size: 64, decorative: true, enableTap: false),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Mochi'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is MochiPainter,
          ),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );

      // Saat idle awal mata terbuka (blinkScaleY == 1.0)
      MochiPainter firstMochiPainter() {
        final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        return paints
            .map((w) => w.painter)
            .whereType<MochiPainter>()
            .first;
      }

      expect(firstMochiPainter().blinkScaleY, closeTo(1.0, 0.01));

      // Maju ke 95% dari 4000ms (= 3800ms): Mochi sedang berkedip
      await tester.pump(const Duration(milliseconds: 3800));
      expect(firstMochiPainter().blinkScaleY, lessThan(0.5));

      // Ketuk Mochi -> memicu animasi bounce & SoundService.playMeow (throttled)
      await tester.tap(find.byType(MochiWidget).first);
      await tester.pump(const Duration(milliseconds: 80));
      expect(SoundService.instance.meowTriggerCount, 1);

      // Ketukan cepat segera setelahnya ter-throttle (< 600ms)
      await tester.tap(find.byType(MochiWidget).first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(SoundService.instance.meowTriggerCount, 1);
    });

    testWidgets('LogoWidget & HeartConfettiField aman terhadap disableAnimations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(PutarTheme.kucingManis),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(child: HeartConfettiField(particleCount: 12)),
                  Center(child: LogoWidget(size: 90)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MochiWidget), findsOneWidget);
      expect(find.byType(HeartConfettiField), findsOneWidget);

      // Tema Pasar Malam tetap memakai LogoPainter klasik (bukan MochiWidget)
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('pasar_malam_logo_app'),
          theme: AppTheme.buildTheme(PutarTheme.pasarMalam),
          home: const Scaffold(body: Center(child: LogoWidget(size: 80))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MochiWidget), findsNothing);
    });
  });

  group('Stage T3 - Roda Hub, Onboarding, ActiveDate, Result & KSplash', () {
    testWidgets('WheelPainter & WheelScreen menampilkan hub Mochi di tema Kucing Manis',
        (tester) async {
      final inMemoryDb = AppDatabase(NativeDatabase.memory());

      final pic = _recordPaint(
        WheelPainter(
          slots: const [20000, 30000, 40000, 50000],
          rotationAngleDegrees: 0,
          cachedTextPainters: WheelPainter.buildTextCache(
            const [20000, 30000, 40000, 50000],
            theme: PutarTheme.kucingManis,
          ),
          theme: PutarTheme.kucingManis,
        ),
        const Size(300, 300),
      );
      pic.dispose();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: const WheelScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // 1 Mochi di LogoWidget header + 1 Mochi di center hub roda
      expect(find.byType(MochiWidget), findsNWidgets(2));
      expect(find.bySemanticsLabel('Mochi'), findsNWidgets(2));

      InAppToast.dismiss();
      await inMemoryDb.close();
    });

    testWidgets('OnboardingScreen slide 0 merender Mochi di tema Kucing Manis',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MochiWidget), findsOneWidget);
      expect(find.bySemanticsLabel('Mochi'), findsOneWidget);
    });

    testWidgets('ActiveDateScreen Kucing Manis menampilkan Mochi mengintip, Masih aman!, dan tapak PawPainter',
        (tester) async {
      final inMemoryDb = AppDatabase(NativeDatabase.memory());

      final dateId = await inMemoryDb.createDate(100000);
      await inMemoryDb.addItem(dateId: dateId, name: 'Matcha Latte', price: 28000);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 680),
                textScaler: TextScaler.linear(1.3),
              ),
              child: ActiveDateScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
      expect(find.text('Masih aman!'), findsOneWidget);
      expect(find.byType(MochiWidget), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PawPainter,
        ),
        findsOneWidget,
      );

      await inMemoryDb.close();
    });

    testWidgets('DateResultScreen Kucing Manis menampilkan HeartConfetti + Mochi happy (Lolos) dan sad (Lewat)',
        (tester) async {
      final inMemoryDb = AppDatabase(NativeDatabase.memory());

      final lolosId = await inMemoryDb.createDate(100000);
      await inMemoryDb.addItem(dateId: lolosId, name: 'Croffle', price: 30000);
      await inMemoryDb.finishDate(lolosId, true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: DateResultScreen(dateId: lolosId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HeartConfettiField), findsOneWidget);
      expect(find.byType(ConfettiField), findsNothing);
      final lolosMochi = tester.widget<MochiWidget>(find.byType(MochiWidget));
      expect(lolosMochi.expression, MochiExpression.happy);
      final scaffoldLolos = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldLolos.backgroundColor, PutarTheme.kucingManis.accentPink);

      // Varian Lewat budget
      final lewatId = await inMemoryDb.createDate(50000);
      await inMemoryDb.addItem(dateId: lewatId, name: 'Steak', price: 85000);
      await inMemoryDb.finishDate(lewatId, false);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('date_result_lewat'),
          overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: DateResultScreen(dateId: lewatId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HeartConfettiField), findsNothing);
      final lewatMochi = tester.widget<MochiWidget>(find.byType(MochiWidget));
      expect(lewatMochi.expression, MochiExpression.sad);
      final scaffoldLewat = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldLewat.backgroundColor, PutarTheme.kucingManis.softDangerBg);

      await inMemoryDb.close();
    });

    testWidgets('GroupDateResultScreen Kucing Manis Layar 68 & 69 merender Mochi 124dp dan HeartConfetti',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: const GroupDateResultScreen(
              groupName: 'Grup Kucing',
              budget: 100000,
              totalSpent: 65000,
              itemCount: 3,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(tester.takeException(), isNull);
      expect(find.byType(HeartConfettiField), findsOneWidget);
      final mochi68 = tester.widget<MochiWidget>(find.byType(MochiWidget));
      expect(mochi68.size, 124);
      expect(mochi68.expression, MochiExpression.happy);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        PutarTheme.kucingManis.success,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: const GroupDateResultScreen(
              groupName: 'Grup Kucing',
              budget: 50000,
              totalSpent: 75000,
              itemCount: 2,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(tester.takeException(), isNull);
      expect(find.byType(HeartConfettiField), findsNothing);
      final mochi69 = tester.widget<MochiWidget>(find.byType(MochiWidget));
      expect(mochi69.size, 124);
      expect(mochi69.expression, MochiExpression.sad);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        PutarTheme.kucingManis.softDangerBg,
      );
      expect(find.text('Aduh, budget lewat Rp25.000'), findsOneWidget);
    });

    testWidgets('SplashScreen KSplash tampil mulus tanpa overflow di 320dp & 390dp (textScale 1.3)',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in [const Size(320, 680), const Size(390, 844)]) {
        final inMemoryDb = AppDatabase(NativeDatabase.memory());
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(inMemoryDb)],
            child: MaterialApp(
              theme: AppTheme.buildTheme(PutarTheme.kucingManis),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: const SplashScreen(),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Mochi lagi siap-siap...'), findsOneWidget);
        expect(find.bySemanticsLabel('Mochi'), findsOneWidget);

        // Selesaikan timeline 3600ms dan timer cadangan 3800ms
        await tester.pump(const Duration(milliseconds: 2500));
        expect(find.text('putar jajan'), findsOneWidget);
        expect(
          find.text(PutarTheme.kucingManis.text(PutarCopyKeys.splashTagline)),
          findsOneWidget,
        );

        final pawPrints = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((w) => w.painter is PawPainter);
        expect(pawPrints.length, 5);

        await tester.pump(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);

        await inMemoryDb.close();
      }
    });
  });
}
