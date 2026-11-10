import 'package:flutter/foundation.dart';

/// Sumber pemicu notifikasi
enum NotificationSource {
  listener,     // Supabase / Firestore realtime listener
  fcm,          // Firebase Cloud Messaging data message
  schedule,     // Local periodic / zoned schedule (misal pengingat Jumat)
  localBudget,  // Perhitungan budget lokal (80%, over budget, streak)
  syncState,    // Status sinkronisasi offline / gagal
  userAction,   // Aksi langsung dalam aplikasi
}

/// Permukaan tampilan yang eksklusif (hanya satu per kejadian)
enum NotificationSurface {
  banner,       // In-App banner meluncur dari atas (foreground)
  system,       // Notifikasi bar status sistem Android (background / terminated)
  dialog,       // Dialog penting yang butuh keputusan/dibaca (menggantikan banner)
  dropped,      // Diabaikan / disaring (tetap dicatat agar tidak susulan)
}

/// Alasan notifikasi diabaikan / disaring
enum NotificationDropReason {
  none,               // Tidak di-drop (berhasil ditampilkan)
  ownAction,          // Aksi diri sendiri (actorUid == currentUid)
  muted,              // Grup dibisukan oleh pengguna
  toggleDisabled,     // Sakelar kategori notifikasi dimatikan
  permissionDenied,   // Izin notifikasi sistem Android belum diberikan
  duplicate,          // Sudah pernah diklaim sebelumnya (anti-double)
  oldEvent,           // Event usang (createdAt sebelum watermark atau >5 menit lalu)
  merged,             // Digabungkan ke dalam notifikasi rangkuman sebelumnya
}

/// Kategori notifikasi sesuai spesifikasi UPDATE 2C & Notif1-4
enum NotificationCategory {
  expense,            // Pengeluaran baru dicatat (kuning)
  expenseDeleted,     // Catatan pengeluaran dihapus (krim)
  spin,               // Permainan / Roda diputar (lavender)
  budgetWarning80,    // Budget mencapai 80% (kuning)
  budgetOver,         // Budget lewat / over (tomat)
  sessionEnd,         // Sesi selesai / lolos (mint)
  memberJoin,         // Anggota baru bergabung (mint)
  memberLeave,        // Anggota keluar (krim)
  codeChanged,        // Kode undangan diganti (biru)
  kickedFromGroup,    // Dikeluarkan dari grup (dialog / sistem tomat)
  groupDeleted,       // Grup dihapus oleh pemilik (dialog / sistem tomat)
  syncFailed,         // Perubahan gagal terkirim (strip + dialog / sistem tomat)
  weeklyReminder,     // Pengingat putar roda Jumat malam (sistem tomat)
  streakCelebration,  // Selebrasi streak berturut-turut (sistem tomat)
  custom,             // Kategori tambahan masa depan
}

/// Model objek tunggal yang mewakili niat memunculkan notifikasi
@immutable
class NotificationIntent {
  /// DedupeKey yang stabil dan deterministik
  /// Format standar:
  /// - Event grup: "evt:{gid}:{eventId}"
  /// - Budget 80%: "bud80:{gid}:{sessionId}"
  /// - Budget lewat: "budOver:{gid}:{sessionId}"
  /// - Pengingat mingguan: "rem:{tahun}-W{minggu}"
  /// - Streak: "streak:{tanggal}"
  /// - Gagal sinkron: "syncfail:{gid}"
  final String dedupeKey;

  /// Kategori notifikasi
  final NotificationCategory category;

  /// Asal sumber notifikasi
  final NotificationSource source;

  /// ID grup (opsional jika notifikasi personal)
  final String? gid;

  /// Nama grup (opsional)
  final String? groupName;

  /// UID pelaku aksi (untuk filter aksi diri sendiri)
  final String? actorUid;

  /// Nama pelaku aksi
  final String? actorName;

  /// Judul untuk Banner / Dialog (maks 1 baris)
  final String title;

  /// Subtitle / isi ringkas Banner (maks 1 baris, ellipsis)
  final String subtitle;

  /// Judul notifikasi sistem (Nama grup atau "Putar Jajan")
  final String systemTitle;

  /// Isi kalimat lengkap dengan nominal untuk notifikasi sistem (maks 2 baris)
  final String systemBody;

  /// Nominal pengeluaran / budget bila ada
  final int? amount;

  /// Waktu pembuatan kejadian
  final DateTime createdAt;

  /// Payload rute navigasi saat notifikasi diketuk (misal "/group/activity")
  final String? payload;

  /// Apakah notifikasi ini mewakili hal kritis yang mewajibkan Dialog
  final bool isImportantDialog;

  /// Metadata tambahan fleksibel
  final Map<String, dynamic> extra;

  const NotificationIntent({
    required this.dedupeKey,
    required this.category,
    required this.source,
    required this.title,
    required this.subtitle,
    required this.systemTitle,
    required this.systemBody,
    this.gid,
    this.groupName,
    this.actorUid,
    this.actorName,
    this.amount,
    DateTime? createdAt,
    this.payload,
    this.isImportantDialog = false,
    this.extra = const {},
  }) : createdAt = createdAt ?? const _DefaultDateTime();

  /// Menghasilkan 31-bit stable notification ID dari dedupeKey untuk sistem Android
  int get stableNotificationId {
    return (dedupeKey.hashCode & 0x7FFFFFFF);
  }

  /// Menandakan apakah intent ini terkait dengan aktivitas grup
  bool get isGroupEvent => gid != null && gid!.isNotEmpty;

  NotificationIntent copyWith({
    String? dedupeKey,
    NotificationCategory? category,
    NotificationSource? source,
    String? gid,
    String? groupName,
    String? actorUid,
    String? actorName,
    String? title,
    String? subtitle,
    String? systemTitle,
    String? systemBody,
    int? amount,
    DateTime? createdAt,
    String? payload,
    bool? isImportantDialog,
    Map<String, dynamic>? extra,
  }) {
    return NotificationIntent(
      dedupeKey: dedupeKey ?? this.dedupeKey,
      category: category ?? this.category,
      source: source ?? this.source,
      gid: gid ?? this.gid,
      groupName: groupName ?? this.groupName,
      actorUid: actorUid ?? this.actorUid,
      actorName: actorName ?? this.actorName,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      systemTitle: systemTitle ?? this.systemTitle,
      systemBody: systemBody ?? this.systemBody,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
      isImportantDialog: isImportantDialog ?? this.isImportantDialog,
      extra: extra ?? this.extra,
    );
  }

  /// Factory untuk event grup dari Supabase / Firestore
  factory NotificationIntent.groupEvent({
    required String gid,
    required String groupName,
    required String eventId,
    required String eventType,
    required String actorUid,
    required String actorName,
    required String title,
    required String subtitle,
    required String systemBody,
    int? amount,
    DateTime? createdAt,
    String? payload,
    Map<String, dynamic> extra = const {},
  }) {
    final category = _resolveCategory(eventType);
    final isDialog = category == NotificationCategory.kickedFromGroup ||
        category == NotificationCategory.groupDeleted;

    return NotificationIntent(
      dedupeKey: 'evt:$gid:$eventId',
      category: category,
      source: NotificationSource.listener,
      gid: gid,
      groupName: groupName,
      actorUid: actorUid,
      actorName: actorName,
      title: title,
      subtitle: subtitle,
      systemTitle: isDialog ? 'Putar Jajan' : groupName,
      systemBody: systemBody,
      amount: amount,
      createdAt: createdAt ?? DateTime.now(),
      payload: payload ?? '/group/activity',
      isImportantDialog: isDialog,
      extra: extra,
    );
  }

  /// Factory untuk peringatan budget 80%
  factory NotificationIntent.budget80({
    required String scopeId, // gid atau "local"
    required String sessionId,
    required String groupOrAppName,
    required int remainingBudget,
    required int totalBudget,
    required int spentAmount,
    NotificationSource source = NotificationSource.localBudget,
  }) {
    final percent = totalBudget > 0 ? (spentAmount * 100 ~/ totalBudget) : 80;
    return NotificationIntent(
      dedupeKey: 'bud80:$scopeId:$sessionId',
      category: NotificationCategory.budgetWarning80,
      source: source,
      gid: scopeId == 'local' ? null : scopeId,
      groupName: scopeId == 'local' ? null : groupOrAppName,
      title: 'Sisa Rp${_formatRupiah(remainingBudget)} lagi',
      subtitle: '$percent% terpakai dari Rp${_formatRupiah(totalBudget)}',
      systemTitle: groupOrAppName,
      systemBody:
          'Sisa budget grup tinggal Rp${_formatRupiah(remainingBudget)} ($percent% terpakai).',
      amount: remainingBudget,
      payload: '/catatan',
      isImportantDialog: false,
    );
  }

  /// Factory untuk peringatan budget lewat (over budget)
  factory NotificationIntent.budgetOver({
    required String scopeId,
    required String sessionId,
    required String groupOrAppName,
    required int overAmount,
    required int totalBudget,
    required int totalSpent,
    NotificationSource source = NotificationSource.localBudget,
  }) {
    return NotificationIntent(
      dedupeKey: 'budOver:$scopeId:$sessionId',
      category: NotificationCategory.budgetOver,
      source: source,
      gid: scopeId == 'local' ? null : scopeId,
      groupName: scopeId == 'local' ? null : groupOrAppName,
      title: 'Budget lewat Rp${_formatRupiah(overAmount)}',
      subtitle:
          'Total Rp${_formatRupiah(totalSpent)} dari Rp${_formatRupiah(totalBudget)}',
      systemTitle: groupOrAppName,
      systemBody:
          'Budget grup lewat Rp${_formatRupiah(overAmount)}. Total Rp${_formatRupiah(totalSpent)} dari Rp${_formatRupiah(totalBudget)}.',
      amount: overAmount,
      payload: '/catatan',
      isImportantDialog: false,
    );
  }

  /// Factory untuk pengingat mingguan Jumat malam
  factory NotificationIntent.weeklyReminder({
    required int year,
    required int weekNumber,
  }) {
    return NotificationIntent(
      dedupeKey: 'rem:$year-W$weekNumber',
      category: NotificationCategory.weeklyReminder,
      source: NotificationSource.schedule,
      title: 'Roda lagi nunggu kamu',
      subtitle: 'Jumat malam waktunya putar. Siapa tau dapat 150k.',
      systemTitle: 'Putar Jajan',
      systemBody: 'Jumat malam waktunya putar roda budget kencan.',
      payload: '/roda',
      isImportantDialog: false,
    );
  }

  /// Factory untuk selebrasi streak lolos
  factory NotificationIntent.streakCelebration({
    required int streakWeeks,
    required DateTime date,
  }) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return NotificationIntent(
      dedupeKey: 'streak:$dateStr',
      category: NotificationCategory.streakCelebration,
      source: NotificationSource.localBudget,
      title: 'Streak $streakWeeks minggu!',
      subtitle: 'Kamu lolos budget lagi minggu ini. Pertahankan.',
      systemTitle: 'Putar Jajan',
      systemBody:
          'Kamu lolos budget lagi minggu ini! Streak $streakWeeks minggu bertahan.',
      payload: '/riwayat',
      isImportantDialog: false,
    );
  }

  /// Factory untuk kegagalan sinkronisasi offline
  factory NotificationIntent.syncFailed({
    required String gid,
    required String groupName,
    required int unsyncedCount,
  }) {
    return NotificationIntent(
      dedupeKey: 'syncfail:$gid',
      category: NotificationCategory.syncFailed,
      source: NotificationSource.syncState,
      gid: gid,
      groupName: groupName,
      title: '$unsyncedCount perubahan belum terkirim',
      subtitle: 'Tersimpan aman di HP ini.',
      systemTitle: 'Putar Jajan',
      systemBody:
          '$unsyncedCount catatan belum terkirim. Tersimpan aman di HP ini.',
      payload: '/group/activity',
      isImportantDialog: true,
    );
  }

  /// Factory untuk dikeluarkan dari grup
  factory NotificationIntent.kickedFromGroup({
    required String gid,
    required String groupName,
  }) {
    return NotificationIntent(
      dedupeKey: 'kicked:$gid',
      category: NotificationCategory.kickedFromGroup,
      source: NotificationSource.listener,
      gid: gid,
      groupName: groupName,
      title: 'Kamu dikeluarkan dari grup',
      subtitle: 'Pemilik mengeluarkanmu dari $groupName.',
      systemTitle: 'Putar Jajan',
      systemBody: 'Kamu dikeluarkan dari grup $groupName.',
      payload: '/group/join',
      isImportantDialog: true,
    );
  }

  static NotificationCategory _resolveCategory(String eventType) {
    switch (eventType) {
      case 'expense':
      case 'expense_created':
        return NotificationCategory.expense;
      case 'expense_deleted':
        return NotificationCategory.expenseDeleted;
      case 'spin':
      case 'spin_performed':
      case 'wheel_spin':
      case 'game_result':
      case 'gameresult':
      case 'gameResult':
        return NotificationCategory.spin;
      case 'member_join':
      case 'memberJoin':
      case 'member_joined':
        return NotificationCategory.memberJoin;
      case 'member_leave':
      case 'memberLeave':
      case 'member_left':
        return NotificationCategory.memberLeave;
      case 'session_start':
      case 'sessionStart':
      case 'session_finished':
      case 'budget_changed':
      case 'budgetChanged':
        return NotificationCategory.sessionEnd;
      case 'code_changed':
      case 'codeChanged':
      case 'invite_code_regenerated':
        return NotificationCategory.codeChanged;
      case 'member_removed':
        return NotificationCategory.kickedFromGroup;
      case 'group_deleted':
        return NotificationCategory.groupDeleted;
      default:
        return NotificationCategory.custom;
    }
  }

  static String _formatRupiah(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  DateTime get _now => DateTime.now();

  @override
  bool isAfter(DateTime other) => _now.isAfter(other);
  @override
  bool isBefore(DateTime other) => _now.isBefore(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _now.isAtSameMomentAs(other);
  @override
  int compareTo(DateTime other) => _now.compareTo(other);
  @override
  DateTime add(Duration duration) => _now.add(duration);
  @override
  DateTime subtract(Duration duration) => _now.subtract(duration);
  @override
  Duration difference(DateTime other) => _now.difference(other);
  @override
  int get millisecondsSinceEpoch => _now.millisecondsSinceEpoch;
  @override
  int get microsecondsSinceEpoch => _now.microsecondsSinceEpoch;
  @override
  String get timeZoneName => _now.timeZoneName;
  @override
  Duration get timeZoneOffset => _now.timeZoneOffset;
  @override
  int get year => _now.year;
  @override
  int get month => _now.month;
  @override
  int get day => _now.day;
  @override
  int get hour => _now.hour;
  @override
  int get minute => _now.minute;
  @override
  int get second => _now.second;
  @override
  int get millisecond => _now.millisecond;
  @override
  int get microsecond => _now.microsecond;
  @override
  int get weekday => _now.weekday;
  @override
  bool get isUtc => _now.isUtc;
  @override
  DateTime toLocal() => _now.toLocal();
  @override
  DateTime toUtc() => _now.toUtc();
  @override
  String toIso8601String() => _now.toIso8601String();
}

