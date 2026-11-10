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

  // Inisialisasi SharedPreferences untuk persistensi lokal dan mode grup
  final prefs = await SharedPreferences.getInstance();
  setGlobalSharedPreferences(prefs);

  // Inisialisasi audio sound service sedini mungkin sebelum frame pertama
  try {
    await SoundService.instance.initialize();
  } catch (e) {
    debugPrint('SoundService main init error: $e');
  }

  // Inisialisasi lokalisasi tanggal Bahasa Indonesia dengan proteksi try/catch
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormatting init error: $e');
  }

  // Kunci orientasi ke Portrait untuk kenyamanan penggunaan saat ngedate
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Inisialisasi Supabase (Free tier PostgreSQL & Realtime)
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase main init error: $e');
  }

  // Atur warna status bar dan navigation bar sistem Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Mount aplikasi dengan SharedPreferences yang sudah siap
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PutarJajanApp(),
    ),
  );

  // Jalankan inisialisasi background notification secara non-blocking
  _initBackgroundServices();
}

Future<void> _initBackgroundServices() async {
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
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
