import 'package:flutter/material.dart';

/// Gaya visual ikon & komponen bertema.
enum PutarIconStyle {
  pasarMalam,
  kucing,
}

/// Jenis maskot yang mendampingi tema (null bila tema tanpa maskot).
enum PutarMascotKind {
  mochi,
}

/// Efek selebrasi pada layar hasil akhir.
enum PutarCelebrationStyle {
  confetti,
  hearts,
}

/// Dekorasi tambahan pada roda putar.
enum PutarWheelDecor {
  none,
  ears,
}

/// Gaya layar pembuka (splash).
enum PutarSplashStyle {
  pasarMalam,
  kucing,
}

/// Kunci standar untuk teks yang berbeda antar tema.
abstract final class PutarCopyKeys {
  static const String wheelWaiting = 'wheel_waiting';
  static const String budgetOverAmount = 'budget_over_amount';
  static const String budgetOverShort = 'budget_over_short';
  static const String wheelReady = 'wheel_ready';
  static const String wheelSubtitle = 'wheel_subtitle';
  static const String splashTagline = 'splash_tagline';
  static const String streakWeeks = 'streak_weeks';
  static const String syncFailed = 'sync_failed';
  static const String budgetSafe = 'budget_safe';

  static const List<String> requiredKeys = [
    wheelWaiting,
    budgetOverAmount,
    budgetOverShort,
    wheelReady,
    wheelSubtitle,
    splashTagline,
    streakWeeks,
    syncFailed,
    budgetSafe,
  ];
}

/// Model tunggal token tema aplikasi Putar Jajan (`ThemeExtension`).
/// Semua warna, tipografi, radius, ketebalan border, bayangan, aset visual,
/// dekorasi, salinan bertema, dan id paket suara tersimpan di sini.
@immutable
class PutarTheme extends ThemeExtension<PutarTheme> {
  // Identitas & metadata tema
  final String id;
  final String displayName;
  final String subtitle;
  final String? badgeLabel;

  // Warna dasar & teks
  final Color ink;
  final Color bg;
  final Color surface;
  final Color textSecondary;
  final Color textDisabled;

  // Palet roda berurutan (8 warna)
  final List<Color> wheelPalette;

  // Warna peran (semantic roles)
  final Color primary;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  // Slot aksen berpasangan (untuk konsistensi lintas layar & kartu)
  final Color accentCoral;
  final Color accentOrange;
  final Color accentYellow;
  final Color accentMint;
  final Color accentBlue;
  final Color accentPurple;
  final Color accentPink;
  final Color accentGreen;
  final Color accentWarmSoft;
  final Color splashRayPrimary;
  final Color splashRaySecondary;
  final Color dividerTint;
  final Color selectedCardBg;
  final Color debugMutedSurface;
  final Color debugHeaderBg;
  final Color softDangerBg;

  // Palet maskot (digunakan saat mascot != null & preview)
  final Color mascotFur;
  final Color mascotEarPink;
  final Color mascotBlush;
  final Color mascotNose;
  final Color mascotBell;
  final Color mascotMuzzle;

  // Tipografi
  final String fontFamily;
  final FontWeight weightRegular;
  final FontWeight weightMedium;
  final FontWeight weightSemiBold;
  final FontWeight weightBold;
  final FontWeight weightExtraBold;

  // Bentuk, ketebalan garis & bayangan keras tanpa blur
  final double borderWidth;
  final double subtleBorderWidth;
  final double heroBorderWidth;
  final double cardRadius;
  final double smallCardRadius;
  final double buttonRadius;
  final double pillButtonRadius;
  final double chipRadius;
  final double sheetRadius;
  final double navBarTopRadius;
  final double navActivePillRadius;
  final Offset standardShadowOffset;
  final Offset heroShadowOffset;
  final Offset smallShadowOffset;
  final Offset miniShadowOffset;
  final Offset dialogShadowOffset;
  final Offset buttonPressOffset;
  final Offset wheelShadowOffset;
  final Color shadowColor;
  final Color borderColor;

  // Gaya aset & dekorasi
  final PutarIconStyle iconStyle;
  final PutarIconStyle navIconStyle;
  final PutarIconStyle pointerStyle;
  final PutarIconStyle logoStyle;
  final PutarMascotKind? mascot;
  final PutarCelebrationStyle celebration;
  final PutarWheelDecor wheelDecor;
  final PutarSplashStyle splashStyle;

  // Paket audio & notifikasi
  final String soundPackId;
  final String notificationChannelSuffix;

  // Peta salinan khusus tema
  final Map<String, String> copy;

  const PutarTheme({
    required this.id,
    required this.displayName,
    required this.subtitle,
    this.badgeLabel,
    required this.ink,
    required this.bg,
    required this.surface,
    required this.textSecondary,
    required this.textDisabled,
    required this.wheelPalette,
    required this.primary,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.accentCoral,
    required this.accentOrange,
    required this.accentYellow,
    required this.accentMint,
    required this.accentBlue,
    required this.accentPurple,
    required this.accentPink,
    required this.accentGreen,
    required this.accentWarmSoft,
    required this.splashRayPrimary,
    required this.splashRaySecondary,
    required this.dividerTint,
    required this.selectedCardBg,
    required this.debugMutedSurface,
    required this.debugHeaderBg,
    required this.softDangerBg,
    required this.mascotFur,
    required this.mascotEarPink,
    required this.mascotBlush,
    required this.mascotNose,
    required this.mascotBell,
    required this.mascotMuzzle,
    required this.fontFamily,
    required this.weightRegular,
    required this.weightMedium,
    required this.weightSemiBold,
    required this.weightBold,
    required this.weightExtraBold,
    required this.borderWidth,
    required this.subtleBorderWidth,
    required this.heroBorderWidth,
    required this.cardRadius,
    required this.smallCardRadius,
    required this.buttonRadius,
    required this.pillButtonRadius,
    required this.chipRadius,
    required this.sheetRadius,
    required this.navBarTopRadius,
    required this.navActivePillRadius,
    required this.standardShadowOffset,
    required this.heroShadowOffset,
    required this.smallShadowOffset,
    required this.miniShadowOffset,
    required this.dialogShadowOffset,
    required this.buttonPressOffset,
    required this.wheelShadowOffset,
    required this.shadowColor,
    required this.borderColor,
    required this.iconStyle,
    required this.navIconStyle,
    required this.pointerStyle,
    required this.logoStyle,
    required this.mascot,
    required this.celebration,
    required this.wheelDecor,
    required this.splashStyle,
    required this.soundPackId,
    required this.notificationChannelSuffix,
    required this.copy,
  });

  // Alias konstan Pasar Malam agar tetap kompatibel dengan AppColors/AppTypography statis
  static const Color kPasarMalamInk = Color(0xFF22163A);
  static const Color kPasarMalamCream = Color(0xFFFFF3D6);
  static const Color kPasarMalamSurface = Color(0xFFFFFFFF);
  static const Color kPasarMalamTextSecondary = Color(0xFF5B4B7A);
  static const Color kPasarMalamDisabled = Color(0xFF6B5B8A);
  static const Color kPasarMalamTomat = Color(0xFFFF6B5A);
  static const Color kPasarMalamJeruk = Color(0xFFFF9F1C);
  static const Color kPasarMalamMatahari = Color(0xFFFFD23F);
  static const Color kPasarMalamMint = Color(0xFF3DDBB0);
  static const Color kPasarMalamLangit = Color(0xFF6FB1FF);
  static const Color kPasarMalamLavender = Color(0xFFB8A4FF);
  static const Color kPasarMalamPermen = Color(0xFFFF8FC0);
  static const Color kPasarMalamLemon = Color(0xFFB8E986);

  /// Tema bawaan resmi: Pasar Malam (Neo-Brutalist Playful).
  static const PutarTheme pasarMalam = PutarTheme(
    id: 'pasar_malam',
    displayName: 'Pasar Malam',
    subtitle: 'Ceria, garis tebal, seperti stiker.',
    badgeLabel: null,
    ink: kPasarMalamInk,
    bg: kPasarMalamCream,
    surface: kPasarMalamSurface,
    textSecondary: kPasarMalamTextSecondary,
    textDisabled: kPasarMalamDisabled,
    wheelPalette: [
      kPasarMalamTomat,
      kPasarMalamJeruk,
      kPasarMalamMatahari,
      kPasarMalamMint,
      kPasarMalamLangit,
      kPasarMalamLavender,
      kPasarMalamPermen,
      kPasarMalamLemon,
    ],
    primary: kPasarMalamTomat,
    secondary: kPasarMalamMatahari,
    success: kPasarMalamMint,
    warning: kPasarMalamMatahari,
    danger: kPasarMalamTomat,
    info: kPasarMalamLangit,
    accentCoral: kPasarMalamTomat,
    accentOrange: kPasarMalamJeruk,
    accentYellow: kPasarMalamMatahari,
    accentMint: kPasarMalamMint,
    accentBlue: kPasarMalamLangit,
    accentPurple: kPasarMalamLavender,
    accentPink: kPasarMalamPermen,
    accentGreen: kPasarMalamLemon,
    accentWarmSoft: Color(0xFFFFE9A8),
    splashRayPrimary: Color(0xFFFFD23F),
    splashRaySecondary: Color(0xFFFFDE66),
    dividerTint: Color(0x2222163A),
    selectedCardBg: kPasarMalamSurface,
    debugMutedSurface: Color(0xFFF0EBF8),
    debugHeaderBg: Color(0xFFE2DDF0),
    softDangerBg: Color(0xFFFFC9BE),
    mascotFur: Color(0xFFFFB066),
    mascotEarPink: Color(0xFFFF8FB1),
    mascotBlush: Color(0xFFFF9FB8),
    mascotNose: Color(0xFFFF7A9C),
    mascotBell: Color(0xFFFFD23F),
    mascotMuzzle: Color(0xFFFFF3E0),
    fontFamily: 'BricolageGrotesque',
    weightRegular: FontWeight.w400,
    weightMedium: FontWeight.w500,
    weightSemiBold: FontWeight.w600,
    weightBold: FontWeight.w700,
    weightExtraBold: FontWeight.w800,
    borderWidth: 3.0,
    subtleBorderWidth: 2.5,
    heroBorderWidth: 3.5,
    cardRadius: 22.0,
    smallCardRadius: 18.0,
    buttonRadius: 22.0,
    pillButtonRadius: 29.0,
    chipRadius: 999.0,
    sheetRadius: 28.0,
    navBarTopRadius: 0.0,
    navActivePillRadius: 16.0,
    standardShadowOffset: Offset(4, 4),
    heroShadowOffset: Offset(6, 6),
    smallShadowOffset: Offset(3, 3),
    miniShadowOffset: Offset(2, 2),
    dialogShadowOffset: Offset(5, 5),
    buttonPressOffset: Offset(4, 4),
    wheelShadowOffset: Offset.zero,
    shadowColor: kPasarMalamInk,
    borderColor: kPasarMalamInk,
    iconStyle: PutarIconStyle.pasarMalam,
    navIconStyle: PutarIconStyle.pasarMalam,
    pointerStyle: PutarIconStyle.pasarMalam,
    logoStyle: PutarIconStyle.pasarMalam,
    mascot: null,
    celebration: PutarCelebrationStyle.confetti,
    wheelDecor: PutarWheelDecor.none,
    splashStyle: PutarSplashStyle.pasarMalam,
    soundPackId: 'pasar_malam',
    notificationChannelSuffix: 'pasar_malam',
    copy: {
      PutarCopyKeys.wheelWaiting: 'Roda lagi nunggu kamu',
      PutarCopyKeys.budgetOverAmount: 'Budget lewat Rp{amount}',
      PutarCopyKeys.budgetOverShort: 'Budget lewat!',
      PutarCopyKeys.wheelReady: 'Roda siap diputar!',
      PutarCopyKeys.wheelSubtitle: 'Putar dulu, jajan di bawah angkanya.',
      PutarCopyKeys.splashTagline: 'Putar. Terima. Jajan.',
      PutarCopyKeys.streakWeeks: 'Streak {weeks} minggu!',
      PutarCopyKeys.syncFailed: 'Gagal',
      PutarCopyKeys.budgetSafe: 'Masih aman',
    },
  );

  /// Tema kedua: Kucing Manis (palet pastel, tipografi Fredoka, ikon berkuping & Mochi).
  /// MochiPainter, HeartConfetti, paket suara & UI setelan tema aktif pada tahap T3–T5.
  static const PutarTheme kucingManis = PutarTheme(
    id: 'kucing_manis',
    displayName: 'Kucing Manis',
    subtitle: 'Imut, pastel, lembut tapi tetap keren.',
    badgeLabel: 'Baru',
    ink: Color(0xFF3A2E4F),
    bg: Color(0xFFFFF0F5),
    surface: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF6E5C86),
    textDisabled: Color(0xFF74648C),
    wheelPalette: [
      Color(0xFFFF8FB1), // Sakura
      Color(0xFFFFB997), // Persik
      Color(0xFFFFE27A), // Mentega
      Color(0xFF9BE8D0), // Mint
      Color(0xFFA8D8FF), // Langit
      Color(0xFFCDB4FF), // Lavender
      Color(0xFFFFC8DD), // Permen
      Color(0xFFC8F0A8), // Pistachio
    ],
    primary: Color(0xFFFF8FB1),
    secondary: Color(0xFFFFE27A),
    success: Color(0xFF9BE8D0),
    warning: Color(0xFFFFE27A),
    danger: Color(0xFFFF8FB1),
    info: Color(0xFFA8D8FF),
    accentCoral: Color(0xFFFF8FB1),
    accentOrange: Color(0xFFFFB997),
    accentYellow: Color(0xFFFFE27A),
    accentMint: Color(0xFF9BE8D0),
    accentBlue: Color(0xFFA8D8FF),
    accentPurple: Color(0xFFCDB4FF),
    accentPink: Color(0xFFFFC8DD),
    accentGreen: Color(0xFFC8F0A8),
    accentWarmSoft: Color(0xFFFFE9F0),
    splashRayPrimary: Color(0xFFFFE2EC),
    splashRaySecondary: Color(0xFFFFF0F5),
    dividerTint: Color(0x223A2E4F),
    selectedCardBg: Color(0xFFFFE9F0),
    debugMutedSurface: Color(0xFFF9EFF4),
    debugHeaderBg: Color(0xFFF3E2EC),
    softDangerBg: Color(0xFFFFD0DC),
    mascotFur: Color(0xFFFFB066),
    mascotEarPink: Color(0xFFFF8FB1),
    mascotBlush: Color(0xFFFF9FB8),
    mascotNose: Color(0xFFFF7A9C),
    mascotBell: Color(0xFFFFD23F),
    mascotMuzzle: Color(0xFFFFF3E0),
    fontFamily: 'Fredoka',
    weightRegular: FontWeight.w400,
    weightMedium: FontWeight.w500,
    weightSemiBold: FontWeight.w600,
    weightBold: FontWeight.w700,
    weightExtraBold: FontWeight.w700,
    borderWidth: 3.0,
    subtleBorderWidth: 2.5,
    heroBorderWidth: 3.5,
    cardRadius: 26.0,
    smallCardRadius: 22.0,
    buttonRadius: 26.0,
    pillButtonRadius: 29.0,
    chipRadius: 999.0,
    sheetRadius: 28.0,
    navBarTopRadius: 26.0,
    navActivePillRadius: 18.0,
    standardShadowOffset: Offset(0, 5),
    heroShadowOffset: Offset(0, 6),
    smallShadowOffset: Offset(0, 4),
    miniShadowOffset: Offset(0, 2),
    dialogShadowOffset: Offset(0, 5),
    buttonPressOffset: Offset(0, 5),
    wheelShadowOffset: Offset(0, 7),
    shadowColor: Color(0xFF3A2E4F),
    borderColor: Color(0xFF3A2E4F),
    iconStyle: PutarIconStyle.kucing,
    navIconStyle: PutarIconStyle.kucing,
    pointerStyle: PutarIconStyle.kucing,
    logoStyle: PutarIconStyle.kucing,
    mascot: PutarMascotKind.mochi,
    celebration: PutarCelebrationStyle.hearts,
    wheelDecor: PutarWheelDecor.ears,
    splashStyle: PutarSplashStyle.kucing,
    soundPackId: 'kucing',
    notificationChannelSuffix: 'kucing',
    copy: {
      PutarCopyKeys.wheelWaiting: 'Mochi nunggu kamu, meong~',
      PutarCopyKeys.budgetOverAmount: 'Aduh, budget lewat Rp{amount}',
      PutarCopyKeys.budgetOverShort: 'Aduh, budget lewat!',
      PutarCopyKeys.wheelReady: 'Roda siap diputar, meong!',
      PutarCopyKeys.wheelSubtitle: 'Putar dulu, nanti kucingnya yang jaga budget.',
      PutarCopyKeys.splashTagline: 'Putar, terima, jajan, meong!',
      PutarCopyKeys.streakWeeks: 'Streak {weeks} minggu, hebat!',
      PutarCopyKeys.syncFailed: 'Aduh, gagal',
      PutarCopyKeys.budgetSafe: 'Masih aman!',
    },
  );

  /// Daftar tema resmi. Menambah tema ke-3 cukup menambahkan entri di sini
  /// beserta paket aset audionya tanpa perlu mengubah layar.
  static const List<PutarTheme> allThemes = [
    pasarMalam,
    kucingManis,
  ];

  /// Mencari tema berdasarkan id, kembali ke `pasarMalam` bila tidak dikenali.
  static PutarTheme byId(String? id) {
    if (id == null || id.isEmpty) return pasarMalam;
    for (final theme in allThemes) {
      if (theme.id == id) return theme;
    }
    return pasarMalam;
  }

  /// Mengambil `PutarTheme` aktif dari `BuildContext` (aman untuk test tanpa ThemeExtension).
  static PutarTheme of(BuildContext context) {
    return Theme.of(context).extension<PutarTheme>() ?? pasarMalam;
  }

  // ---- Tipografi bertema ----

  TextStyle get displayLarge => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightExtraBold,
        fontSize: 40,
        height: 1.1,
        letterSpacing: -1.0,
        color: ink,
      );

  TextStyle get displayMedium => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightExtraBold,
        fontSize: 32,
        height: 1.15,
        letterSpacing: -0.8,
        color: ink,
      );

  TextStyle get titleLarge => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightExtraBold,
        fontSize: 24,
        height: 1.2,
        letterSpacing: -0.5,
        color: ink,
      );

  TextStyle get titleMedium => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightBold,
        fontSize: 20,
        height: 1.25,
        letterSpacing: -0.3,
        color: ink,
      );

  TextStyle get bodyLargeBold => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightBold,
        fontSize: 16,
        height: 1.35,
        color: ink,
      );

  TextStyle get bodyLargeMedium => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightMedium,
        fontSize: 16,
        height: 1.35,
        color: ink,
      );

  TextStyle get bodyMedium => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightMedium,
        fontSize: 14,
        height: 1.4,
        color: textSecondary,
      );

  TextStyle get bodySmall => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightMedium,
        fontSize: 12,
        height: 1.4,
        color: textSecondary,
      );

  TextStyle get buttonLarge => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightExtraBold,
        fontSize: 17,
        letterSpacing: 0.5,
        color: ink,
      );

  TextStyle get buttonSmall => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightExtraBold,
        fontSize: 14,
        letterSpacing: 0.3,
        color: ink,
      );

  TextStyle get chipLabel => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightBold,
        fontSize: 13,
        letterSpacing: 0.2,
        color: ink,
      );

  TextStyle get wheelLabel => TextStyle(
        fontFamily: fontFamily,
        fontWeight: weightExtraBold,
        fontSize: 18,
        color: ink,
      );

  // ---- Helper palet & copy ----

  Color getWheelColor(int index) {
    if (wheelPalette.isEmpty) return primary;
    return wheelPalette[index % wheelPalette.length];
  }

  Color getBudgetStatusColor(double percentage) {
    if (percentage < 0.70) return success;
    if (percentage <= 0.90) return warning;
    return danger;
  }

  List<Color> get memberAvatarColors => [
        accentBlue,
        accentGreen,
        accentPink,
        accentYellow,
        accentPurple,
        accentCoral,
      ];

  List<Color> get gamesHubCardColors => [
        accentPink,
        accentBlue,
        accentGreen,
        accentYellow,
        accentMint,
        accentOrange,
        accentPurple,
        accentCoral,
      ];

  List<Color> get detailMemberColors => [
        accentBlue,
        accentGreen,
        accentPink,
        accentPurple,
        accentYellow,
        accentMint,
        id == 'pasar_malam' ? const Color(0xFFFF9F43) : accentOrange,
        accentCoral,
      ];

  /// Mengambil kalimat bertema berdasarkan kunci dengan substitusi placeholder `{key}`.
  String text(String key, {Map<String, String> params = const {}}) {
    var result = copy[key] ?? pasarMalam.copy[key] ?? key;
    if (params.isNotEmpty) {
      params.forEach((paramKey, value) {
        result = result.replaceAll('{$paramKey}', value);
      });
    }
    return result;
  }

  @override
  PutarTheme copyWith({
    String? id,
    String? displayName,
    String? subtitle,
    String? badgeLabel,
    Color? ink,
    Color? bg,
    Color? surface,
    Color? textSecondary,
    Color? textDisabled,
    List<Color>? wheelPalette,
    Color? primary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? accentCoral,
    Color? accentOrange,
    Color? accentYellow,
    Color? accentMint,
    Color? accentBlue,
    Color? accentPurple,
    Color? accentPink,
    Color? accentGreen,
    Color? accentWarmSoft,
    Color? splashRayPrimary,
    Color? splashRaySecondary,
    Color? dividerTint,
    Color? selectedCardBg,
    Color? debugMutedSurface,
    Color? debugHeaderBg,
    Color? softDangerBg,
    Color? mascotFur,
    Color? mascotEarPink,
    Color? mascotBlush,
    Color? mascotNose,
    Color? mascotBell,
    Color? mascotMuzzle,
    String? fontFamily,
    FontWeight? weightRegular,
    FontWeight? weightMedium,
    FontWeight? weightSemiBold,
    FontWeight? weightBold,
    FontWeight? weightExtraBold,
    double? borderWidth,
    double? subtleBorderWidth,
    double? heroBorderWidth,
    double? cardRadius,
    double? smallCardRadius,
    double? buttonRadius,
    double? pillButtonRadius,
    double? chipRadius,
    double? sheetRadius,
    double? navBarTopRadius,
    double? navActivePillRadius,
    Offset? standardShadowOffset,
    Offset? heroShadowOffset,
    Offset? smallShadowOffset,
    Offset? miniShadowOffset,
    Offset? dialogShadowOffset,
    Offset? buttonPressOffset,
    Offset? wheelShadowOffset,
    Color? shadowColor,
    Color? borderColor,
    PutarIconStyle? iconStyle,
    PutarIconStyle? navIconStyle,
    PutarIconStyle? pointerStyle,
    PutarIconStyle? logoStyle,
    PutarMascotKind? mascot,
    PutarCelebrationStyle? celebration,
    PutarWheelDecor? wheelDecor,
    PutarSplashStyle? splashStyle,
    String? soundPackId,
    String? notificationChannelSuffix,
    Map<String, String>? copy,
  }) {
    return PutarTheme(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      subtitle: subtitle ?? this.subtitle,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      ink: ink ?? this.ink,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      wheelPalette: wheelPalette ?? this.wheelPalette,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      accentCoral: accentCoral ?? this.accentCoral,
      accentOrange: accentOrange ?? this.accentOrange,
      accentYellow: accentYellow ?? this.accentYellow,
      accentMint: accentMint ?? this.accentMint,
      accentBlue: accentBlue ?? this.accentBlue,
      accentPurple: accentPurple ?? this.accentPurple,
      accentPink: accentPink ?? this.accentPink,
      accentGreen: accentGreen ?? this.accentGreen,
      accentWarmSoft: accentWarmSoft ?? this.accentWarmSoft,
      splashRayPrimary: splashRayPrimary ?? this.splashRayPrimary,
      splashRaySecondary: splashRaySecondary ?? this.splashRaySecondary,
      dividerTint: dividerTint ?? this.dividerTint,
      selectedCardBg: selectedCardBg ?? this.selectedCardBg,
      debugMutedSurface: debugMutedSurface ?? this.debugMutedSurface,
      debugHeaderBg: debugHeaderBg ?? this.debugHeaderBg,
      softDangerBg: softDangerBg ?? this.softDangerBg,
      mascotFur: mascotFur ?? this.mascotFur,
      mascotEarPink: mascotEarPink ?? this.mascotEarPink,
      mascotBlush: mascotBlush ?? this.mascotBlush,
      mascotNose: mascotNose ?? this.mascotNose,
      mascotBell: mascotBell ?? this.mascotBell,
      mascotMuzzle: mascotMuzzle ?? this.mascotMuzzle,
      fontFamily: fontFamily ?? this.fontFamily,
      weightRegular: weightRegular ?? this.weightRegular,
      weightMedium: weightMedium ?? this.weightMedium,
      weightSemiBold: weightSemiBold ?? this.weightSemiBold,
      weightBold: weightBold ?? this.weightBold,
      weightExtraBold: weightExtraBold ?? this.weightExtraBold,
      borderWidth: borderWidth ?? this.borderWidth,
      subtleBorderWidth: subtleBorderWidth ?? this.subtleBorderWidth,
      heroBorderWidth: heroBorderWidth ?? this.heroBorderWidth,
      cardRadius: cardRadius ?? this.cardRadius,
      smallCardRadius: smallCardRadius ?? this.smallCardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      pillButtonRadius: pillButtonRadius ?? this.pillButtonRadius,
      chipRadius: chipRadius ?? this.chipRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      navBarTopRadius: navBarTopRadius ?? this.navBarTopRadius,
      navActivePillRadius: navActivePillRadius ?? this.navActivePillRadius,
      standardShadowOffset: standardShadowOffset ?? this.standardShadowOffset,
      heroShadowOffset: heroShadowOffset ?? this.heroShadowOffset,
      smallShadowOffset: smallShadowOffset ?? this.smallShadowOffset,
      miniShadowOffset: miniShadowOffset ?? this.miniShadowOffset,
      dialogShadowOffset: dialogShadowOffset ?? this.dialogShadowOffset,
      buttonPressOffset: buttonPressOffset ?? this.buttonPressOffset,
      wheelShadowOffset: wheelShadowOffset ?? this.wheelShadowOffset,
      shadowColor: shadowColor ?? this.shadowColor,
      borderColor: borderColor ?? this.borderColor,
      iconStyle: iconStyle ?? this.iconStyle,
      navIconStyle: navIconStyle ?? this.navIconStyle,
      pointerStyle: pointerStyle ?? this.pointerStyle,
      logoStyle: logoStyle ?? this.logoStyle,
      mascot: mascot ?? this.mascot,
      celebration: celebration ?? this.celebration,
      wheelDecor: wheelDecor ?? this.wheelDecor,
      splashStyle: splashStyle ?? this.splashStyle,
      soundPackId: soundPackId ?? this.soundPackId,
      notificationChannelSuffix:
          notificationChannelSuffix ?? this.notificationChannelSuffix,
      copy: copy ?? this.copy,
    );
  }

  @override
  PutarTheme lerp(ThemeExtension<PutarTheme>? other, double t) {
    if (other is! PutarTheme) return this;
    final paletteLen = wheelPalette.length < other.wheelPalette.length
        ? wheelPalette.length
        : other.wheelPalette.length;
    final lerpedPalette = List<Color>.generate(
      paletteLen,
      (i) => Color.lerp(wheelPalette[i], other.wheelPalette[i], t)!,
    );
    final useOther = t >= 0.5;
    return PutarTheme(
      id: useOther ? other.id : id,
      displayName: useOther ? other.displayName : displayName,
      subtitle: useOther ? other.subtitle : subtitle,
      badgeLabel: useOther ? other.badgeLabel : badgeLabel,
      ink: Color.lerp(ink, other.ink, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      wheelPalette: lerpedPalette,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      accentCoral: Color.lerp(accentCoral, other.accentCoral, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      accentMint: Color.lerp(accentMint, other.accentMint, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      accentPink: Color.lerp(accentPink, other.accentPink, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentWarmSoft: Color.lerp(accentWarmSoft, other.accentWarmSoft, t)!,
      splashRayPrimary:
          Color.lerp(splashRayPrimary, other.splashRayPrimary, t)!,
      splashRaySecondary:
          Color.lerp(splashRaySecondary, other.splashRaySecondary, t)!,
      dividerTint: Color.lerp(dividerTint, other.dividerTint, t)!,
      selectedCardBg: Color.lerp(selectedCardBg, other.selectedCardBg, t)!,
      debugMutedSurface:
          Color.lerp(debugMutedSurface, other.debugMutedSurface, t)!,
      debugHeaderBg: Color.lerp(debugHeaderBg, other.debugHeaderBg, t)!,
      softDangerBg: Color.lerp(softDangerBg, other.softDangerBg, t)!,
      mascotFur: Color.lerp(mascotFur, other.mascotFur, t)!,
      mascotEarPink: Color.lerp(mascotEarPink, other.mascotEarPink, t)!,
      mascotBlush: Color.lerp(mascotBlush, other.mascotBlush, t)!,
      mascotNose: Color.lerp(mascotNose, other.mascotNose, t)!,
      mascotBell: Color.lerp(mascotBell, other.mascotBell, t)!,
      mascotMuzzle: Color.lerp(mascotMuzzle, other.mascotMuzzle, t)!,
      fontFamily: useOther ? other.fontFamily : fontFamily,
      weightRegular: useOther ? other.weightRegular : weightRegular,
      weightMedium: useOther ? other.weightMedium : weightMedium,
      weightSemiBold: useOther ? other.weightSemiBold : weightSemiBold,
      weightBold: useOther ? other.weightBold : weightBold,
      weightExtraBold: useOther ? other.weightExtraBold : weightExtraBold,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      subtleBorderWidth:
          subtleBorderWidth + (other.subtleBorderWidth - subtleBorderWidth) * t,
      heroBorderWidth:
          heroBorderWidth + (other.heroBorderWidth - heroBorderWidth) * t,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      smallCardRadius:
          smallCardRadius + (other.smallCardRadius - smallCardRadius) * t,
      buttonRadius: buttonRadius + (other.buttonRadius - buttonRadius) * t,
      pillButtonRadius:
          pillButtonRadius + (other.pillButtonRadius - pillButtonRadius) * t,
      chipRadius: chipRadius + (other.chipRadius - chipRadius) * t,
      sheetRadius: sheetRadius + (other.sheetRadius - sheetRadius) * t,
      navBarTopRadius:
          navBarTopRadius + (other.navBarTopRadius - navBarTopRadius) * t,
      navActivePillRadius:
          navActivePillRadius + (other.navActivePillRadius - navActivePillRadius) * t,
      standardShadowOffset:
          Offset.lerp(standardShadowOffset, other.standardShadowOffset, t)!,
      heroShadowOffset:
          Offset.lerp(heroShadowOffset, other.heroShadowOffset, t)!,
      smallShadowOffset:
          Offset.lerp(smallShadowOffset, other.smallShadowOffset, t)!,
      miniShadowOffset:
          Offset.lerp(miniShadowOffset, other.miniShadowOffset, t)!,
      dialogShadowOffset:
          Offset.lerp(dialogShadowOffset, other.dialogShadowOffset, t)!,
      buttonPressOffset:
          Offset.lerp(buttonPressOffset, other.buttonPressOffset, t)!,
      wheelShadowOffset:
          Offset.lerp(wheelShadowOffset, other.wheelShadowOffset, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      iconStyle: useOther ? other.iconStyle : iconStyle,
      navIconStyle: useOther ? other.navIconStyle : navIconStyle,
      pointerStyle: useOther ? other.pointerStyle : pointerStyle,
      logoStyle: useOther ? other.logoStyle : logoStyle,
      mascot: useOther ? other.mascot : mascot,
      celebration: useOther ? other.celebration : celebration,
      wheelDecor: useOther ? other.wheelDecor : wheelDecor,
      splashStyle: useOther ? other.splashStyle : splashStyle,
      soundPackId: useOther ? other.soundPackId : soundPackId,
      notificationChannelSuffix: useOther
          ? other.notificationChannelSuffix
          : notificationChannelSuffix,
      copy: useOther ? other.copy : copy,
    );
  }
}

/// Extension praktis untuk mengakses token tema aktif via `context.putarTheme`.
extension PutarThemeBuildContext on BuildContext {
  PutarTheme get putarTheme => PutarTheme.of(this);
}
