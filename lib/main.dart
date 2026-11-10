import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
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

  // Atur warna status bar dan navigation bar sistem Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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

  // Mount aplikasi SEGERA agar frame pertama langsung digambar
  // dan splash screen native Android langsung terlepas tanpa delay
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PutarJajanApp(),
    ),
  );

  // Jalankan inisialisasi services secara non-blocking di latar belakang
  _initBackgroundServices(prefs);
}

Future<void> _initBackgroundServices(SharedPreferences prefs) async {
  // Inisialisasi lokalisasi tanggal Bahasa Indonesia
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormatting init error: $e');
  }

  // Inisialisasi audio sound service
  try {
    await SoundService.instance.initialize();
  } catch (e) {
    debugPrint('SoundService init error: $e');
  }

  // Inisialisasi Supabase (Free tier PostgreSQL & Realtime)
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Inisialisasi notifikasi lokal & pengingat Jumat
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
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

class PutarJajanApp extends StatefulWidget {
  const PutarJajanApp({super.key});

  @override
  State<PutarJajanApp> createState() => _PutarJajanAppState();
}

class _PutarJajanAppState extends State<PutarJajanApp> {
  @override
  void initState() {
    super.initState();
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
    return MaterialApp.router(
      title: 'Putar Jajan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return GroupRealtimeNotificationListener(
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
