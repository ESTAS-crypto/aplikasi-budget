import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/sound_service.dart';

enum AppScope { pribadi, grup }

/// Provider state scope aktif (Pribadi / Grup)
final appScopeProvider = StateProvider<AppScope>((ref) => AppScope.pribadi);

/// Neo-Brutalist Scope Switcher (Pribadi vs Grup)
/// Digunakan pada Layar 18 (Roda) & Layar 19 (Catatan) untuk berganti mode tanpa mengubah Bottom Nav
class ScopeSwitcher extends StatelessWidget {
  final AppScope currentScope;
  final ValueChanged<AppScope> onScopeChanged;

  const ScopeSwitcher({
    super.key,
    required this.currentScope,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.ink,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSegment(
              scope: AppScope.pribadi,
              label: 'Pribadi',
              activeColor: AppColors.matahari,
            ),
            const SizedBox(width: 4),
            _buildSegment(
              scope: AppScope.grup,
              label: 'Grup',
              activeColor: AppColors.langit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment({
    required AppScope scope,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = currentScope == scope;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Beralih ke mode $label',
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            SoundService.instance.play(Sfx.uiTap);
            HapticFeedback.selectionClick();
            onScopeChanged(scope);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppColors.ink, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.buttonSmall.copyWith(
              color: AppColors.ink,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

