import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../painters/sticker_icons.dart';
import '../utils/sound_service.dart';

/// Modal Bottom Sheet Pengaturan Suara & Getaran (Neo-Brutalist)
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
    final settings = ref.watch(soundSettingsProvider);
    final notifier = ref.read(soundSettingsProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.ink, width: 3.5),
          left: BorderSide(color: AppColors.ink, width: 3.5),
          right: BorderSide(color: AppColors.ink, width: 3.5),
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
                        color: AppColors.matahari,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.ink, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(7),
                      child: const CustomPaint(
                        painter: CustomSettingsIconPainter(
                          color: AppColors.ink,
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
                            style: AppTypography.displayMedium.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Audio & Getaran gameplay',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(9),
                  child: const CustomPaint(
                    painter: CustomCloseIconPainter(
                      color: AppColors.ink,
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
              activeColor: AppColors.mint,
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
                    activeTrackColor: AppColors.matahari,
                    inactiveTrackColor: AppColors.surface,
                    thumbColor: AppColors.ink,
                    overlayColor: AppColors.matahari.withAlpha(50),
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
              activeColor: AppColors.permen,
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(3, 3),
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
                            color: AppColors.langit,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.ink, width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              'PJ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Lihat Sistem Brand & Desain',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CustomPaint(
                      painter: CustomForwardIconPainter(
                        color: AppColors.ink,
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
                color: AppColors.matahari,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: Size(16, 16),
                    painter: CustomSettingsIconPainter(
                      color: AppColors.ink,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Buka Pengaturan Lengkap',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
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
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: value ? activeColor : AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(2, 2),
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
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

