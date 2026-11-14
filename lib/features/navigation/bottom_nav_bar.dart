import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/putar_theme.dart';
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
    final t = context.putarTheme;
    final currentIndex = navigationShell.currentIndex;

    final navContent = Padding(
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
            icon: _MorphingNavIcon(
              morphKey: 'wheel_${t.navIconStyle.name}',
              child: CustomPaint(
                painter: WheelNavPainter(
                  color: t.ink,
                  hubColor: t.surface,
                  style: t.navIconStyle,
                ),
              ),
            ),
          ),
          _NavItem(
            label: 'Catatan',
            isActive: currentIndex == 1,
            onTap: () => _onItemTapped(1),
            icon: _MorphingNavIcon(
              morphKey: 'receipt_${t.navIconStyle.name}',
              child: CustomPaint(
                painter: ReceiptNavPainter(
                  color: t.ink,
                  cutoutColor: currentIndex == 1 ? t.secondary : t.surface,
                  style: t.navIconStyle,
                ),
              ),
            ),
          ),
          _NavItem(
            label: 'Riwayat',
            isActive: currentIndex == 2,
            onTap: () => _onItemTapped(2),
            icon: _MorphingNavIcon(
              morphKey: 'history_${t.navIconStyle.name}',
              child: CustomPaint(
                painter: HistoryNavPainter(
                  color: t.ink,
                  style: t.navIconStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (t.navBarTopRadius > 0) {
      return CustomPaint(
        painter: _NavBarFramePainter(
          surfaceColor: t.surface,
          borderColor: t.borderColor,
          borderWidth: t.borderWidth,
          topRadius: t.navBarTopRadius,
        ),
        child: navContent,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(
            color: t.borderColor,
            width: t.borderWidth,
          ),
        ),
      ),
      child: navContent,
    );
  }
}

class _MorphingNavIcon extends StatelessWidget {
  final String morphKey;
  final Widget child;

  const _MorphingNavIcon({
    required this.morphKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 420);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        final scale = Tween<double>(begin: 0.72, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack))
            .animate(animation);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
      child: SizedBox(
        key: ValueKey(morphKey),
        width: 26,
        height: 26,
        child: child,
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
    final t = context.putarTheme;
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
              // Tab aktif: pil bertema berborder 2px ink di belakang ikon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: isActive
                    ? const EdgeInsets.symmetric(horizontal: 18, vertical: 3)
                    : const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? t.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(t.navActivePillRadius),
                  border: Border.all(
                    color: isActive ? t.borderColor : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: icon,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: t.chipLabel.copyWith(
                  fontWeight: t.weightExtraBold,
                  color: isActive ? t.ink : t.textDisabled,
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

class _NavBarFramePainter extends CustomPainter {
  final Color surfaceColor;
  final Color borderColor;
  final double borderWidth;
  final double topRadius;

  const _NavBarFramePainter({
    required this.surfaceColor,
    required this.borderColor,
    required this.borderWidth,
    required this.topRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = topRadius.clamp(0.0, w / 2);

    final fillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, r)
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(w - r, 0)
      ..arcToPoint(
        Offset(w, r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill,
    );

    final half = borderWidth / 2;
    final innerR = (r - half).clamp(0.0, w / 2);
    final borderPath = Path()
      ..moveTo(half, r)
      ..arcToPoint(
        Offset(r, half),
        radius: Radius.circular(innerR),
        clockwise: true,
      )
      ..lineTo(w - r, half)
      ..arcToPoint(
        Offset(w - half, r),
        radius: Radius.circular(innerR),
        clockwise: true,
      );

    canvas.drawPath(
      borderPath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NavBarFramePainter oldDelegate) =>
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.topRadius != topRadius;
}
