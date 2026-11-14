import 'dart:async';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/notification_service.dart';
import '../group/services/group_auth_service.dart';
import '../utils/sound_service.dart';
import 'app_icon_service.dart';
import 'putar_theme.dart';

/// Kunci penyimpanan lokal untuk tema aplikasi aktif.
const String kThemePreferenceKey = 'pj_theme_id';

/// Membaca tema awal secara sinkron dari `SharedPreferences` sebelum `runApp()`.
PutarTheme readInitialThemeFromPrefs(SharedPreferences? prefs) {
  final savedId = prefs?.getString(kThemePreferenceKey);
  return PutarTheme.byId(savedId);
}

/// Provider untuk tema awal yang sudah dimuat sebelum `runApp()`.
/// Di-override di `main.dart` menggunakan nilai hasil `readInitialThemeFromPrefs(prefs)`.
final initialThemeProvider = Provider<PutarTheme>((ref) {
  try {
    return readInitialThemeFromPrefs(ref.watch(sharedPreferencesProvider));
  } catch (_) {
    return PutarTheme.pasarMalam;
  }
});

/// Hook opsional agar modul lain (audio/notifikasi pada tahap T4) bereaksi saat tema berganti.
typedef ThemeChangeCallback = FutureOr<void> Function(PutarTheme theme);

/// Sinyal event transisi tema agar overlay animasi global memuai halus dari titik sentuh.
@immutable
class ThemeTransitionSignal {
  const ThemeTransitionSignal({
    required this.fromTheme,
    required this.toTheme,
    required this.seq,
    this.origin,
  });

  final PutarTheme fromTheme;
  final PutarTheme toTheme;
  final int seq;
  final Offset? origin;
}

/// Controller Riverpod untuk mengelola dan menyimpan pilihan tema aplikasi.
class ThemeController extends StateNotifier<PutarTheme> {
  final SharedPreferences? _prefs;
  final ThemeChangeCallback? _onThemeChanged;
  final ValueNotifier<ThemeTransitionSignal?> _transitionSignal =
      ValueNotifier<ThemeTransitionSignal?>(null);
  int _transitionSeq = 0;

  /// Listenable sinyal perpindahan tema terakhir untuk overlay transisi visual.
  ValueListenable<ThemeTransitionSignal?> get transitionSignalListenable =>
      _transitionSignal;

  ThemeController({
    required PutarTheme initialTheme,
    SharedPreferences? prefs,
    ThemeChangeCallback? onThemeChanged,
  })  : _prefs = prefs, // ignore: prefer_initializing_formals
        _onThemeChanged = onThemeChanged, // ignore: prefer_initializing_formals
        super(initialTheme);

  /// Mengganti tema secara live berdasarkan id dan menyimpannya ke `SharedPreferences`.
  Future<void> setThemeById(String themeId, {Offset? origin}) async {
    final next = PutarTheme.byId(themeId);
    if (next.id == state.id) return;

    final prev = state;
    _transitionSignal.value = ThemeTransitionSignal(
      fromTheme: prev,
      toTheme: next,
      seq: ++_transitionSeq,
      origin: origin,
    );

    state = next;
    await _persistThemeId(next.id);
    if (_onThemeChanged != null) {
      try {
        await _onThemeChanged(next);
      } catch (e) {
        debugPrint('[ThemeController] onThemeChanged error: $e');
      }
    }
  }

  /// Mengganti tema secara live langsung dengan instance `PutarTheme`.
  Future<void> setTheme(PutarTheme theme, {Offset? origin}) async {
    await setThemeById(theme.id, origin: origin);
  }

  Future<void> _persistThemeId(String id) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(kThemePreferenceKey, id);
    } catch (e) {
      debugPrint('[ThemeController] Persist theme failed: $e');
    }
  }

  @override
  void dispose() {
    _transitionSignal.dispose();
    super.dispose();
  }
}

/// Efek samping saat tema aplikasi berpindah: ganti paket suara aktif,
/// perbarui channel notifikasi tema, dan selaraskan ikon launcher aplikasi.
Future<void> applyThemeSideEffects(
  PutarTheme theme, {
  SharedPreferences? prefs,
}) async {
  try {
    await SoundService.instance.setSoundPack(theme.soundPackId);
  } catch (e) {
    debugPrint('[ThemeController] SoundService setSoundPack error: $e');
  }
  try {
    await NotificationService.instance.applyTheme(theme, prefs: prefs);
  } catch (e) {
    debugPrint('[ThemeController] NotificationService applyTheme error: $e');
  }
  unawaited(AppIconService.instance.applyTheme(theme));
}

/// Provider global `ThemeController` (aktif untuk seluruh `MaterialApp`).
final themeControllerProvider =
    StateNotifierProvider<ThemeController, PutarTheme>((ref) {
  final initial = ref.watch(initialThemeProvider);
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {}

  return ThemeController(
    initialTheme: initial,
    prefs: prefs,
    onThemeChanged: (theme) => applyThemeSideEffects(theme, prefs: prefs),
  );
});
