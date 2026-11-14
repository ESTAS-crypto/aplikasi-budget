import 'package:flutter/material.dart';
import 'putar_theme.dart';

export 'putar_theme.dart';

class AppTheme {
  AppTheme._();

  /// Membangun `ThemeData` lengkap dari token `PutarTheme` yang sedang aktif.
  static ThemeData buildTheme(PutarTheme theme) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: theme.bg,
      primaryColor: theme.primary,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: theme.primary,
        onPrimary: theme.ink,
        secondary: theme.secondary,
        onSecondary: theme.ink,
        surface: theme.surface,
        onSurface: theme.ink,
        error: theme.danger,
        onError: theme.ink,
      ),
      fontFamily: theme.fontFamily,
      textTheme: TextTheme(
        displayLarge: theme.displayLarge,
        displayMedium: theme.displayMedium,
        titleLarge: theme.titleLarge,
        titleMedium: theme.titleMedium,
        bodyLarge: theme.bodyLargeMedium,
        bodyMedium: theme.bodyMedium,
        bodySmall: theme.bodySmall,
        labelLarge: theme.buttonLarge,
        labelMedium: theme.chipLabel,
      ),
      extensions: [
        theme,
      ],
    );
  }

  /// Tema default aplikasi (Pasar Malam).
  static ThemeData get lightTheme => buildTheme(PutarTheme.pasarMalam);
}
