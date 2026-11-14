import 'package:flutter/material.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/sound_service.dart';

/// Bilah Tab Penanda Buku bertema (Bookmark Tabs)
/// Memberikan sensasi index penanda buku binder fisik dengan animasi in/out.
class BookmarkTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const BookmarkTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildBookmarkTab(
              theme: t,
              index: 0,
              label: 'Aplikasi',
              subLabel: 'Umum & Audio',
              activeColor: t.secondary,
              isSelected: selectedIndex == 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBookmarkTab(
              theme: t,
              index: 1,
              label: 'Grup',
              subLabel: 'Aktivitas & Notif',
              activeColor: t.info,
              isSelected: selectedIndex == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkTab({
    required PutarTheme theme,
    required int index,
    required String label,
    required String subLabel,
    required Color activeColor,
    required bool isSelected,
  }) {
    final activeShadowOffset = theme.standardShadowOffset.dx == 0
        ? const Offset(0, 4)
        : const Offset(3.5, 3.5);
    final inactiveShadowOffset = theme.standardShadowOffset.dx == 0
        ? const Offset(0, 2)
        : const Offset(1.5, 1.5);

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          SoundService.instance.play(Sfx.uiTap);
          onTabSelected(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, isSelected ? -2.0 : 2.0, 0),
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: isSelected ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : theme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(
            color: theme.borderColor,
            width: isSelected ? theme.borderWidth : 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              offset: isSelected ? activeShadowOffset : inactiveShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.ink
                    : theme.ink.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.titleMedium.copyWith(
                      fontSize: isSelected ? 15 : 14,
                      fontWeight:
                          isSelected ? theme.weightExtraBold : theme.weightBold,
                      color: theme.ink,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subLabel,
                    style: theme.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: theme.weightSemiBold,
                      color: isSelected
                          ? theme.ink.withValues(alpha: 0.75)
                          : theme.textSecondary,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
