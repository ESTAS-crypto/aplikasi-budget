import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/theme/putar_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/notifications/models/notification_intent.dart';

/// Slot fungsional channel notifikasi Android per tema.
enum NotificationChannelSlot {
  ongoing,
  warning,
  reminder,
  expenseLogged,
  groupActivity,
}

/// Konfigurasi channel Android & atribut visual notifikasi per tema.
@immutable
class NotificationChannelConfig {
  final String channelId;
  final String channelName;
  final String description;
  final Importance importance;
  final Priority priority;
  final bool playSound;
  final String? soundResource;
  final bool enableVibration;
  final String smallIcon;
  final Color accentColor;

  const NotificationChannelConfig({
    required this.channelId,
    required this.channelName,
    required this.description,
    required this.importance,
    required this.priority,
    required this.playSound,
    required this.soundResource,
    required this.enableVibration,
    required this.smallIcon,
    required this.accentColor,
  });

  AndroidNotificationChannel toAndroidChannel() {
    return AndroidNotificationChannel(
      channelId,
      channelName,
      description: description,
      importance: importance,
      playSound: playSound,
      sound: soundResource != null
          ? RawResourceAndroidNotificationSound(soundResource!)
          : null,
      enableVibration: enableVibration,
    );
  }
}

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
  static const String channelGroupActivityId = 'channel_group_activity_v2';

  static const String channelOngoingKucingId = 'channel_ongoing_kucing_v1';
  static const String channelWarningKucingId = 'channel_warning_kucing_v1';
  static const String channelReminderKucingId = 'channel_reminder_kucing_v1';
  static const String channelExpenseLoggedKucingId =
      'channel_expense_logged_kucing_v1';
  static const String channelGroupActivityKucingId =
      'channel_group_activity_kucing_v1';

  static const String smallIconDefault = 'ic_stat_notification';
  static const String smallIconKucing = 'ic_stat_notification_kucing';

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

  PutarTheme _activeTheme = PutarTheme.pasarMalam;

  @visibleForTesting
  int applyThemeRescheduleCount = 0;

  /// Tema yang sedang aktif digunakan oleh `NotificationService`.
  PutarTheme get activeTheme => _activeTheme;

  /// Mengembalikan konfigurasi channel & ikon Android sesuai tema dan slot.
  static NotificationChannelConfig channelConfigForTheme(
    PutarTheme theme,
    NotificationChannelSlot slot,
  ) {
    final isKucing = theme.notificationChannelSuffix == 'kucing';
    final icon = isKucing ? smallIconKucing : smallIconDefault;
    final accent = isKucing ? theme.primary : PutarTheme.kPasarMalamTomat;

    switch (slot) {
      case NotificationChannelSlot.ongoing:
        return NotificationChannelConfig(
          channelId: isKucing ? channelOngoingKucingId : channelOngoingId,
          channelName: isKucing
              ? 'Lagi Ngedate (Kucing Manis)'
              : 'Lagi Ngedate (Ongoing)',
          description:
              'Notifikasi persisten memantau sisa budget selama date berlangsung',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          soundResource: null,
          enableVibration: false,
          smallIcon: icon,
          accentColor: accent,
        );
      case NotificationChannelSlot.warning:
        return NotificationChannelConfig(
          channelId: isKucing ? channelWarningKucingId : channelWarningId,
          channelName: isKucing
              ? 'Peringatan Budget (Kucing Manis)'
              : 'Peringatan Budget',
          description:
              'Peringatan ketika budget jajan mencapai 80% atau lebih',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          soundResource: isKucing ? 'notif_warning_kucing' : 'notif_warning',
          enableVibration: true,
          smallIcon: icon,
          accentColor: accent,
        );
      case NotificationChannelSlot.reminder:
        return NotificationChannelConfig(
          channelId: isKucing ? channelReminderKucingId : channelReminderId,
          channelName: isKucing
              ? 'Pengingat & Streak (Kucing Manis)'
              : 'Pengingat & Streak',
          description:
              'Pengingat kencan mingguan Jumat 18:00 dan selebrasi streak lolos',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          soundResource: isKucing ? 'notif_reminder_kucing' : 'notif_reminder',
          enableVibration: true,
          smallIcon: icon,
          accentColor: accent,
        );
      case NotificationChannelSlot.expenseLogged:
        return NotificationChannelConfig(
          channelId:
              isKucing ? channelExpenseLoggedKucingId : channelExpenseLoggedId,
          channelName: isKucing
              ? 'Pencatatan Jajan (Kucing Manis)'
              : 'Pencatatan Jajan',
          description: 'Notifikasi status bar setiap kali jajan baru dicatat',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          soundResource: isKucing ? 'notif_warning_kucing' : 'notif_warning',
          enableVibration: true,
          smallIcon: icon,
          accentColor: accent,
        );
      case NotificationChannelSlot.groupActivity:
        return NotificationChannelConfig(
          channelId:
              isKucing ? channelGroupActivityKucingId : channelGroupActivityId,
          channelName: isKucing
              ? 'Aktivitas Grup (Kucing Manis)'
              : 'Aktivitas Grup',
          description:
              'Notifikasi aktivitas belanja dan putaran roda anggota grup',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          soundResource: isKucing ? 'notif_reminder_kucing' : 'notif_reminder',
          enableVibration: true,
          smallIcon: icon,
          accentColor: accent,
        );
    }
  }

  NotificationChannelConfig _configFor(NotificationChannelSlot slot) =>
      channelConfigForTheme(_activeTheme, slot);

  /// Mengganti tema aktif pada `NotificationService` dan menjadwalkan ulang
  /// pengingat Jumat pada channel tema baru bila pengingat sedang aktif.
  Future<void> applyTheme(
    PutarTheme theme, {
    bool reschedule = true,
    SharedPreferences? prefs,
  }) async {
    final changed = _activeTheme.id != theme.id;
    _activeTheme = theme;
    if (!changed || !reschedule) return;

    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final enabled = sp.getBool('pj_friday_reminder_enabled') ?? true;
      if (!enabled) return;

      applyThemeRescheduleCount++;
      await scheduleWeeklyFridayReminder(
        reinitTimezone: tz.timeZoneDatabase.locations.isEmpty,
      );
    } catch (e) {
      debugPrint('[NotificationService] applyTheme reschedule warning: $e');
    }
  }

  @visibleForTesting
  void resetThemeForTest() {
    _activeTheme = PutarTheme.pasarMalam;
    applyThemeRescheduleCount = 0;
  }

  Future<void> initialize({PutarTheme? initialTheme}) async {
    if (initialTheme != null) {
      _activeTheme = initialTheme;
    }

    // 1. Inisialisasi Timezone perangkat
    await updateTimezone();

    // 2. Inisialisasi Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(smallIconDefault);

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

    // 3. Daftarkan Notification Channels untuk setiap tema resmi Android 8+
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      for (final theme in PutarTheme.allThemes) {
        for (final slot in NotificationChannelSlot.values) {
          final cfg = channelConfigForTheme(theme, slot);
          await androidPlugin.createNotificationChannel(cfg.toAndroidChannel());
        }
      }
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

  bool _didAutoRequestAndroidPermission = false;

  /// Cek apakah izin notifikasi telah diberikan
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    return await androidPlugin.areNotificationsEnabled() ?? false;
  }

  /// Meminta izin runtime notifikasi Android 13+ sekali per sesi tanpa dialog tambahan
  /// agar notifikasi aktivitas grup di luar aplikasi tidak terblokir OS.
  Future<bool> ensureAndroidPermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    final enabled = await androidPlugin.areNotificationsEnabled() ?? false;
    if (enabled) return true;
    if (_didAutoRequestAndroidPermission) return false;
    _didAutoRequestAndroidPermission = true;
    try {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
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
      final t = context.putarTheme;
      final userConsent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.cardRadius),
            side: BorderSide(color: t.ink, width: t.borderWidth),
          ),
          title: Text(
            'Aktifkan Notifikasi?',
            style: TextStyle(
              fontWeight: t.weightExtraBold,
              color: t.ink,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Putar Jajan butuh izin notifikasi agar kamu bisa memantau sisa budget langsung di status bar dan menerima pengingat putar roda setiap Jumat malam.',
            style: TextStyle(color: t.ink, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Nanti Saja', style: TextStyle(color: t.textDisabled)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: t.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: t.ink, width: 2),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Izinkan', style: TextStyle(fontWeight: t.weightExtraBold)),
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
    final cfg = _configFor(NotificationChannelSlot.ongoing);

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Status sisa budget ngedate',
      importance: cfg.importance,
      priority: cfg.priority,
      ongoing: true,
      onlyAlertOnce: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
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
    final cfg = _configFor(NotificationChannelSlot.warning);

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Peringatan batas budget 80%',
      importance: cfg.importance,
      priority: cfg.priority,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
      sound: cfg.soundResource != null
          ? RawResourceAndroidNotificationSound(cfg.soundResource!)
          : null,
      playSound: cfg.playSound,
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

    final cfg = _configFor(NotificationChannelSlot.reminder);
    final isKucing = _activeTheme.notificationChannelSuffix == 'kucing';
    final reminderTitle =
        isKucing ? 'Mochi lagi nunggu kamu' : 'Roda lagi nunggu kamu';
    final reminderBody = isKucing
        ? 'Jumat malam waktunya putar roda sama Mochi. Siapa tau dapat 150k.'
        : 'Jumat malam waktunya putar. Siapa tau dapat 150k.';

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Pengingat kencan Jumat malam',
      importance: cfg.importance,
      priority: cfg.priority,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
      sound: cfg.soundResource != null
          ? RawResourceAndroidNotificationSound(cfg.soundResource!)
          : null,
      playSound: cfg.playSound,
    );

    final details = NotificationDetails(android: androidDetails);

    // Hitung waktu Jumat 18:00 terdekat
    final scheduledDate = _nextInstanceOfFriday18();

    try {
      await _plugin.zonedSchedule(
        notificationReminderId,
        reminderTitle,
        reminderBody,
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
        reminderTitle,
        reminderBody,
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
    final cfg = _configFor(NotificationChannelSlot.reminder);

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Selebrasi streak',
      importance: cfg.importance,
      priority: cfg.priority,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
      sound: cfg.soundResource != null
          ? RawResourceAndroidNotificationSound(cfg.soundResource!)
          : null,
      playSound: cfg.playSound,
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
    final cfg = _configFor(NotificationChannelSlot.expenseLogged);

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Notifikasi status bar setiap kali jajan dicatat',
      importance: cfg.importance,
      priority: cfg.priority,
      playSound: cfg.playSound,
      sound: cfg.soundResource != null
          ? RawResourceAndroidNotificationSound(cfg.soundResource!)
          : null,
      enableVibration: cfg.enableVibration,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
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

    final cfg = _configFor(NotificationChannelSlot.groupActivity);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Notifikasi aktivitas belanja dan putaran roda anggota grup',
      importance: cfg.importance,
      priority: cfg.priority,
      playSound: cfg.playSound,
      sound: cfg.soundResource != null
          ? RawResourceAndroidNotificationSound(cfg.soundResource!)
          : null,
      enableVibration: cfg.enableVibration,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
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
    final cfg = _configFor(NotificationChannelSlot.groupActivity);

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      channelDescription: 'Notifikasi grup dan aktivitas anggota',
      importance: cfg.importance,
      priority: cfg.priority,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
      sound: cfg.soundResource != null
          ? RawResourceAndroidNotificationSound(cfg.soundResource!)
          : null,
      playSound: cfg.playSound,
      enableVibration: cfg.enableVibration,
    );

    final notificationDetails = NotificationDetails(
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

    NotificationChannelSlot slot = NotificationChannelSlot.groupActivity;
    bool useCustomSound = true;
    List<AndroidNotificationAction>? actions;

    switch (intent.category) {
      case NotificationCategory.spin:
        slot = NotificationChannelSlot.groupActivity;
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
        slot = NotificationChannelSlot.warning;
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
        slot = NotificationChannelSlot.groupActivity;
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
        slot = NotificationChannelSlot.reminder;
        break;

      case NotificationCategory.syncFailed:
        slot = NotificationChannelSlot.groupActivity;
        useCustomSound = false;
        actions = const [
          AndroidNotificationAction(
            'action_coba_lagi',
            'Coba lagi',
            showsUserInterface: true,
          ),
        ];
        break;

      default:
        slot = NotificationChannelSlot.groupActivity;
        break;
    }

    final cfg = _configFor(slot);
    final soundResource = useCustomSound ? cfg.soundResource : null;

    final androidDetails = AndroidNotificationDetails(
      cfg.channelId,
      cfg.channelName,
      importance: cfg.importance,
      priority: cfg.priority,
      color: cfg.accentColor,
      icon: cfg.smallIcon,
      sound: soundResource != null
          ? RawResourceAndroidNotificationSound(soundResource)
          : null,
      playSound: cfg.playSound,
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
