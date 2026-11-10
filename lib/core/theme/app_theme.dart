import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

@immutable
class StickerThemeTokens extends ThemeExtension<StickerThemeTokens> {
  final double borderWidth;
  final double heroBorderWidth;
  final double borderRadius;
  final double buttonRadius;
  final Offset standardShadowOffset;
  final Offset heroShadowOffset;
  final Color shadowColor;
  final Color borderColor;

  const StickerThemeTokens({
    this.borderWidth = 3.0,
    this.heroBorderWidth = 3.5,
    this.borderRadius = 22.0,
    this.buttonRadius = 29.0,
    this.standardShadowOffset = const Offset(4, 4),
    this.heroShadowOffset = const Offset(6, 6),
    this.shadowColor = AppColors.ink,
    this.borderColor = AppColors.ink,
  });

  @override
  StickerThemeTokens copyWith({
    double? borderWidth,
    double? heroBorderWidth,
    double? borderRadius,
    double? buttonRadius,
    Offset? standardShadowOffset,
    Offset? heroShadowOffset,
    Color? shadowColor,
    Color? borderColor,
  }) {
    return StickerThemeTokens(
      borderWidth: borderWidth ?? this.borderWidth,
      heroBorderWidth: heroBorderWidth ?? this.heroBorderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      standardShadowOffset: standardShadowOffset ?? this.standardShadowOffset,
      heroShadowOffset: heroShadowOffset ?? this.heroShadowOffset,
      shadowColor: shadowColor ?? this.shadowColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }

  @override
  StickerThemeTokens lerp(ThemeExtension<StickerThemeTokens>? other, double t) {
    if (other is! StickerThemeTokens) return this;
    return StickerThemeTokens(
      borderWidth: (borderWidth + (other.borderWidth - borderWidth) * t),
      heroBorderWidth: (heroBorderWidth + (other.heroBorderWidth - heroBorderWidth) * t),
      borderRadius: (borderRadius + (other.borderRadius - borderRadius) * t),
      buttonRadius: (buttonRadius + (other.buttonRadius - buttonRadius) * t),
      standardShadowOffset: Offset.lerp(standardShadowOffset, other.standardShadowOffset, t)!,
      heroShadowOffset: Offset.lerp(heroShadowOffset, other.heroShadowOffset, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.cream,
      primaryColor: AppColors.tomat,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.tomat,
        onPrimary: AppColors.ink,
        secondary: AppColors.matahari,
        onSecondary: AppColors.ink,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.tomat,
        onError: AppColors.ink,
      ),
      fontFamily: AppTypography.fontFamily,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLargeMedium,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonLarge,
        labelMedium: AppTypography.chipLabel,
      ),
      extensions: const [
        StickerThemeTokens(),
      ],
    );
  }
}
