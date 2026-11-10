import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/sound_service.dart';

/// Bilah Tab Penanda Buku Neo-Brutalist (Bookmark Tabs)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildBookmarkTab(
              index: 0,
              label: 'Aplikasi',
              subLabel: 'Umum & Audio',
              activeColor: AppColors.matahari,
              isSelected: selectedIndex == 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBookmarkTab(
              index: 1,
              label: 'Grup',
              subLabel: 'Aktivitas & Notif',
              activeColor: AppColors.langit,
              isSelected: selectedIndex == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkTab({
    required int index,
    required String label,
    required String subLabel,
    required Color activeColor,
    required bool isSelected,
  }) {
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
          color: isSelected ? activeColor : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(
            color: AppColors.ink,
            width: isSelected ? 3.0 : 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink,
              offset: isSelected ? const Offset(3.5, 3.5) : const Offset(1.5, 1.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Penanda bulat kecil khas binder
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.ink : AppColors.ink.withValues(alpha: 0.3),
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
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: isSelected ? 15 : 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subLabel,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.ink.withValues(alpha: 0.75) : const Color(0xFF5B4B7A),
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

