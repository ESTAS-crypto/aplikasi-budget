import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/painters/nav_icons_painter.dart';
import '../../core/utils/sound_service.dart';

class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    SoundService.instance.play(Sfx.uiTap);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.ink,
            width: 3.0,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            label: 'Main',
            isActive: currentIndex == 0,
            onTap: () => _onItemTapped(0),
            icon: const SizedBox(
              width: 26,
              height: 26,
              child: CustomPaint(painter: WheelNavPainter()),
            ),
          ),
          _NavItem(
            label: 'Catatan',
            isActive: currentIndex == 1,
            onTap: () => _onItemTapped(1),
            icon: const SizedBox(
              width: 26,
              height: 26,
              child: CustomPaint(painter: ReceiptNavPainter()),
            ),
          ),
          _NavItem(
            label: 'Riwayat',
            isActive: currentIndex == 2,
            onTap: () => _onItemTapped(2),
            icon: const SizedBox(
              width: 26,
              height: 26,
              child: CustomPaint(painter: HistoryNavPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget icon;

  const _NavItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tab aktif: pil Matahari berborder 2px ink di belakang ikon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: isActive
                    ? const EdgeInsets.symmetric(horizontal: 18, vertical: 3)
                    : const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.matahari : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? AppColors.ink : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: icon,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTypography.chipLabel.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isActive ? AppColors.ink : AppColors.disabled,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
