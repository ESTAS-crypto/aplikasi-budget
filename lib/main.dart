import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_icon_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_transition_overlay.dart';
import 'core/utils/sound_service.dart';
import 'core/supabase/supabase_config.dart';
import 'core/group/services/group_auth_service.dart';
import 'core/group/widgets/group_realtime_listener.dart';
import 'features/navigation/app_router.dart';
import 'features/notifications/notification_service.dart';
import 'core/notifications/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi ke Portrait untuk kenyamanan penggunaan saat ngedate
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Inisialisasi SharedPreferences dengan pertahanan berlapis (fail-safe)
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('[SharedPreferences] Native init error: $e');
    try {
      // Self-healing: jika native storage korup, aktifkan in-memory fallback
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      debugPrint('[SharedPreferences] In-memory fallback berhasil diaktifkan');
    } catch (e2) {
      debugPrint('[SharedPreferences] In-memory init error: $e2');
    }
  }

  // Jaminan mutlak: prefs tidak pernah null saat runApp
  if (prefs == null) {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }

  setGlobalSharedPreferences(prefs);

  // Baca tema aktif SEBELUM runApp agar frame pertama & Splash memakai tema yang benar
  final initialTheme = readInitialThemeFromPrefs(prefs);

  // Atur warna status bar dan navigation bar sistem Android sesuai tema awal
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: initialTheme.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Pra-inisialisasi Supabase dan jingle splash sebelum runApp
  // agar realtime aktif sejak frame 1 dan audio splash serentak (0 delay)
  await Future.wait([
    SupabaseConfig.initialize().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    ),
    SoundService.instance
        .prepareSplashJingle(
          prefs: prefs,
          soundPackId: initialTheme.soundPackId,
        )
        .timeout(
          const Duration(milliseconds: 600),
          onTimeout: () {},
        ),
  ]);

  // Mount aplikasi SEGERA agar frame pertama langsung digambar
  // dan splash screen native Android langsung terlepas tanpa delay
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialThemeProvider.overrideWithValue(initialTheme),
      ],
      child: const PutarJajanApp(),
    ),
  );

  // Jalankan inisialisasi services secara non-blocking di latar belakang
  _initBackgroundServices(prefs, initialTheme);
}

Future<void> _initBackgroundServices(
  SharedPreferences prefs,
  PutarTheme initialTheme,
) async {
  // Inisialisasi lokalisasi tanggal Bahasa Indonesia
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormatting init error: $e');
  }

  // Beri jeda singkat agar pemutaran splash MediaPlayer tidak bersaing I/O saat frame 1,
  // lalu pra-decode 23 SFX SoundPool untuk tema aktif
  try {
    await Future.delayed(const Duration(milliseconds: 250));
    await SoundService.instance.initialize(
      soundPackId: initialTheme.soundPackId,
    );
  } catch (e) {
    debugPrint('SoundService init error: $e');
  }

  // Pastikan Supabase terinisialisasi jika sempat timeout sebelumnya
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Inisialisasi notifikasi lokal & pengingat Jumat pada channel tema aktif
  try {
    await NotificationService.instance.initialize(
      initialTheme: initialTheme,
    );
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  // Selaraskan ikon launcher & TaskDescription Android dengan tema tersimpan
  try {
    await AppIconService.instance.applyTheme(initialTheme, force: true);
  } catch (e) {
    debugPrint('AppIconService init error: $e');
  }

  try {
    final reminderEnabled = prefs.getBool('pj_friday_reminder_enabled') ?? true;
    if (reminderEnabled) {
      await NotificationService.instance.scheduleWeeklyFridayReminder();
    }
  } catch (e) {
    debugPrint('Weekly reminder scheduling error: $e');
  }
}

class PutarJajanApp extends ConsumerStatefulWidget {
  const PutarJajanApp({super.key});

  @override
  ConsumerState<PutarJajanApp> createState() => _PutarJajanAppState();
}

class _PutarJajanAppState extends ConsumerState<PutarJajanApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(NotificationCoordinator.instance);
    // Inisialisasi renderer bawaan NotificationCoordinator
    NotificationCoordinator.instance.setupDefaultRenderers(
      contextGetter: () => rootNavigatorKey.currentContext ?? context,
      navigator: (route) => appRouter.push(route),
      systemRenderer: (intent) =>
          NotificationService.instance.renderSystemIntent(intent),
      cancelSystemGroupRenderer: (gid) =>
          NotificationService.instance.cancelGroupNotification(gid),
    );
    NotificationCoordinator.instance.hasSystemNotificationPermissionGetter =
        () => NotificationService.instance.areNotificationsEnabled();

    // Tangani aksi navigasi dari notifikasi sistem Android
    NotificationService.instance.pendingNavigationRoute
        .addListener(_handleNotificationRoute);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(NotificationCoordinator.instance);
    NotificationService.instance.pendingNavigationRoute.removeListener(_handleNotificationRoute);
    super.dispose();
  }

  void _handleNotificationRoute() {
    final route = NotificationService.instance.pendingNavigationRoute.value;
    if (route != null) {
      appRouter.go(route);
      NotificationService.instance.pendingNavigationRoute.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeControllerProvider);
    ref.listen<PutarTheme>(themeControllerProvider, (prev, next) {
      if (prev?.id != next.id) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: next.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );
      }
    });

    return MaterialApp.router(
      title: 'Putar Jajan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(activeTheme),
      themeAnimationDuration: const Duration(milliseconds: 580),
      themeAnimationCurve: Curves.easeInOutCubic,
      routerConfig: appRouter,
      builder: (context, child) {
        return ThemeTransitionOverlay(
          child: GroupRealtimeNotificationListener(
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}
