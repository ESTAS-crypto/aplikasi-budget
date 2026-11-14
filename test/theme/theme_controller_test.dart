import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:putar_jajan/core/painters/logo_painter.dart';
import 'package:putar_jajan/core/painters/mochi_painter.dart';
import 'package:putar_jajan/core/theme/app_icon_service.dart';
import 'package:putar_jajan/core/theme/app_theme.dart';
import 'package:putar_jajan/core/theme/theme_controller.dart';
import 'package:putar_jajan/core/theme/theme_transition_overlay.dart';
import 'package:putar_jajan/features/wheel/brand_system_screen.dart';

void main() {
  group('readInitialThemeFromPrefs', () {
    test('defaults to Pasar Malam when prefs is null or empty', () {
      expect(readInitialThemeFromPrefs(null).id, PutarTheme.pasarMalam.id);
    });

    test('returns Pasar Malam when key is absent or unknown', () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      expect(readInitialThemeFromPrefs(prefs).id, PutarTheme.pasarMalam.id);

      SharedPreferences.setMockInitialValues({
        kThemePreferenceKey: 'tema_tidak_dikenal',
      });
      prefs = await SharedPreferences.getInstance();
      expect(readInitialThemeFromPrefs(prefs).id, PutarTheme.pasarMalam.id);
    });

    test('loads persisted Kucing Manis theme id from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        kThemePreferenceKey: PutarTheme.kucingManis.id,
      });
      final prefs = await SharedPreferences.getInstance();
      final theme = readInitialThemeFromPrefs(prefs);
      expect(theme.id, PutarTheme.kucingManis.id);
      expect(theme.displayName, PutarTheme.kucingManis.displayName);
    });
  });

  group('ThemeController', () {
    test('updates state, persists selection, and fires callback', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final callbacks = <String>[];

      final controller = ThemeController(
        initialTheme: PutarTheme.pasarMalam,
        prefs: prefs,
        onThemeChanged: (theme) {
          callbacks.add(theme.id);
        },
      );

      expect(controller.state.id, PutarTheme.pasarMalam.id);

      await controller.setThemeById(PutarTheme.kucingManis.id);
      expect(controller.state.id, PutarTheme.kucingManis.id);
      expect(prefs.getString(kThemePreferenceKey), PutarTheme.kucingManis.id);
      expect(callbacks, [PutarTheme.kucingManis.id]);

      // Setting the same active theme id should be a no-op.
      await controller.setThemeById(PutarTheme.kucingManis.id);
      expect(callbacks, [PutarTheme.kucingManis.id]);

      await controller.setTheme(PutarTheme.pasarMalam);
      expect(controller.state.id, PutarTheme.pasarMalam.id);
      expect(prefs.getString(kThemePreferenceKey), PutarTheme.pasarMalam.id);
      expect(callbacks, [PutarTheme.kucingManis.id, PutarTheme.pasarMalam.id]);
    });

    test('falls back to Pasar Malam on unknown id', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final controller = ThemeController(
        initialTheme: PutarTheme.kucingManis,
        prefs: prefs,
      );

      await controller.setThemeById('unknown_theme_id');
      expect(controller.state.id, PutarTheme.pasarMalam.id);
      expect(prefs.getString(kThemePreferenceKey), PutarTheme.pasarMalam.id);
    });
  });

  group('PutarTheme.lerp', () {
    test('returns endpoints at t=0.0 and t=1.0 and interpolates at t=0.5', () {
      const a = PutarTheme.pasarMalam;
      const b = PutarTheme.kucingManis;

      final atZero = a.lerp(b, 0.0);
      expect(atZero.id, a.id);
      expect(atZero.bg, a.bg);
      expect(atZero.primary, a.primary);
      expect(atZero.borderWidth, closeTo(a.borderWidth, 0.0001));
      expect(atZero.iconStyle, a.iconStyle);

      final atMid = a.lerp(b, 0.5);
      expect(atMid.id, b.id);
      expect(atMid.bg, Color.lerp(a.bg, b.bg, 0.5));
      expect(atMid.primary, Color.lerp(a.primary, b.primary, 0.5));
      expect(
        atMid.cardRadius,
        closeTo((a.cardRadius + b.cardRadius) / 2, 0.0001),
      );
      expect(atMid.iconStyle, b.iconStyle);

      final atOne = a.lerp(b, 1.0);
      expect(atOne.id, b.id);
      expect(atOne.bg, b.bg);
      expect(atOne.primary, b.primary);
      expect(atOne.cardRadius, closeTo(b.cardRadius, 0.0001));
      expect(atOne.iconStyle, b.iconStyle);

      expect(a.lerp(null, 0.5).id, a.id);
    });
  });

  group('PutarCopyKeys & theme registry', () {
    test('all themes provide every required copy key and substitute params', () {
      expect(PutarTheme.allThemes.length, greaterThanOrEqualTo(2));
      final ids = PutarTheme.allThemes.map((t) => t.id).toSet();
      expect(ids.length, PutarTheme.allThemes.length);
      expect(ids, containsAll([PutarTheme.pasarMalam.id, PutarTheme.kucingManis.id]));

      for (final theme in PutarTheme.allThemes) {
        expect(theme.id, isNotEmpty);
        expect(theme.displayName, isNotEmpty);
        for (final key in PutarCopyKeys.requiredKeys) {
          expect(
            theme.copy.containsKey(key),
            isTrue,
            reason: '${theme.id} missing copy key: $key',
          );
          final resolved = theme.text(
            key,
            params: const {'amount': '50.000', 'weeks': '3'},
          );
          expect(resolved, isNotEmpty);
          expect(resolved, isNot(contains('{')));
          expect(resolved, isNot(contains('}')));
        }
      }
    });
  });

  group('AppIconService & smooth theme transitions', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      AppIconService.instance.resetForTest();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.putarjajan.putar_jajan/app_icon'),
        null,
      );
      AppIconService.instance.resetForTest();
    });

    test('AppIconService invokes native setLauncherTheme on theme changes', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.putarjajan.putar_jajan/app_icon'),
        (call) async {
          calls.add(call);
          return true;
        },
      );

      final kucingOk = await AppIconService.instance.applyTheme(
        PutarTheme.kucingManis,
      );
      expect(kucingOk, isTrue);
      expect(
        AppIconService.instance.lastAppliedThemeId,
        PutarTheme.kucingManis.id,
      );

      // Duplicate call without force should be a clean no-op.
      await AppIconService.instance.applyTheme(PutarTheme.kucingManis);
      expect(calls.length, 1);

      final pasarOk = await AppIconService.instance.applyTheme(
        PutarTheme.pasarMalam,
      );
      expect(pasarOk, isTrue);
      expect(calls.length, 2);
      expect(calls[0].method, 'setLauncherTheme');
      expect(calls[0].arguments, {'themeId': PutarTheme.kucingManis.id});
      expect(calls[1].arguments, {'themeId': PutarTheme.pasarMalam.id});
    });

    test('AppIconService handles MissingPluginException gracefully', () async {
      final result = await AppIconService.instance.setLauncherTheme(
        PutarTheme.kucingManis.id,
      );
      expect(result, isFalse);
    });

    test('ThemeController emits ThemeTransitionSignal with tap origin', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(
        initialTheme: PutarTheme.pasarMalam,
        prefs: prefs,
      );
      addTearDown(controller.dispose);

      const tapPoint = Offset(144, 520);
      await controller.setTheme(PutarTheme.kucingManis, origin: tapPoint);

      final signal = controller.transitionSignalListenable.value;
      expect(signal, isNotNull);
      expect(signal!.fromTheme.id, PutarTheme.pasarMalam.id);
      expect(signal.toTheme.id, PutarTheme.kucingManis.id);
      expect(signal.origin, tapPoint);
      expect(signal.seq, 1);
    });

    testWidgets(
      'ThemeTransitionOverlay completes smoothly and respects disableAnimations',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final controller = ThemeController(
          initialTheme: PutarTheme.pasarMalam,
          prefs: prefs,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ThemeTransitionOverlay(
                signalListenable: controller.transitionSignalListenable,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

        await controller.setTheme(
          PutarTheme.kucingManis,
          origin: const Offset(100, 200),
        );
        await tester.pump(const Duration(milliseconds: 220));
        expect(find.byType(IgnorePointer), findsWidgets);

        await tester.pumpAndSettle();

        // When disableAnimations is true, overlay should skip animation layers.
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ThemeTransitionOverlay(
                signalListenable: controller.transitionSignalListenable,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await controller.setTheme(PutarTheme.pasarMalam);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'LogoWidget morphs smoothly between Pasar Malam wheel and Kucing Mochi',
      (tester) async {
        var activeTheme = PutarTheme.pasarMalam;
        late void Function(VoidCallback) setHostState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MaterialApp(
                theme: AppTheme.buildTheme(activeTheme),
                themeAnimationDuration: const Duration(milliseconds: 580),
                home: const Scaffold(
                  body: Center(
                    child: LogoWidget(size: 64, animate: false),
                  ),
                ),
              );
            },
          ),
        );

        expect(find.bySemanticsLabel('Logo Putar Jajan'), findsOneWidget);
        expect(find.byType(MochiWidget), findsNothing);

        setHostState(() => activeTheme = PutarTheme.kucingManis);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Mochi'), findsOneWidget);
        expect(find.bySemanticsLabel('Logo Putar Jajan'), findsNothing);
      },
    );

    testWidgets(
      'BrandSystemScreen renders Kucing Manis palette, copy, and Mochi variants',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(PutarTheme.kucingManis),
            home: const BrandSystemScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Sakura'), findsOneWidget);
        expect(find.text('Pistachio'), findsOneWidget);
        expect(
          find.textContaining('Mochi si kucing karamel penunggu jajan'),
          findsOneWidget,
        );
        expect(find.textContaining('Font Fredoka'), findsOneWidget);
      },
    );
  });
}

