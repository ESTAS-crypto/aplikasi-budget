import 'dart:async';
import 'package:flutter/foundation.dart';

/// 5 Status Sinkronisasi Grup sesuai UPDATE_2_GRUP_ONLINE_OFFLINE.md
enum SyncState {
  tersinkron('Tersinkron', 'Semua data telah tersimpan di server.'),
  menunggu('Menunggu', 'Ada catatan tersimpan di HP ini, menunggu jaringan untuk terkirim.'),
  menyinkronkan('Menyinkronkan', 'Sedang mengirimkan perubahan terbaru ke server...'),
  offline('Offline', 'Tidak ada sambungan internet. Menampilkan data tersimpan di HP ini.'),
  gagal('Gagal sinkron', 'Gagal mengirim ke server. Ketuk untuk coba lagi.');

  final String label;
  final String description;
  const SyncState(this.label, this.description);
}

/// Helper penurunan status murni (pure function) untuk kemudahan pengujian unit
class SyncStateResolver {
  SyncStateResolver._();

  static SyncState resolve({
    required bool isOnline,
    required bool hasPendingWrites,
    required bool hasWriteError,
  }) {
    if (hasWriteError) {
      return SyncState.gagal;
    }
    if (!isOnline) {
      return hasPendingWrites ? SyncState.menunggu : SyncState.offline;
    }
    if (hasPendingWrites) {
      return SyncState.menyinkronkan;
    }
    return SyncState.tersinkron;
  }
}

/// Service pemantau status koneksi dan antrean sinkronisasi dengan debounce 1,5 detik
class SyncStateService extends ChangeNotifier {
  SyncState _rawState = SyncState.tersinkron;
  SyncState _debouncedState = SyncState.tersinkron;
  bool _isStripVisible = false;

  Timer? _debounceTimer;
  Timer? _hideTimer;

  SyncState get state => _debouncedState;
  SyncState get rawState => _rawState;
  bool get isStripVisible => _isStripVisible;

  /// Memperbarui kondisi jaringan, pending writes, dan error tulis
  void updateConditions({
    required bool isOnline,
    required bool hasPendingWrites,
    bool hasWriteError = false,
  }) {
    final newState = SyncStateResolver.resolve(
      isOnline: isOnline,
      hasPendingWrites: hasPendingWrites,
      hasWriteError: hasWriteError,
    );

    if (_rawState == newState) return;
    _rawState = newState;

    if (newState == SyncState.tersinkron) {
      // Jika kembali tersinkron: batalkan debounce muncul strip
      _debounceTimer?.cancel();

      if (_isStripVisible) {
        // Tampilkan 'Tersinkron' selama 2 detik sebelum menghilang dengan fade
        _debouncedState = SyncState.tersinkron;
        notifyListeners();

        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(milliseconds: 2000), () {
          _isStripVisible = false;
          notifyListeners();
        });
      }
    } else {
      // Keadaan bukan tersinkron: tahan 1,5 detik (debounce anti-kedip) sebelum strip muncul
      _hideTimer?.cancel();
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        _debouncedState = _rawState;
        _isStripVisible = true;
        notifyListeners();
      });
    }
  }

  /// Reset paksa saat retry
  void retry() {
    _rawState = SyncState.menyinkronkan;
    _debouncedState = SyncState.menyinkronkan;
    _isStripVisible = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }
}

