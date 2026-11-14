import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/group/services/group_auth_service.dart';
import 'package:putar_jajan/core/group/sync/sync_state.dart';
import 'package:putar_jajan/core/group/widgets/sync_legend.dart';
import 'package:putar_jajan/core/group/widgets/sync_strip.dart';
import 'package:putar_jajan/core/notifications/models/notification_intent.dart';
import 'package:putar_jajan/core/painters/nav_icons_painter.dart';
import 'package:putar_jajan/core/painters/paw_painter.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/widgets/in_app_toast.dart';
import 'package:putar_jajan/data/database.dart';
import 'package:putar_jajan/data/database_provider.dart';
import 'package:putar_jajan/features/navigation/bottom_nav_bar.dart';
import 'package:putar_jajan/features/wheel/wheel_painter.dart';
import 'package:putar_jajan/features/wheel/wheel_screen.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

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
  });

  group('Stage T2 - Token tema Kucing Manis', () {
    const k = PutarTheme.kucingManis;

    test('palet, font Fredoka, bentuk, bayangan & copy sesuai spesifikasi', () {
      expect(k.id, 'kucing_manis');
      expect(k.ink, const Color(0xFF3A2E4F));
      expect(k.bg, const Color(0xFFFFF0F5));
      expect(k.surface, const Color(0xFFFFFFFF));
      expect(k.textSecondary, const Color(0xFF6E5C86));
      expect(k.textDisabled, const Color(0xFF74648C));
      expect(k.softDangerBg, const Color(0xFFFFD0DC));
      expect(k.wheelPalette, const [
        Color(0xFFFF8FB1),
        Color(0xFFFFB997),
        Color(0xFFFFE27A),
        Color(0xFF9BE8D0),
        Color(0xFFA8D8FF),
        Color(0xFFCDB4FF),
        Color(0xFFFFC8DD),
        Color(0xFFC8F0A8),
      ]);

      expect(k.fontFamily, 'Fredoka');
      expect(k.weightRegular, FontWeight.w400);
      expect(k.weightMedium, FontWeight.w500);
      expect(k.weightSemiBold, FontWeight.w600);
      expect(k.weightBold, FontWeight.w700);
      expect(k.weightExtraBold, FontWeight.w700);

      expect(k.borderWidth, 3.0);
      expect(k.cardRadius, 26.0);
      expect(k.smallCardRadius, 22.0);
      expect(k.buttonRadius, 26.0);
      expect(k.pillButtonRadius, 29.0);
      expect(k.navBarTopRadius, 26.0);
      expect(k.navActivePillRadius, 18.0);
      expect(k.standardShadowOffset, const Offset(0, 5));
      expect(k.heroShadowOffset, const Offset(0, 6));
      expect(k.smallShadowOffset, const Offset(0, 4));
      expect(k.miniShadowOffset, const Offset(0, 2));
      expect(k.wheelShadowOffset, const Offset(0, 7));

      expect(k.navIconStyle, PutarIconStyle.kucing);
      expect(k.pointerStyle, PutarIconStyle.kucing);
      expect(k.wheelDecor, PutarWheelDecor.ears);

      expect(
        k.text(PutarCopyKeys.wheelSubtitle),
        'Putar dulu, nanti kucingnya yang jaga budget.',
      );
      expect(k.text(PutarCopyKeys.wheelReady), 'Roda siap diputar, meong!');
      expect(
        k.text(PutarCopyKeys.budgetOverAmount, params: const {'amount': '12.000'}),
        'Aduh, budget lewat Rp12.000',
      );
      expect(k.text(PutarCopyKeys.syncFailed), 'Aduh, gagal');

      final mid = PutarTheme.pasarMalam.lerp(k, 0.5);
      expect(mid.navBarTopRadius, closeTo(13.0, 0.001));
      expect(mid.navActivePillRadius, closeTo(17.0, 0.001));
      expect(mid.wheelShadowOffset, const Offset(0, 3.5));
    });

    test('rasio kontras WCAG AA (>= 4.5) terpenuhi di semua warna teks utama', () {
      expect(_contrastRatio(k.ink, k.bg), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(k.ink, k.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(k.textSecondary, k.bg), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(k.textSecondary, k.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(k.textDisabled, k.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(k.textDisabled, k.bg), greaterThanOrEqualTo(4.5));

      for (final sliceColor in k.wheelPalette) {
        expect(
          _contrastRatio(k.ink, sliceColor),
          greaterThanOrEqualTo(4.5),
          reason: 'Slice $sliceColor harus kontras >= 4.5 dengan ink ${k.ink}',
        );
      }
    });

    test('NotificationIntent factories mendukung theme Pasar Malam dan Kucing', () {
      final defaultOver = NotificationIntent.budgetOver(
        scopeId: 'g1',
        sessionId: 's1',
        groupOrAppName: 'Kencan',
        overAmount: 15000,
        totalBudget: 50000,
        totalSpent: 65000,
      );
      expect(defaultOver.title, 'Budget lewat Rp15.000');

      final kucingOver = NotificationIntent.budgetOver(
        scopeId: 'g1',
        sessionId: 's1',
        groupOrAppName: 'Kencan',
        overAmount: 15000,
        totalBudget: 50000,
        totalSpent: 65000,
        theme: PutarTheme.kucingManis,
      );
      expect(kucingOver.title, 'Aduh, budget lewat Rp15.000');

      final kucingReminder = NotificationIntent.weeklyReminder(
        year: 2026,
        weekNumber: 46,
        theme: PutarTheme.kucingManis,
      );
      expect(kucingReminder.title, 'Mochi nunggu kamu, meong~');

      final kucingStreak = NotificationIntent.streakCelebration(
        streakWeeks: 5,
        date: DateTime(2026, 11, 14),
        theme: PutarTheme.kucingManis,
      );
      expect(kucingStreak.title, 'Streak 5 minggu, hebat!');
    });
  });

  group('Stage T2 - CustomPainter Kucing Manis', () {
    test('PawPainter, WheelEarPainter, NavPainters & WheelPainter melukis tanpa error', () {
      final pawUp = _recordPaint(const PawPainter(), const Size(40, 40));
      final pawDown = _recordPaint(const PawPainter(pointDown: true), const Size(42, 42));
      final earL = _recordPaint(const WheelEarPainter(), const Size(64, 64));
      final earR = _recordPaint(const WheelEarPainter(mirrorHorizontal: true), const Size(64, 64));
      final wheelNav = _recordPaint(
        const WheelNavPainter(style: PutarIconStyle.kucing),
        const Size(26, 26),
      );
      final receiptNav = _recordPaint(
        const ReceiptNavPainter(style: PutarIconStyle.kucing),
        const Size(26, 26),
      );
      final historyNav = _recordPaint(
        const HistoryNavPainter(style: PutarIconStyle.kucing),
        const Size(26, 26),
      );

      final slots = const [20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000];
      final wheelPainter = WheelPainter(
        slots: slots,
        rotationAngleDegrees: 15,
        cachedTextPainters: WheelPainter.buildTextCache(
          slots,
          theme: PutarTheme.kucingManis,
        ),
        theme: PutarTheme.kucingManis,
      );
      final wheelPic = _recordPaint(wheelPainter, const Size(300, 300));
      final miniWheelPic = _recordPaint(
        WheelPainter(
          slots: slots,
          rotationAngleDegrees: 0,
          cachedTextPainters: const {},
          isMiniPreview: true,
          theme: PutarTheme.kucingManis,
        ),
        const Size(120, 120),
      );

      expect(pawUp.approximateBytesUsed, greaterThan(0));
      expect(pawDown.approximateBytesUsed, greaterThan(0));
      expect(earL.approximateBytesUsed, greaterThan(0));
      expect(earR.approximateBytesUsed, greaterThan(0));
      expect(wheelNav.approximateBytesUsed, greaterThan(0));
      expect(receiptNav.approximateBytesUsed, greaterThan(0));
      expect(historyNav.approximateBytesUsed, greaterThan(0));
      expect(wheelPic.approximateBytesUsed, greaterThan(0));
      expect(miniWheelPic.approximateBytesUsed, greaterThan(0));

      expect(
        const WheelNavPainter(style: PutarIconStyle.kucing)
            .shouldRepaint(const WheelNavPainter(style: PutarIconStyle.pasarMalam)),
        isTrue,
      );
      expect(
        const ReceiptNavPainter(style: PutarIconStyle.kucing)
            .shouldRepaint(const ReceiptNavPainter(style: PutarIconStyle.pasarMalam)),
        isTrue,
      );
      expect(
        const HistoryNavPainter(style: PutarIconStyle.kucing)
            .shouldRepaint(const HistoryNavPainter(style: PutarIconStyle.pasarMalam)),
        isTrue,
      );

      pawUp.dispose();
      pawDown.dispose();
      earL.dispose();
      earR.dispose();
      wheelNav.dispose();
      receiptNav.dispose();
      historyNav.dispose();
      wheelPic.dispose();
      miniWheelPic.dispose();
    });
  });

  group('Stage T2 - Widget rendering tema Kucing Manis', () {
    testWidgets('BottomNavBar merender lengkung atas 26px & ikon berkuping tanpa error', (tester) async {
      final router = GoRouter(
        initialLocation: '/roda',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(
              body: shell,
              bottomNavigationBar: BottomNavBar(navigationShell: shell),
            ),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/roda', builder: (_, _) => const SizedBox.shrink()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/catatan', builder: (_, _) => const SizedBox.shrink()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/riwayat', builder: (_, _) => const SizedBox.shrink()),
              ]),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.buildTheme(PutarTheme.kucingManis),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('Catatan'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);

      final navPaints = tester.widgetList<CustomPaint>(
        find.descendant(of: find.byType(BottomNavBar), matching: find.byType(CustomPaint)),
      );
      final wheelNav = navPaints.map((w) => w.painter).whereType<WheelNavPainter>().first;
      final receiptNav = navPaints.map((w) => w.painter).whereType<ReceiptNavPainter>().first;
      final historyNav = navPaints.map((w) => w.painter).whereType<HistoryNavPainter>().first;

      expect(wheelNav.style, PutarIconStyle.kucing);
      expect(receiptNav.style, PutarIconStyle.kucing);
      expect(historyNav.style, PutarIconStyle.kucing);

      await tester.tap(find.text('Catatan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('WheelScreen di tema Kucing Manis tampil bersih di 320dp dan 390dp (textScale 1.3)', (tester) async {
      addTearDown(() async {
        InAppToast.dismiss();
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
                child: const WheelScreen(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(
          find.text('Putar dulu, nanti kucingnya yang jaga budget.'),
          findsOneWidget,
        );
        if (size.width == 320) {
          expect(find.text('Roda siap diputar, meong!'), findsOneWidget);
        }
        expect(find.text('PUTAR RODA'), findsOneWidget);

        // Pastikan watermark telapak hadir dan dibungkus ExcludeSemantics
        final wheelPaint = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<WheelPainter>()
            .first;
        expect(wheelPaint.theme.id, PutarTheme.kucingManis.id);

        final pawPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((w) => w.painter is PawPainter);
        expect(pawPaints.length, 3);
        expect(
          find.ancestor(
            of: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PawPainter),
            matching: find.byType(ExcludeSemantics),
          ),
          findsNWidgets(3),
        );

        InAppToast.dismiss();
        await inMemoryDb.close();
      }
    });

    testWidgets('SyncStrip & SyncLegend memakai copy Kucing tanpa overflow di 320dp', (tester) async {
      tester.view.physicalSize = const Size(640, 1360);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(PutarTheme.kucingManis),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SyncStrip(state: SyncState.gagal, isVisible: true),
                  SizedBox(height: 12),
                  SyncLegend(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Aduh, gagal sinkron ke server'), findsOneWidget);
      expect(find.text('Aduh, gagal'), findsOneWidget);
    });
  });
}
