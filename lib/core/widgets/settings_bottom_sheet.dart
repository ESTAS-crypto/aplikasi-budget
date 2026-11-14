import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/putar_theme.dart';
import '../painters/sticker_icons.dart';
import '../utils/sound_service.dart';

/// Modal Bottom Sheet Pengaturan Suara & Getaran bertema
class SettingsBottomSheet extends ConsumerWidget {
  const SettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    SoundService.instance.play(Sfx.uiTap);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SettingsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.putarTheme;
    final settings = ref.watch(soundSettingsProvider);
    final notifier = ref.read(soundSettingsProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.sheetRadius)),
        border: Border(
          top: BorderSide(color: t.borderColor, width: t.heroBorderWidth),
          left: BorderSide(color: t.borderColor, width: t.heroBorderWidth),
          right: BorderSide(color: t.borderColor, width: t.heroBorderWidth),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header dengan Tombol Tutup
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: t.secondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: t.borderColor,
                          width: t.subtleBorderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.shadowColor,
                            offset: t.miniShadowOffset,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(7),
                      child: CustomPaint(
                        painter: CustomSettingsIconPainter(
                          color: t.ink,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan',
                            style: t.displayMedium.copyWith(
                              fontSize: 22,
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                            ),
                          ),
                          Text(
                            'Audio & Getaran gameplay',
                            style: t.bodySmall.copyWith(
                              color: t.textSecondary,
                              fontSize: 12,
                              fontWeight: t.weightSemiBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.uiTap);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: t.borderColor,
                      width: t.subtleBorderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: t.shadowColor,
                        offset: t.miniShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(9),
                  child: CustomPaint(
                    painter: CustomCloseIconPainter(
                      color: t.ink,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Card 1: Suara Efek (SFX) Toggle
          _SettingCard(
            title: 'Efek Suara',
            subtitle: '19 audio kalimba resmi pentatonik C',
            trailing: _NeoSwitch(
              value: settings.soundEnabled,
              activeColor: t.success,
              onChanged: (val) {
                notifier.setSoundEnabled(val);
                if (val) {
                  SoundService.instance.play(Sfx.uiTap);
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Card 2: Volume Slider
          _SettingCard(
            title: 'Volume Master',
            subtitle: '${(settings.volume * 100).toInt()}%',
            content: Column(
              children: [
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 12,
                    activeTrackColor: t.secondary,
                    inactiveTrackColor: t.surface,
                    thumbColor: t.ink,
                    overlayColor: t.secondary.withAlpha(50),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 11,
                      elevation: 2,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: settings.volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: settings.soundEnabled
                        ? (val) {
                            notifier.setVolume(val);
                          }
                        : null,
                    onChangeEnd: (val) {
                      SoundService.instance.play(Sfx.coinRecord);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 3: Getaran Haptik
          _SettingCard(
            title: 'Getaran Haptik',
            subtitle: 'Sentuhan sinkron pada roda, dadu & amplop',
            trailing: _NeoSwitch(
              value: settings.vibrationEnabled,
              activeColor: t.accentPink,
              onChanged: (val) {
                notifier.setVibrationEnabled(val);
                if (val) {
                  SoundService.instance.play(Sfx.uiTap, haptic: true);
                }
              },
            ),
          ),
          const SizedBox(height: 14),

          // Tombol Sistem Brand & Palet
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              SoundService.instance.play(Sfx.uiTap);
              context.push('/brand-system');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: t.borderColor,
                  width: t.subtleBorderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: t.smallShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: t.info,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: t.borderColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              'PJ',
                              style: TextStyle(
                                fontFamily: t.fontFamily,
                                fontSize: 10,
                                fontWeight: t.weightExtraBold,
                                color: t.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lihat Sistem Brand & Desain',
                            style: TextStyle(
                              fontFamily: t.fontFamily,
                              fontSize: 13,
                              fontWeight: t.weightBold,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CustomPaint(
                      painter: CustomForwardIconPainter(
                        color: t.ink,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tombol Buka Pengaturan Lengkap
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              SoundService.instance.play(Sfx.uiTap);
              context.push('/settings');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: t.secondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: t.borderColor,
                  width: t.subtleBorderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: t.smallShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(16, 16),
                    painter: CustomSettingsIconPainter(
                      color: t.ink,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Buka Pengaturan Lengkap',
                    style: TextStyle(
                      fontFamily: t.fontFamily,
                      fontSize: 13,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? content;

  const _SettingCard({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.smallShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.bodyMedium.copyWith(
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: t.bodySmall.copyWith(
                        color: t.textSecondary,
                        fontSize: 12,
                        fontWeight: t.weightSemiBold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ?trailing,
            ],
          ),
          ?content,
        ],
      ),
    );
  }
}

class _NeoSwitch extends StatelessWidget {
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _NeoSwitch({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: value ? activeColor : t.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
          boxShadow: [
            BoxShadow(
              color: t.shadowColor,
              offset: t.miniShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: t.surface,
              shape: BoxShape.circle,
              border: Border.all(color: t.borderColor, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
