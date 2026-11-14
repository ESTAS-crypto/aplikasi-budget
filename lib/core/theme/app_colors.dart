import 'package:flutter/material.dart';
import 'putar_theme.dart';

/// Palet warna resmi tema bawaan "Pasar Malam" (diambil dari `PutarTheme.pasarMalam`).
/// Widget di UI wajib membaca `context.putarTheme` agar merespons pergantian tema secara live.
class AppColors {
  AppColors._();

  // Dasar & Teks (mengacu ke PutarTheme.pasarMalam)
  static const Color ink = PutarTheme.kPasarMalamInk;
  static const Color cream = PutarTheme.kPasarMalamCream;
  static const Color surface = PutarTheme.kPasarMalamSurface;
  static const Color textSecondary = PutarTheme.kPasarMalamTextSecondary;
  static const Color disabled = PutarTheme.kPasarMalamDisabled;

  // Warna Aksen & Irisan Roda (8 warna resmi Pasar Malam)
  static const Color tomat = PutarTheme.kPasarMalamTomat;
  static const Color jeruk = PutarTheme.kPasarMalamJeruk;
  static const Color matahari = PutarTheme.kPasarMalamMatahari;
  static const Color mint = PutarTheme.kPasarMalamMint;
  static const Color langit = PutarTheme.kPasarMalamLangit;
  static const Color lavender = PutarTheme.kPasarMalamLavender;
  static const Color permen = PutarTheme.kPasarMalamPermen;
  static const Color lemon = PutarTheme.kPasarMalamLemon;

  /// 8 Warna berurutan untuk irisan roda
  static List<Color> get wheelPalette => PutarTheme.pasarMalam.wheelPalette;

  /// Mengambil warna roda berdasarkan indeks
  static Color getWheelColor(int index) {
    return PutarTheme.pasarMalam.getWheelColor(index);
  }

  /// Warna status budget
  /// Aman (<70%) = Mint, Waspada (70-90%) = Matahari, Bahaya (>90%) = Tomat
  static Color getBudgetStatusColor(double percentage) {
    return PutarTheme.pasarMalam.getBudgetStatusColor(percentage);
  }
}
