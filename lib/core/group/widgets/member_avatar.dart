import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../painters/group_icons_painter.dart';

/// Avatar Anggota Grup Neo-Brutalist
/// Menggunakan inisial nama dan salah satu dari 8 warna palet Putar Jajan
class MemberAvatar extends StatelessWidget {
  final String name;
  final int colorIndex;
  final bool isOwner;
  final double size;

  const MemberAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.isOwner = false,
    this.size = 44,
  });

  String _getInitials(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.getWheelColor(colorIndex);
    final initials = _getInitials(name);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(size * 0.32),
              border: Border.all(
                color: AppColors.ink,
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              initials,
              style: AppTypography.buttonSmall.copyWith(
                fontSize: size * 0.40,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (isOwner)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.matahari,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 1.8),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const CustomPaint(
                  size: Size(11, 11),
                  painter: CustomCrownPainter(color: AppColors.ink, strokeWidth: 2.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

