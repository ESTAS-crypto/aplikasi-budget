import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/in_app_toast.dart';
import '../../../core/widgets/sticker_button.dart';
import '../widgets/theme_preview_painters.dart';

/// Layar 22: Pilih Tema Aplikasi (`Tema1.dc.html`).
/// Menampilkan daftar tema dari `PutarTheme.allThemes` dengan pratinjau token masing-masing,
/// daftar aspek yang ikut berubah, dan tombol aksi "Pakai `<Nama Tema>`" secara langsung.
class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() =>
      _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  String? _selectedId;
  Offset? _lastTapOrigin;

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final activeTheme = ref.watch(themeControllerProvider);
    final selectedTheme = PutarTheme.byId(_selectedId ?? activeTheme.id);

    ref.listen<PutarTheme>(themeControllerProvider, (prev, next) {
      if (prev?.id != next.id && mounted) {
        setState(() => _selectedId = next.id);
      }
    });

    const changeItems = <String>[
      'Warna dan roda',
      'Maskot tema',
      'Logo dan ikon',
      'Splash screen',
    ];

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header: Tombol Kembali + "Tema aplikasi"
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Kembali',
                          child: GestureDetector(
                            onTap: () {
                              SoundService.instance.play(Sfx.uiTap);
                              if (GoRouter.maybeOf(context) != null &&
                                  context.canPop()) {
                                context.pop();
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: t.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: t.ink,
                                  width: t.borderWidth,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: t.shadowColor,
                                    offset: t.smallShadowOffset,
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: CustomPaint(
                                size: const Size(22, 22),
                                painter: CustomBackIconPainter(
                                  color: t.ink,
                                  strokeWidth: t.borderWidth,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tema aplikasi',
                            style: t.displayMedium.copyWith(
                              fontSize: 26,
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ganti suasana. Semua fitur tetap sama.',
                      style: t.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: t.weightMedium,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Kartu Pratinjau Tema Generik (mendukung tema ke-3+ otomatis)
                    for (int i = 0; i < PutarTheme.allThemes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _ThemeOptionCard(
                        themeOption: PutarTheme.allThemes[i],
                        isActive:
                            PutarTheme.allThemes[i].id == activeTheme.id,
                        isSelected:
                            PutarTheme.allThemes[i].id == selectedTheme.id,
                        onTap: () {
                          SoundService.instance.play(Sfx.uiTap);
                          setState(() {
                            _selectedId = PutarTheme.allThemes[i].id;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 20),

                    // 3. Bagian "Yang ikut berubah" (grid 2x2 bebas overflow pada 320dp + 1.3x)
                    Text(
                      'Yang ikut berubah',
                      style: t.titleMedium.copyWith(
                        fontSize: 16,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ChangeFeatureItem(
                            label: changeItems[0],
                            ink: t.ink,
                            style: t.bodyMedium.copyWith(
                              fontSize: 14,
                              fontWeight: t.weightBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChangeFeatureItem(
                            label: changeItems[1],
                            ink: t.ink,
                            style: t.bodyMedium.copyWith(
                              fontSize: 14,
                              fontWeight: t.weightBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ChangeFeatureItem(
                            label: changeItems[2],
                            ink: t.ink,
                            style: t.bodyMedium.copyWith(
                              fontSize: 14,
                              fontWeight: t.weightBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ChangeFeatureItem(
                            label: changeItems[3],
                            ink: t.ink,
                            style: t.bodyMedium.copyWith(
                              fontSize: 14,
                              fontWeight: t.weightBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Tombol Terapkan Tema di Bawah
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) => _lastTapOrigin = event.position,
                    child: StickerButton.large(
                      key: const ValueKey('apply_selected_theme_button'),
                      text: 'Pakai ${selectedTheme.displayName}',
                      backgroundColor: selectedTheme.primary,
                      textColor: t.ink,
                      borderColor: t.ink,
                      shadowColor: t.shadowColor,
                      onPressed: () async {
                        await ref
                            .read(themeControllerProvider.notifier)
                            .setTheme(selectedTheme, origin: _lastTapOrigin);
                        if (!context.mounted) return;
                        SoundService.instance.play(Sfx.uiTap);
                        InAppToast.show(
                          context,
                          message:
                              'Tema ${selectedTheme.displayName} sekarang dipakai.',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bisa diganti kapan saja di Pengaturan.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: t.weightSemiBold,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final PutarTheme themeOption;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.themeOption,
    required this.isActive,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final previewSize = sw < 350 ? 66.0 : 84.0;
    final option = themeOption;
    final swatches = <Color>[
      option.primary,
      option.secondary,
      option.success,
      option.accentPurple,
    ];

    final cardBg = isSelected ? option.selectedCardBg : option.surface;
    final borderWidth =
        isSelected ? option.heroBorderWidth + 0.5 : option.borderWidth;
    final shadowColor = isSelected && option.mascot != null
        ? option.primary
        : option.shadowColor;
    final badgeText = isActive ? 'Dipakai' : option.badgeLabel;
    final badgeColor = isActive ? option.bg : option.secondary;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 420);

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: 'Tema ${option.displayName}, ${option.subtitle}'
          '${isActive ? ', sedang dipakai' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(sw < 350 ? 12 : 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(option.cardRadius),
                border: Border.all(
                  color: option.ink,
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    offset: option.standardShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ThemePreviewThumbnail(
                    themeOption: option,
                    size: previewSize,
                    animate: option.mascot != null,
                  ),
                  SizedBox(width: sw < 350 ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              option.displayName,
                              style: TextStyle(
                                fontFamily: option.fontFamily,
                                fontSize: sw < 350 ? 17 : 19,
                                fontWeight: option.weightExtraBold,
                                color: option.ink,
                              ),
                            ),
                            if (badgeText != null)
                              Container(
                                key: ValueKey('badge_$badgeText'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius:
                                      BorderRadius.circular(option.chipRadius),
                                  border: Border.all(
                                    color: option.ink,
                                    width: 2.0,
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontFamily: option.fontFamily,
                                    fontSize: 11,
                                    fontWeight: option.weightExtraBold,
                                    color: option.ink,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          option.subtitle,
                          style: TextStyle(
                            fontFamily: option.fontFamily,
                            fontSize: 13,
                            fontWeight: option.weightMedium,
                            color: option.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final swatch in swatches)
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: swatch,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: option.ink,
                                    width: 2.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -6,
              top: -10,
              child: ExcludeSemantics(
                child: AnimatedSwitcher(
                  duration: animDuration,
                  switchInCurve: Curves.linear,
                  switchOutCurve: Curves.linear,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.72, end: 1.0)
                          .chain(CurveTween(curve: Curves.easeOutBack))
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: isSelected
                      ? Container(
                          key: ValueKey('theme_selected_check_${option.id}'),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: option.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: option.ink,
                              width: option.borderWidth,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: CustomPaint(
                            size: const Size(18, 18),
                            painter: CustomCheckIconPainter(
                              color: option.ink,
                              strokeWidth: 3.0,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeFeatureItem extends StatelessWidget {
  final String label;
  final Color ink;
  final TextStyle style;

  const _ChangeFeatureItem({
    required this.label,
    required this.ink,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(
              painter: CustomCheckIconPainter(
                color: ink,
                strokeWidth: 3.0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: style,
          ),
        ),
      ],
    );
  }
}
