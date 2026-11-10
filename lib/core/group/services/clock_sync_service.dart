import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Layanan estimasi selisih jam lokal perangkat dengan jam server (Clock Synchronization).
/// Memastikan semua HP memulai animasi putaran pada waktu yang sama persis (selisih < 300ms).
class ClockSyncService {
  int _offsetMs = 0;
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  /// Selisih jam server terhadap jam lokal dalam milidetik (serverTime - localTime)
  int get offsetMs => _offsetMs;

  /// Nilai waktu server perkiraan saat ini dalam epoch milidetik
  int get serverNowMs => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  /// Objek DateTime server perkiraan saat ini
  DateTime get serverNow => DateTime.fromMillisecondsSinceEpoch(serverNowMs);

  @visibleForTesting
  void setOffsetForTesting(int offsetMs) {
    _offsetMs = offsetMs;
  }

  /// Memulai sinkronisasi periodik (tiap 5 menit sesuai F2)
  void startPeriodicSync(
    String gid, {
    dynamic firestore,
    dynamic supabase,
    String? uid,
  }) {
    _periodicSyncTimer?.cancel();
    syncClock(gid, firestore: firestore, supabase: supabase, uid: uid);
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncClock(gid, firestore: firestore, supabase: supabase, uid: uid);
    });
  }

  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Memperkirakan selisih jam server (offset) dengan mengambil median dari 3 pengukuran
  Future<int> syncClock(
    String gid, {
    dynamic firestore,
    dynamic supabase,
    String? uid,
  }) async {
    if (_isSyncing) return _offsetMs;
    _isSyncing = true;
    try {
      final samples = <int>[];

      for (int i = 0; i < 3; i++) {
        final tStart = DateTime.now().millisecondsSinceEpoch;
        int? serverTimeMs;

        // 1. Coba via Firestore jika tersedia
        if (firestore != null && uid != null && uid.isNotEmpty) {
          try {
            final docRef = firestore
                .collection('groups')
                .doc(gid)
                .collection('_clock_sync')
                .doc(uid);
            await docRef.set({
              'clientT': tStart,
              't': DateTime.now().toUtc().millisecondsSinceEpoch,
            });
            final snap = await docRef.get();
            final data = snap.data();
            if (data != null && data['t'] != null) {
              final rawT = data['t'];
              if (rawT is num) {
                serverTimeMs = rawT.toInt();
              } else if (rawT is DateTime) {
                serverTimeMs = rawT.millisecondsSinceEpoch;
              } else {
                try {
                  serverTimeMs = (rawT as dynamic).millisecondsSinceEpoch;
                } catch (_) {}
              }
            }
          } catch (e) {
            debugPrint('[ClockSync] Firestore ping error: $e');
          }
        }

        // 2. Fallback via Supabase jika Firestore tidak ada / gagal
        if (serverTimeMs == null && supabase != null) {
          try {
            final res = await supabase.rpc('get_server_time');
            if (res != null) {
              serverTimeMs = DateTime.tryParse(res.toString())?.millisecondsSinceEpoch;
            }
          } catch (_) {}
        }

        final tEnd = DateTime.now().millisecondsSinceEpoch;
        final roundTrip = tEnd - tStart;

        if (serverTimeMs != null) {
          // Estimasi waktu server saat tEnd: serverTimeMs + (roundTrip / 2)
          final serverEstimatedAtEnd = serverTimeMs + (roundTrip ~/ 2);
          final offsetSample = serverEstimatedAtEnd - tEnd;
          samples.add(offsetSample);
        }
      }

      if (samples.isNotEmpty) {
        samples.sort();
        final medianOffset = samples[samples.length ~/ 2];
        _offsetMs = medianOffset;
        debugPrint('[ClockSync] Server clock offset synced: ${_offsetMs}ms (median of $samples)');
      }
    } catch (e) {
      debugPrint('[ClockSync] syncClock exception: $e');
    } finally {
      _isSyncing = false;
    }

    return _offsetMs;
  }

  void dispose() {
    stopPeriodicSync();
  }
}

/// Provider global untuk ClockSyncService
final clockSyncServiceProvider = Provider<ClockSyncService>((ref) {
  final service = ClockSyncService();
  ref.onDispose(() => service.dispose());
  return service;
});

