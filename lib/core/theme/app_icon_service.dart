import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'putar_theme.dart';

/// Mengelola sinkronisasi ikon launcher Android & ikon TaskDescription
/// sesuai tema aktif (`pasar_malam` <-> `kucing_manis`).
class AppIconService {
  AppIconService._();

  static final AppIconService instance = AppIconService._();

  static const MethodChannel _channel = MethodChannel(
    'com.putarjajan.putar_jajan/app_icon',
  );

  String? _lastRequestedThemeId;
  String? _lastAppliedThemeId;

  @visibleForTesting
  String? get lastRequestedThemeId => _lastRequestedThemeId;

  @visibleForTesting
  String? get lastAppliedThemeId => _lastAppliedThemeId;

  @visibleForTesting
  void resetForTest() {
    _lastRequestedThemeId = null;
    _lastAppliedThemeId = null;
  }

  /// Menyelaraskan ikon aplikasi di launcher Android dengan [theme].
  Future<bool> applyTheme(PutarTheme theme, {bool force = false}) {
    return setLauncherTheme(theme.id, force: force);
  }

  /// Meminta layer Android menukar ikon launcher ke [themeId].
  Future<bool> setLauncherTheme(String themeId, {bool force = false}) async {
    final normalizedId = PutarTheme.byId(themeId).id;
    _lastRequestedThemeId = normalizedId;

    if (kIsWeb) return false;
    if (!force && _lastAppliedThemeId == normalizedId) {
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'setLauncherTheme',
        <String, dynamic>{'themeId': normalizedId},
      );
      _lastAppliedThemeId = normalizedId;
      return result ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('[AppIconService] setLauncherTheme error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AppIconService] unexpected error: $e');
      return false;
    }
  }
}
