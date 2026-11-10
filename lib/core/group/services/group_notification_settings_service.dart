import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'group_auth_service.dart';

/// Model Pengaturan Notifikasi Grup per GID (Layar 44)
class GroupNotificationSettings {
  final bool isMuted;
  final DateTime? mutedUntil;
  final String muteDuration; // '1_jam', '8_jam', 'sampai_kunyalakan'
  final bool notifyExpenses;
  final bool notifySpin;
  final bool notifyWarning80;
  final bool notifyDateComplete;
  final bool notifyMembers;

  const GroupNotificationSettings({
    this.isMuted = false,
    this.mutedUntil,
    this.muteDuration = '1_jam',
    this.notifyExpenses = true,
    this.notifySpin = true,
    this.notifyWarning80 = true,
    this.notifyDateComplete = true,
    this.notifyMembers = false,
  });

  bool get isCurrentlyMuted {
    if (!isMuted) return false;
    if (mutedUntil == null) return true;
    return DateTime.now().isBefore(mutedUntil!);
  }

  String get mutedUntilFormatted {
    if (!isCurrentlyMuted) return '';
    if (mutedUntil == null) return 'sampai dinyalakan';
    final h = mutedUntil!.hour.toString().padLeft(2, '0');
    final m = mutedUntil!.minute.toString().padLeft(2, '0');
    return '$h.$m';
  }

  GroupNotificationSettings copyWith({
    bool? isMuted,
    DateTime? mutedUntil,
    String? muteDuration,
    bool? notifyExpenses,
    bool? notifySpin,
    bool? notifyWarning80,
    bool? notifyDateComplete,
    bool? notifyMembers,
    bool clearMutedUntil = false,
  }) {
    return GroupNotificationSettings(
      isMuted: isMuted ?? this.isMuted,
      mutedUntil: clearMutedUntil ? null : (mutedUntil ?? this.mutedUntil),
      muteDuration: muteDuration ?? this.muteDuration,
      notifyExpenses: notifyExpenses ?? this.notifyExpenses,
      notifySpin: notifySpin ?? this.notifySpin,
      notifyWarning80: notifyWarning80 ?? this.notifyWarning80,
      notifyDateComplete: notifyDateComplete ?? this.notifyDateComplete,
      notifyMembers: notifyMembers ?? this.notifyMembers,
    );
  }
}

/// Service untuk membaca dan menyimpan pengaturan notifikasi per grup
class GroupNotificationSettingsService {
  final SharedPreferences prefs;

  GroupNotificationSettingsService(this.prefs);

  static String _keyMuted(String gid) => 'group_notif_${gid}_muted';
  static String _keyMutedUntil(String gid) => 'group_notif_${gid}_muted_until';
  static String _keyMuteDuration(String gid) => 'group_notif_${gid}_mute_duration';
  static String _keyExpenses(String gid) => 'group_notif_${gid}_expenses';
  static String _keySpin(String gid) => 'group_notif_${gid}_spin';
  static String _keyWarning(String gid) => 'group_notif_${gid}_warning80';
  static String _keyDateComplete(String gid) => 'group_notif_${gid}_date_complete';
  static String _keyMembers(String gid) => 'group_notif_${gid}_members';

  GroupNotificationSettings getSettings(String gid) {
    final muted = prefs.getBool(_keyMuted(gid)) ?? false;
    final untilMs = prefs.getInt(_keyMutedUntil(gid));
    final duration = prefs.getString(_keyMuteDuration(gid)) ?? '1_jam';
    final mutedUntil = untilMs != null ? DateTime.fromMillisecondsSinceEpoch(untilMs) : null;

    return GroupNotificationSettings(
      isMuted: muted,
      mutedUntil: mutedUntil,
      muteDuration: duration,
      notifyExpenses: prefs.getBool(_keyExpenses(gid)) ?? true,
      notifySpin: prefs.getBool(_keySpin(gid)) ?? true,
      notifyWarning80: prefs.getBool(_keyWarning(gid)) ?? true,
      notifyDateComplete: prefs.getBool(_keyDateComplete(gid)) ?? true,
      notifyMembers: prefs.getBool(_keyMembers(gid)) ?? false,
    );
  }

  Future<void> saveSettings(String gid, GroupNotificationSettings settings) async {
    await prefs.setBool(_keyMuted(gid), settings.isMuted);
    if (settings.mutedUntil != null) {
      await prefs.setInt(_keyMutedUntil(gid), settings.mutedUntil!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_keyMutedUntil(gid));
    }
    await prefs.setString(_keyMuteDuration(gid), settings.muteDuration);
    await prefs.setBool(_keyExpenses(gid), settings.notifyExpenses);
    await prefs.setBool(_keySpin(gid), settings.notifySpin);
    await prefs.setBool(_keyWarning(gid), settings.notifyWarning80);
    await prefs.setBool(_keyDateComplete(gid), settings.notifyDateComplete);
    await prefs.setBool(_keyMembers(gid), settings.notifyMembers);
  }
}

/// Provider GroupNotificationSettingsService
final groupNotificationSettingsServiceProvider = Provider<GroupNotificationSettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GroupNotificationSettingsService(prefs);
});

/// StateNotifier untuk memantau dan mengubah pengaturan notifikasi grup aktif
class ActiveGroupNotificationSettingsNotifier extends StateNotifier<GroupNotificationSettings> {
  final GroupNotificationSettingsService service;
  final String gid;

  ActiveGroupNotificationSettingsNotifier(this.service, this.gid)
      : super(service.getSettings(gid));

  Future<void> setMuted(bool val, {String? duration}) async {
    final dur = duration ?? state.muteDuration;
    DateTime? until;
    if (val) {
      if (dur == '1_jam') {
        until = DateTime.now().add(const Duration(hours: 1));
      } else if (dur == '8_jam') {
        until = DateTime.now().add(const Duration(hours: 8));
      } else {
        until = null;
      }
    }
    state = state.copyWith(
      isMuted: val,
      mutedUntil: until,
      muteDuration: dur,
      clearMutedUntil: until == null,
    );
    await service.saveSettings(gid, state);
  }

  Future<void> setMuteDuration(String dur) async {
    DateTime? until;
    if (dur == '1_jam') {
      until = DateTime.now().add(const Duration(hours: 1));
    } else if (dur == '8_jam') {
      until = DateTime.now().add(const Duration(hours: 8));
    } else {
      until = null;
    }
    state = state.copyWith(
      isMuted: true,
      mutedUntil: until,
      muteDuration: dur,
      clearMutedUntil: until == null,
    );
    await service.saveSettings(gid, state);
  }

  Future<void> toggleExpenses(bool val) async {
    state = state.copyWith(notifyExpenses: val);
    await service.saveSettings(gid, state);
  }

  Future<void> setNotifyExpenses(bool val) => toggleExpenses(val);

  Future<void> toggleSpin(bool val) async {
    state = state.copyWith(notifySpin: val);
    await service.saveSettings(gid, state);
  }

  Future<void> setNotifySpin(bool val) => toggleSpin(val);

  Future<void> toggleWarning80(bool val) async {
    state = state.copyWith(notifyWarning80: val);
    await service.saveSettings(gid, state);
  }

  Future<void> setNotifyWarning80(bool val) => toggleWarning80(val);

  Future<void> toggleDateComplete(bool val) async {
    state = state.copyWith(notifyDateComplete: val);
    await service.saveSettings(gid, state);
  }

  Future<void> setNotifyDateComplete(bool val) => toggleDateComplete(val);

  Future<void> toggleMembers(bool val) async {
    state = state.copyWith(notifyMembers: val);
    await service.saveSettings(gid, state);
  }

  Future<void> setNotifyMembers(bool val) => toggleMembers(val);
}

/// Family StateNotifierProvider untuk pengaturan notifikasi grup per gid
final groupNotificationSettingsProvider = StateNotifierProvider.family<
    ActiveGroupNotificationSettingsNotifier, GroupNotificationSettings, String>((ref, gid) {
  final service = ref.watch(groupNotificationSettingsServiceProvider);
  return ActiveGroupNotificationSettingsNotifier(service, gid);
});
