import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menangani Autentikasi Pengguna & Profil Anggota Grup (Local-First)
class GroupAuthService {
  static const String keyDisplayName = 'group_display_name';
  static const String keyColorIndex = 'group_member_color_index';
  static const String keyFallbackUid = 'group_fallback_uid';

  final dynamic auth;
  final SharedPreferences prefs;

  String? _cachedDisplayName;
  int _cachedColorIndex = 0;
  String? _cachedUid;

  GroupAuthService({
    this.auth,
    required this.prefs,
  }) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    _cachedDisplayName = prefs.getString(keyDisplayName);
    _cachedColorIndex = prefs.getInt(keyColorIndex) ?? _generateRandomColorIndex();
    _cachedUid = prefs.getString(keyFallbackUid);
    if (_cachedUid == null || _cachedUid!.isEmpty) {
      final fallbackId = 'usr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      _cachedUid = fallbackId;
      prefs.setString(keyFallbackUid, fallbackId);
    }
  }

  static int _generateRandomColorIndex() {
    return Random().nextInt(8); // 0 sampai 7
  }

  /// Validasi nama tampilan (1 sampai 20 karakter, auto-trim)
  static bool isValidDisplayName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= 20;
  }

  /// Nama tampilan saat ini (null jika belum diisi)
  String? get displayName => _cachedDisplayName;

  /// Indeks warna tema profil saat ini (0-7)
  int get colorIndex => _cachedColorIndex;

  /// UID pengguna saat ini (berdasarkan SharedPreferences / Local UUID)
  String? get currentUid => _cachedUid ?? prefs.getString(keyFallbackUid);

  /// Fallback UID dari SharedPreferences jika offline
  String? get fallbackUid => prefs.getString(keyFallbackUid) ?? _cachedUid;

  /// Memeriksa apakah sebuah UID cocok dengan pengguna saat ini
  bool isCurrentUser(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    final curUid = currentUid;
    if (curUid != null && uid == curUid) return true;
    final fbUid = fallbackUid;
    if (fbUid != null && uid == fbUid) return true;
    if (_cachedUid != null && uid == _cachedUid) return true;
    return false;
  }

  /// Apakah pengguna sudah melengkapi nama tampilan
  bool get hasCompletedProfile =>
      _cachedDisplayName != null && isValidDisplayName(_cachedDisplayName!);

  /// Memastikan pengguna memiliki identitas UID yang valid dan tersimpan
  Future<String> ensureSignedIn() async {
    if (_cachedUid == null || _cachedUid!.isEmpty) {
      _cachedUid = prefs.getString(keyFallbackUid);
    }
    if (_cachedUid == null || _cachedUid!.isEmpty) {
      final fallbackId = 'usr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      _cachedUid = fallbackId;
      await prefs.setString(keyFallbackUid, fallbackId);
    }
    return _cachedUid!;
  }

  /// Menyimpan nama tampilan baru
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (!isValidDisplayName(trimmed)) {
      throw ArgumentError('Nama tampilan harus 1 hingga 20 karakter.');
    }
    _cachedDisplayName = trimmed;
    await prefs.setString(keyDisplayName, trimmed);
  }

  /// Menyimpan indeks warna avatar (0-7)
  Future<void> setColorIndex(int index) async {
    if (index < 0 || index > 7) {
      throw RangeError('Color index harus antara 0 dan 7');
    }
    _cachedColorIndex = index;
    await prefs.setInt(keyColorIndex, index);
  }
}

/// Cache global SharedPreferences sebagai failsafe
SharedPreferences? _globalSharedPreferences;

/// Setter untuk mendaftarkan instance SharedPreferences global saat startup
void setGlobalSharedPreferences(SharedPreferences prefs) {
  _globalSharedPreferences = prefs;
}

/// Provider SharedPreferences umum (di-override di main.dart atau memakai cache global)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  if (_globalSharedPreferences != null) {
    return _globalSharedPreferences!;
  }
  throw UnimplementedError('SharedPreferences belum diinisialisasi');
});

/// Provider GroupAuthService
final groupAuthServiceProvider = Provider<GroupAuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GroupAuthService(auth: null, prefs: prefs);
});
