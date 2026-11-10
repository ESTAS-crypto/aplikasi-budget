import 'package:flutter/material.dart';

/// Palet warna resmi "Putar Jajan" (Neo-Brutalist Playful).
class AppColors {
  AppColors._();

  // Dasar & Teks
  static const Color ink = Color(0xFF22163A);         // Teks utama, garis, border, bayangan keras
  static const Color cream = Color(0xFFFFF3D6);       // Latar belakang utama
  static const Color surface = Color(0xFFFFFFFF);     // Permukaan kartu / dialog / sheet
  static const Color textSecondary = Color(0xFF5B4B7A); // Teks sekunder
  static const Color disabled = Color(0xFF6B5B8A);    // Teks nonaktif / placeholder

  // Warna Aksen & Irisan Roda (8 warna resmi)
  static const Color tomat = Color(0xFFFF6B5A);       // Tomat (Aksen bahaya / tombol utama / irisan 1)
  static const Color jeruk = Color(0xFFFF9F1C);       // Jeruk (Irisan 2)
  static const Color matahari = Color(0xFFFFD23F);    // Matahari (Waspada / highlight / irisan 3)
  static const Color mint = Color(0xFF3DDBB0);        // Mint (Aman / lolos / irisan 4)
  static const Color langit = Color(0xFF6FB1FF);      // Langit (Irisan 5)
  static const Color lavender = Color(0xFFB8A4FF);    // Lavender (Chip tanggal / irisan 6)
  static const Color permen = Color(0xFFFF8FC0);      // Permen (Irisan 7)
  static const Color lemon = Color(0xFFB8E986);       // Lemon (Irisan 8)

  /// 8 Warna berurutan untuk irisan roda
  static const List<Color> wheelPalette = [
    tomat,
    jeruk,
    matahari,
    mint,
    langit,
    lavender,
    permen,
    lemon,
  ];

  /// Mengambil warna roda berdasarkan indeks
  static Color getWheelColor(int index) {
    return wheelPalette[index % wheelPalette.length];
  }

  /// Warna status budget
  /// Aman (<70%) = Mint
  /// Waspada (70-90%) = Matahari
  /// Bahaya (>90%) = Tomat
  static Color getBudgetStatusColor(double percentage) {
    if (percentage < 0.70) {
      return mint;
    } else if (percentage <= 0.90) {
      return matahari;
    } else {
      return tomat;
    }
  }
}
