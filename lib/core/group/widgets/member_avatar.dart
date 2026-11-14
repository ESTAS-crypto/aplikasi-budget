import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
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
    final t = context.putarTheme;
    final bgColor = t.getWheelColor(colorIndex);
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
                color: t.ink,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: t.ink,
                  offset: t.miniShadowOffset,
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              initials,
              style: t.buttonSmall.copyWith(
                fontSize: size * 0.40,
                fontWeight: t.weightExtraBold,
                color: t.ink,
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
                  color: t.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.ink, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: t.ink,
                      offset: const Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: CustomPaint(
                  size: const Size(11, 11),
                  painter: CustomCrownPainter(color: t.ink, strokeWidth: 2.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

