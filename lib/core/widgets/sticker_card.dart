import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Kartu neo-brutalist dengan border tebal 3px dan bayangan keras tanpa blur.
class StickerCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double borderWidth;
  final double borderRadius;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isHero;
  final VoidCallback? onTap;

  const StickerCard({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.ink,
    this.shadowColor = AppColors.ink,
    this.borderWidth = 3.0,
    this.borderRadius = 22.0,
    this.shadowOffset = const Offset(4, 4),
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.isHero = false,
    this.onTap,
  });

  /// Factory untuk kartu hero (offset shadow 6,6)
  factory StickerCard.hero({
    Key? key,
    required Widget child,
    Color backgroundColor = AppColors.matahari,
    Color borderColor = AppColors.ink,
    Color shadowColor = AppColors.ink,
    EdgeInsetsGeometry? padding = const EdgeInsets.all(20.0),
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return StickerCard(
      key: key,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      borderWidth: 3.5,
      borderRadius: 22.0,
      shadowOffset: const Offset(6, 6),
      padding: padding,
      margin: margin,
      isHero: true,
      onTap: onTap,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveShadow = isHero ? const Offset(6, 6) : shadowOffset;
    final effectiveBorderWidth = isHero ? 3.5 : borderWidth;

    Widget cardBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: effectiveBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: effectiveShadow,
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      cardBody = GestureDetector(
        onTap: onTap,
        child: cardBody,
      );
    }

    if (margin != null) {
      cardBody = Padding(
        padding: margin!,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
