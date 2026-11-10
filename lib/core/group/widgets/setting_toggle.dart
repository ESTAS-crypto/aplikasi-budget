import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../utils/sound_service.dart';

/// Neo-Brutalist SettingToggle (Layar 21)
/// Sakelar saklar custom dengan border ink 3px dan transisi halus
class SettingToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const SettingToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label.isNotEmpty ? label : 'Pengaturan sakelar',
      child: GestureDetector(
        onTap: () {
          SoundService.instance.play(Sfx.uiTap);
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 30,
          decoration: BoxDecoration(
            color: value ? AppColors.mint : AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.ink, width: 2.8),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: value ? AppColors.surface : AppColors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: 2.0,
                      ),
                    ),
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

