import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/putar_theme.dart';
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
    final t = context.putarTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.ink,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: t.ink,
            offset: t.smallShadowOffset,
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
              t: t,
              scope: AppScope.pribadi,
              label: 'Pribadi',
              activeColor: t.secondary,
            ),
            const SizedBox(width: 4),
            _buildSegment(
              t: t,
              scope: AppScope.grup,
              label: 'Grup',
              activeColor: t.accentBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment({
    required PutarTheme t,
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
                ? Border.all(color: t.ink, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: t.ink,
                      offset: t.miniShadowOffset,
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: t.buttonSmall.copyWith(
              color: t.ink,
              fontWeight: isSelected ? t.weightExtraBold : t.weightSemiBold,
            ),
          ),
        ),
      ),
    );
  }
}

