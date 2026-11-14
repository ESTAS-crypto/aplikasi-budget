import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_intent.dart';

/// Catatan klaim notifikasi di penyimpanan lokal
@immutable
class NotifiedClaimRecord {
  final String dedupeKey;
  final NotificationSurface surface;
  final DateTime at;
  final NotificationDropReason reason;

  const NotifiedClaimRecord({
    required this.dedupeKey,
    required this.surface,
    required this.at,
    this.reason = NotificationDropReason.none,
  });

  Map<String, dynamic> toMap() {
    return {
      'dedupeKey': dedupeKey,
      'surface': surface.name,
      'at': at.toIso8601String(),
      'reason': reason.name,
    };
  }

  factory NotifiedClaimRecord.fromMap(Map<String, dynamic> map) {
    return NotifiedClaimRecord(
      dedupeKey: map['dedupeKey'] as String? ?? '',
      surface: NotificationSurface.values.firstWhere(
        (e) => e.name == map['surface'],
        orElse: () => NotificationSurface.dropped,
      ),
      at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      reason: NotificationDropReason.values.firstWhere(
        (e) => e.name == map['reason'],
        orElse: () => NotificationDropReason.none,
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NotifiedClaimRecord.fromJson(String jsonStr) {
    return NotifiedClaimRecord.fromMap(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }
}

/// Kontrak penyimpanan klaim atomik (anti-double)
abstract class NotifiedClaimStore {
  /// Mencoba mengklaim dedupeKey secara atomik.
  /// Mengembalikan true jika berhasil diklaim (belum pernah ada).
  /// Mengembalikan false jika sudah pernah diklaim sebelumnya (duplicate).
  Future<bool> tryClaim({
    required String dedupeKey,
    required NotificationSurface surface,
    NotificationDropReason reason = NotificationDropReason.none,
  });

  /// Cek apakah dedupeKey sudah pernah diklaim
  Future<bool> isClaimed(String dedupeKey);

  /// Mengambil data klaim berdasarkan key
  Future<NotifiedClaimRecord?> getClaim(String dedupeKey);

  /// Membersihkan data klaim yang usang (> 30 hari)
  Future<void> pruneOldClaims([Duration maxAge = const Duration(days: 30)]);

  /// Mengambil daftar klaim terbaru (untuk observabilitas / layar debug)
  Future<List<NotifiedClaimRecord>> getRecentClaims([int limit = 50]);

  /// Mendapatkan watermark waktu event terakhir yang disampaikan per grup
  Future<DateTime?> getLastDeliveredEventAt(String gid);

  /// Memperbarui watermark waktu event terakhir yang disampaikan per grup
  Future<void> setLastDeliveredEventAt(String gid, DateTime timestamp);

  /// Menghapus watermark grup jika terdeteksi corrupt (mis. timestamp masa depan akibat clock skew)
  Future<void> clearLastDeliveredEventAt(String gid);

  /// Menghapus seluruh data klaim (untuk testing / reset)
  Future<void> clearAll();
}

/// Implementasi In-Memory (cepat untuk testing dan lingkungan terisolasi)
class InMemoryNotifiedClaimStore implements NotifiedClaimStore {
  final Map<String, NotifiedClaimRecord> _records = {};
  final Map<String, DateTime> _watermarks = {};

  @override
  Future<DateTime?> getLastDeliveredEventAt(String gid) async {
    return _watermarks[gid];
  }

  @override
  Future<void> setLastDeliveredEventAt(String gid, DateTime timestamp) async {
    final current = _watermarks[gid];
    if (current == null || timestamp.isAfter(current)) {
      _watermarks[gid] = timestamp;
    }
  }

  @override
  Future<void> clearLastDeliveredEventAt(String gid) async {
    _watermarks.remove(gid);
  }

  @override
  Future<bool> tryClaim({
    required String dedupeKey,
    required NotificationSurface surface,
    NotificationDropReason reason = NotificationDropReason.none,
  }) async {
    if (_records.containsKey(dedupeKey)) {
      return false; // Sudah pernah diklaim sebelumnya!
    }
    _records[dedupeKey] = NotifiedClaimRecord(
      dedupeKey: dedupeKey,
      surface: surface,
      at: DateTime.now(),
      reason: reason,
    );
    return true;
  }

  @override
  Future<bool> isClaimed(String dedupeKey) async {
    return _records.containsKey(dedupeKey);
  }

  @override
  Future<NotifiedClaimRecord?> getClaim(String dedupeKey) async {
    return _records[dedupeKey];
  }

  @override
  Future<void> pruneOldClaims([
    Duration maxAge = const Duration(days: 30),
  ]) async {
    final threshold = DateTime.now().subtract(maxAge);
    _records.removeWhere((_, record) => record.at.isBefore(threshold));
  }

  @override
  Future<List<NotifiedClaimRecord>> getRecentClaims([int limit = 50]) async {
    final list = _records.values.toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list.take(limit).toList();
  }

  @override
  Future<void> clearAll() async {
    _records.clear();
    _watermarks.clear();
  }
}

/// Implementasi SharedPreferences (persisten lintas restart aplikasi)
class SharedPrefsNotifiedClaimStore implements NotifiedClaimStore {
  static const String _keyPrefix = 'notif_claim_v1:';
  static const String _indexKey = 'notif_claims_index_v1';
  static const String _watermarkPrefix = 'notif_watermark_v1:';

  final SharedPreferences? _customPrefs;

  SharedPrefsNotifiedClaimStore([this._customPrefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _customPrefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<DateTime?> getLastDeliveredEventAt(String gid) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString('$_watermarkPrefix$gid');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> setLastDeliveredEventAt(String gid, DateTime timestamp) async {
    final prefs = await _getPrefs();
    final current = await getLastDeliveredEventAt(gid);
    if (current == null || timestamp.isAfter(current)) {
      await prefs.setString('$_watermarkPrefix$gid', timestamp.toIso8601String());
    }
  }

  @override
  Future<void> clearLastDeliveredEventAt(String gid) async {
    final prefs = await _getPrefs();
    await prefs.remove('$_watermarkPrefix$gid');
  }

  @override
  Future<bool> tryClaim({
    required String dedupeKey,
    required NotificationSurface surface,
    NotificationDropReason reason = NotificationDropReason.none,
  }) async {
    final prefs = await _getPrefs();
    final storageKey = '$_keyPrefix$dedupeKey';

    // Cek apakah sudah ada klaim
    if (prefs.containsKey(storageKey)) {
      return false;
    }

    final record = NotifiedClaimRecord(
      dedupeKey: dedupeKey,
      surface: surface,
      at: DateTime.now(),
      reason: reason,
    );

    // Tulis klaim
    await prefs.setString(storageKey, record.toJson());

    // Update daftar indeks untuk kemudahan iterasi & pruning
    final indexList = prefs.getStringList(_indexKey) ?? [];
    if (!indexList.contains(dedupeKey)) {
      indexList.insert(0, dedupeKey);
      // Batasi indeks maksimal 1000 entri terbaru
      if (indexList.length > 1000) {
        final removed = indexList.removeLast();
        await prefs.remove('$_keyPrefix$removed');
      }
      await prefs.setStringList(_indexKey, indexList);
    }

    return true;
  }

  @override
  Future<bool> isClaimed(String dedupeKey) async {
    final prefs = await _getPrefs();
    return prefs.containsKey('$_keyPrefix$dedupeKey');
  }

  @override
  Future<NotifiedClaimRecord?> getClaim(String dedupeKey) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString('$_keyPrefix$dedupeKey');
    if (raw == null) return null;
    try {
      return NotifiedClaimRecord.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> pruneOldClaims([
    Duration maxAge = const Duration(days: 30),
  ]) async {
    final prefs = await _getPrefs();
    final indexList = prefs.getStringList(_indexKey) ?? [];
    final threshold = DateTime.now().subtract(maxAge);
    final validKeys = <String>[];

    for (final key in indexList) {
      final raw = prefs.getString('$_keyPrefix$key');
      if (raw == null) continue;
      try {
        final record = NotifiedClaimRecord.fromJson(raw);
        if (record.at.isBefore(threshold)) {
          await prefs.remove('$_keyPrefix$key');
        } else {
          validKeys.add(key);
        }
      } catch (_) {
        await prefs.remove('$_keyPrefix$key');
      }
    }

    await prefs.setStringList(_indexKey, validKeys);
  }

  @override
  Future<List<NotifiedClaimRecord>> getRecentClaims([int limit = 50]) async {
    final prefs = await _getPrefs();
    final indexList = prefs.getStringList(_indexKey) ?? [];
    final result = <NotifiedClaimRecord>[];

    for (final key in indexList.take(limit)) {
      final raw = prefs.getString('$_keyPrefix$key');
      if (raw != null) {
        try {
          result.add(NotifiedClaimRecord.fromJson(raw));
        } catch (_) {}
      }
    }

    return result;
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    final indexList = prefs.getStringList(_indexKey) ?? [];
    for (final key in indexList) {
      await prefs.remove('$_keyPrefix$key');
    }
    await prefs.remove(_indexKey);
  }
}

