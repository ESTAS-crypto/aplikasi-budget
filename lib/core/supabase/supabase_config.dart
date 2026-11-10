import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Konfigurasi resmi Supabase untuk Putar Jajan
class SupabaseConfig {
  SupabaseConfig._();

  static const String projectUrl = 'https://ftbrcktypbwfuvfccxec.supabase.co';
  static const String publishableKey = 'sb_publishable_BsHfvh3Pla3e-QDb71wHSg_GQjpwE5Q';

  /// Inisialisasi Supabase di aplikasi Flutter
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: projectUrl,
        publishableKey: publishableKey,
        debug: kDebugMode,
      );
      debugPrint('[SupabaseConfig] Berhasil terhubung ke Supabase ($projectUrl)');
    } catch (e) {
      debugPrint('[SupabaseConfig] Inisialisasi Supabase gagal: $e');
    }
  }

  /// Client Supabase aktif
  static SupabaseClient get client => Supabase.instance.client;
}

