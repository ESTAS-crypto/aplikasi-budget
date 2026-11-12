import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/theme/app_colors.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/notifications/models/notification_intent.dart';

/// Top-level background notification action handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Dipanggil saat aplikasi di background/tertutup ketika aksi notifikasi ditekan
  // Response akan diproses saat aplikasi dibuka kembali melalui getNotificationAppLaunchDetails
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String channelOngoingId = 'channel_ongoing';
  static const String channelWarningId = 'channel_warning_v2';
  static const String channelReminderId = 'channel_reminder_v2';
  static const String channelExpenseLoggedId = 'channel_expense_logged_v2';
  static const String channelGroupActivityId = 'channel_group_activity';

  static const int notificationOngoingId = 1001;
  static const int notificationWarningId = 1002;
  static const int notificationReminderId = 1003;
  static const int notificationStreakId = 1004;
  static const int notificationExpenseLoggedId = 1005;
  static const int notificationGroupBaseId = 200000;

  static const String actionCatatJajan = 'action_catat_jajan';
  static const String actionLihatSisa = 'action_lihat_sisa';

  final ValueNotifier<String?> pendingNavigationRoute = ValueNotifier<String?>(null);

  final Map<String, List<String>> _groupActivityBuffers = {};
  final Map<String, Timer> _groupActivityTimers = {};

  Future<void> initialize() async {
    // 1. Inisialisasi Timezone perangkat
    await updateTimezone();

    // 2. Inisialisasi Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationAction(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 3. Daftarkan 3 Notification Channels di Android
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Channel 1: Ongoing (Importance.low) - Tidak bersuara setiap progress diupdate
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelOngoingId,
          'Lagi Ngedate (Ongoing)',
          description: 'Notifikasi persisten memantau sisa budget selama date berlangsung',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );

      // Channel 2: Peringatan (Importance.high) - Heads-up alert dengan suara custom dan getaran saat melewati 80%
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelWarningId,
          'Peringatan Budget',
          description: 'Peringatan ketika budget jajan mencapai 80% atau lebih',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notif_warning'),
          enableVibration: true,
        ),
      );

      // Channel 3: Pengingat Mingguan & Streak (Importance.defaultImportance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelReminderId,
          'Pengingat & Streak',
          description: 'Pengingat kencan mingguan Jumat 18:00 dan selebrasi streak lolos',
          importance: Importance.defaultImportance,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notif_reminder'),
          enableVibration: true,
        ),
      );

      // Channel 4: Pencatatan Jajan (Importance.high) - Heads-up alert di status bar saat mencatat
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelExpenseLoggedId,
          'Pencatatan Jajan',
          description: 'Notifikasi status bar setiap kali jajan baru dicatat',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notif_warning'),
          enableVibration: true,
        ),
      );

      // Channel 5: Aktivitas Grup (Importance.defaultImportance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelGroupActivityId,
          'Aktivitas Grup',
          description: 'Notifikasi aktivitas belanja dan putaran roda anggota grup',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // 4. Periksa apakah cold start dipicu oleh tap notifikasi
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final response = launchDetails.notificationResponse;
      if (response != null) {
        _handleNotificationAction(response);
      }
    }
  }

  void _handleNotificationAction(NotificationResponse response) {
    if (response.actionId == actionCatatJajan) {
      pendingNavigationRoute.value = '/catatan?openAdd=true';
    } else if (response.actionId == actionLihatSisa) {
      pendingNavigationRoute.value = '/catatan';
    } else {
      // Tap default pada notifikasi
      if (response.payload == '/group/activity' ||
          (response.id != null &&
              response.id! >= notificationGroupBaseId &&
              response.id! < notificationGroupBaseId + 100000)) {
        pendingNavigationRoute.value = '/group/activity';
      } else if (response.id == notificationOngoingId ||
          response.id == notificationWarningId ||
          response.id == notificationExpenseLoggedId) {
        pendingNavigationRoute.value = '/catatan';
      } else if (response.id == notificationReminderId) {
        pendingNavigationRoute.value = '/roda';
      } else if (response.id == notificationStreakId) {
        pendingNavigationRoute.value = '/riwayat';
      }
    }
  }

  /// Cek apakah izin notifikasi telah diberikan
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    return await androidPlugin.areNotificationsEnabled() ?? false;
  }

  /// Minta izin notifikasi Android 13+ (POST_NOTIFICATIONS)
  Future<bool> requestNotificationPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    final areEnabled = await androidPlugin.areNotificationsEnabled() ?? false;
    if (areEnabled) return true;

    // Tampilkan penjelasan ramah sebelum memunculkan prompt izin sistem
    if (context.mounted) {
      final userConsent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.ink, width: 3),
          ),
          title: const Text(
            'Aktifkan Notifikasi?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'Putar Jajan butuh izin notifikasi agar kamu bisa memantau sisa budget langsung di status bar dan menerima pengingat putar roda setiap Jumat malam.',
            style: TextStyle(color: AppColors.ink, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nanti Saja', style: TextStyle(color: AppColors.disabled)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tomat,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Izinkan', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

      if (userConsent != true) return false;
    }

    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Update / Tampilkan notifikasi persisten (ongoing) saat date berlangsung
  Future<void> showOngoingDateNotification({
    required int remainingBudget,
    required int spentAmount,
    required int totalBudget,
  }) async {
    final progress = totalBudget > 0 ? (spentAmount * 100 ~/ totalBudget).clamp(0, 100) : 0;

    final androidDetails = AndroidNotificationDetails(
      channelOngoingId,
      'Lagi Ngedate (Ongoing)',
      channelDescription: 'Status sisa budget ngedate',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      notificationOngoingId,
      'Lagi ngedate · sisa ${RupiahFormatter.format(remainingBudget)}',
      'Terpakai ${RupiahFormatter.format(spentAmount)} dari ${RupiahFormatter.format(totalBudget)}',
      details,
    );
  }

  /// Hapus notifikasi ongoing saat date selesai
  Future<void> cancelOngoingNotification() async {
    await _plugin.cancel(notificationOngoingId);
  }

  /// Tampilkan notifikasi peringatan 80% dengan dua aksi: Catat jajan & Lihat sisa
  Future<void> showWarning80Notification({
    required int remainingBudget,
    required double spentPercentage,
  }) async {
    final percentInt = (spentPercentage * 100).toInt();

    final androidDetails = AndroidNotificationDetails(
      channelWarningId,
      'Peringatan Budget',
      channelDescription: 'Peringatan batas budget 80%',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      sound: const RawResourceAndroidNotificationSound('notif_warning'),
      playSound: true,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionCatatJajan,
          'Catat jajan',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          actionLihatSisa,
          'Lihat sisa',
          showsUserInterface: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      notificationWarningId,
      'Sisa ${RupiahFormatter.format(remainingBudget)} lagi',
      'Sudah $percentInt% terpakai. Pilih jajan yang hemat dulu ya.',
      details,
    );
  }

  /// Menginisialisasi atau memperbarui zona waktu perangkat
  Future<void> updateTimezone() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {}
    }
  }

  /// Batalkan jadwal pengingat Jumat malam
  Future<void> cancelWeeklyFridayReminder() async {
    await _plugin.cancel(notificationReminderId);
  }

  /// Mengambil daftar permintaan notifikasi yang sedang terjadwal
  Future<List<PendingNotificationRequest>> getPendingNotificationRequests() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }

  /// Dipanggil setelah boot, ganti zona waktu, atau konfigurasi sistem berubah
  Future<void> handleSystemConfigChange() async {
    try {
      await updateTimezone();
      await scheduleWeeklyFridayReminder(reinitTimezone: false);
    } catch (e) {
      debugPrint('[NotificationService] handleSystemConfigChange error: $e');
    }
  }

  /// Jadwalkan pengingat mingguan setiap Jumat jam 18:00 WIB
  /// Sesuai UPDATE 2C: Selalu cancel(id) terlebih dahulu sebelum zonedSchedule agar idempoten mutlak
  Future<void> scheduleWeeklyFridayReminder({bool reinitTimezone = false}) async {
    // 1. ATURAN WAJIB: Selalu batalkan jadwal lama terlebih dahulu
    await cancelWeeklyFridayReminder();

    if (reinitTimezone) {
      await updateTimezone();
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    bool canExact = false;
    if (androidPlugin != null) {
      try {
        canExact = await androidPlugin.canScheduleExactNotifications() ?? false;
      } catch (_) {
        canExact = false;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelReminderId,
      'Pengingat Mingguan & Streak',
      channelDescription: 'Pengingat kencan Jumat malam',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      sound: const RawResourceAndroidNotificationSound('notif_reminder'),
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    // Hitung waktu Jumat 18:00 terdekat
    final scheduledDate = _nextInstanceOfFriday18();

    try {
      await _plugin.zonedSchedule(
        notificationReminderId,
        'Roda lagi nunggu kamu',
        'Jumat malam waktunya putar. Siapa tau dapat 150k.',
        scheduledDate,
        details,
        androidScheduleMode: canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {
      // Fallback ke inexact jika ada kendala security
      await _plugin.zonedSchedule(
        notificationReminderId,
        'Roda lagi nunggu kamu',
        'Jumat malam waktunya putar. Siapa tau dapat 150k.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfFriday18() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      18,
      0,
    );

    while (scheduledDate.weekday != DateTime.friday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Tampilkan notifikasi selebrasi streak setelah date Lolos
  Future<void> showStreakNotification(int streakWeeks) async {
    final androidDetails = AndroidNotificationDetails(
      channelReminderId,
      'Pengingat Mingguan & Streak',
      channelDescription: 'Selebrasi streak',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      sound: const RawResourceAndroidNotificationSound('notif_reminder'),
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      notificationStreakId,
      'Streak $streakWeeks minggu!',
      'Kamu lolos budget lagi minggu ini. Pertahankan.',
      details,
    );
  }

  /// Tampilkan notifikasi status bar setiap kali jajan selesai dicatat
  Future<void> showExpenseLoggedNotification({
    required String itemName,
    required int itemPrice,
    required int remainingBudget,
    required int totalSpent,
    required int totalBudget,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelExpenseLoggedId,
      'Pencatatan Jajan',
      channelDescription: 'Notifikasi status bar setiap kali jajan dicatat',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notif_warning'),
      enableVibration: true,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      autoCancel: true,
      styleInformation: BigTextStyleInformation(
        '${RupiahFormatter.format(itemPrice)} untuk $itemName berhasil dicatat.\nSisa budget ngedate: ${RupiahFormatter.format(remainingBudget)} (Terpakai ${RupiahFormatter.format(totalSpent)} dari ${RupiahFormatter.format(totalBudget)})',
        contentTitle: 'Jajan dicatat · Sisa ${RupiahFormatter.format(remainingBudget)}',
        summaryText: 'Putar Jajan',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      notificationExpenseLoggedId,
      'Jajan dicatat · Sisa ${RupiahFormatter.format(remainingBudget)}',
      '$itemName (${RupiahFormatter.format(itemPrice)}) dicatat. Sisa budget: ${RupiahFormatter.format(remainingBudget)}',
      details,
    );
  }

  /// Batalkan notifikasi pencatatan jajan
  Future<void> cancelExpenseLoggedNotification() async {
    await _plugin.cancel(notificationExpenseLoggedId);
  }

  /// Batalkan notifikasi sistem untuk grup tertentu (pembersihan saat layar dibuka)
  Future<void> cancelGroupNotification(String gid) async {
    final notifId = notificationGroupBaseId + (gid.hashCode.abs() % 90000);
    _groupActivityBuffers.remove(gid);
    _groupActivityTimers[gid]?.cancel();
    _groupActivityTimers.remove(gid);
    await _plugin.cancel(notifId);
  }

  /// Menampilkan notifikasi aktivitas grup dengan penggabungan 60 detik per grup
  Future<void> showGroupActivityNotification({
    required String gid,
    required String groupName,
    required String actorUid,
    required String currentUid,
    required String message,
    bool isExpense = false,
    bool notifyEnabled = true,
  }) async {
    // HP pelaku TIDAK menerima notifikasi sistem untuk aksinya sendiri
    if (actorUid == currentUid || !notifyEnabled) {
      return;
    }

    final buffer = _groupActivityBuffers.putIfAbsent(gid, () => []);
    buffer.add(message);

    final notificationId = notificationGroupBaseId + (gid.hashCode.abs() % 90000);

    final String title;
    final String body;
    if (buffer.length == 1) {
      title = groupName;
      body = message;
    } else {
      title = '${buffer.length} aktivitas baru di $groupName';
      body = '${buffer.last}, dan ${buffer.length - 1} lainnya.';
    }

    _groupActivityTimers[gid]?.cancel();
    _groupActivityTimers[gid] = Timer(const Duration(seconds: 60), () {
      _groupActivityBuffers.remove(gid);
      _groupActivityTimers.remove(gid);
    });

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelGroupActivityId,
      'Aktivitas Grup',
      channelDescription: 'Notifikasi aktivitas belanja dan putaran roda anggota grup',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      actions: isExpense && buffer.length == 1
          ? const [
              AndroidNotificationAction(
                actionCatatJajan,
                'Catat jajan',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                actionLihatSisa,
                'Lihat sisa',
                showsUserInterface: true,
              ),
            ]
          : null,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _plugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: '/group/activity',
      );
    } catch (_) {}
  }

  /// Menampilkan notifikasi instan untuk aktivitas grup (join, buat grup, putar roda)
  Future<void> showGroupNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelGroupActivityId,
      'Aktivitas Grup',
      channelDescription: 'Notifikasi grup dan aktivitas anggota',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
      await _plugin.show(
        notifId,
        title,
        body,
        notificationDetails,
        payload: payload ?? '/roda',
      );
    } catch (_) {}
  }

  /// Render notifikasi sistem dari NotificationCoordinator dengan ID stabil per grup
  Future<void> renderSystemIntent(NotificationIntent intent) async {
    final notifId = (intent.gid != null && intent.gid!.isNotEmpty)
        ? (notificationGroupBaseId + (intent.gid!.hashCode.abs() % 90000))
        : intent.stableNotificationId;

    String channelId = channelGroupActivityId;
    String channelName = 'Aktivitas Grup';
    Importance importance = Importance.defaultImportance;
    Priority priority = Priority.defaultPriority;
    String? soundResource;
    List<AndroidNotificationAction>? actions;

    switch (intent.category) {
      case NotificationCategory.spin:
        channelId = channelGroupActivityId;
        channelName = 'Aktivitas Grup';
        importance = Importance.high;
        priority = Priority.high;
        soundResource = 'notif_reminder';
        actions = const [
          AndroidNotificationAction(
            actionCatatJajan,
            'Catat jajan',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            actionLihatSisa,
            'Lihat budget',
            showsUserInterface: true,
          ),
        ];
        break;

      case NotificationCategory.budgetWarning80:
      case NotificationCategory.budgetOver:
        channelId = channelWarningId;
        channelName = 'Peringatan Budget';
        importance = Importance.high;
        priority = Priority.high;
        soundResource = 'notif_warning';
        actions = const [
          AndroidNotificationAction(
            actionCatatJajan,
            'Catat jajan',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            actionLihatSisa,
            'Lihat sisa',
            showsUserInterface: true,
          ),
        ];
        break;

      case NotificationCategory.expense:
        channelId = channelGroupActivityId;
        channelName = 'Aktivitas Grup';
        importance = Importance.high;
        priority = Priority.high;
        soundResource = 'notif_reminder';
        actions = const [
          AndroidNotificationAction(
            actionCatatJajan,
            'Catat jajan',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            actionLihatSisa,
            'Lihat sisa',
            showsUserInterface: true,
          ),
        ];
        break;

      case NotificationCategory.weeklyReminder:
      case NotificationCategory.streakCelebration:
        channelId = channelReminderId;
        channelName = 'Pengingat & Streak';
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        soundResource = 'notif_reminder';
        break;

      case NotificationCategory.syncFailed:
        channelId = channelGroupActivityId;
        channelName = 'Aktivitas Grup';
        importance = Importance.high;
        priority = Priority.high;
        actions = const [
          AndroidNotificationAction(
            'action_coba_lagi',
            'Coba lagi',
            showsUserInterface: true,
          ),
        ];
        break;

      default:
        channelId = channelGroupActivityId;
        channelName = 'Aktivitas Grup';
        importance = Importance.high;
        priority = Priority.high;
        soundResource = 'notif_reminder';
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      color: AppColors.tomat,
      icon: 'ic_stat_notification',
      sound: soundResource != null
          ? RawResourceAndroidNotificationSound(soundResource)
          : null,
      playSound: true,
      actions: actions,
      styleInformation: BigTextStyleInformation(
        intent.systemBody,
        contentTitle: intent.systemTitle,
        summaryText: 'Putar Jajan',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        notifId,
        intent.systemTitle,
        intent.systemBody,
        notificationDetails,
        payload: intent.payload ?? '/group/activity',
      );
    } catch (e) {
      debugPrint('[NotificationService] renderSystemIntent error: $e');
    }
  }
}
