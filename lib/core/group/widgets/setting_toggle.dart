import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/putar_theme.dart';
import '../../utils/sound_service.dart';

/// Sakelar kustom bertema dengan border tebal dan transisi halus
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
    final t = context.putarTheme;
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
            color: value ? t.success : t.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: t.borderColor, width: 2.8),
            boxShadow: [
              BoxShadow(
                color: t.shadowColor,
                offset: t.miniShadowOffset,
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
                      color: value ? t.surface : t.ink,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.borderColor,
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
