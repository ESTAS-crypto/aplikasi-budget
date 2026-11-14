import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';

/// Kartu neo-brutalist dengan border tebal dan bayangan keras tanpa blur.
class StickerCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final double? borderWidth;
  final double? borderRadius;
  final Offset? shadowOffset;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isHero;
  final VoidCallback? onTap;

  const StickerCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.borderWidth,
    this.borderRadius,
    this.shadowOffset,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.isHero = false,
    this.onTap,
  });

  /// Factory untuk kartu hero
  factory StickerCard.hero({
    Key? key,
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
    Color? shadowColor,
    EdgeInsetsGeometry? padding = const EdgeInsets.all(20.0),
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return StickerCard(
      key: key,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: padding,
      margin: margin,
      isHero: true,
      onTap: onTap,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final effectiveBg =
        backgroundColor ?? (isHero ? t.warning : t.surface);
    final effectiveBorder = borderColor ?? t.borderColor;
    final effectiveShadowColor = shadowColor ?? t.shadowColor;
    final effectiveRadius = borderRadius ?? t.cardRadius;
    final effectiveShadow = shadowOffset ??
        (isHero ? t.heroShadowOffset : t.standardShadowOffset);
    final effectiveBorderWidth = borderWidth ??
        (isHero ? t.heroBorderWidth : t.borderWidth);

    Widget cardBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: effectiveBorder,
          width: effectiveBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveShadowColor,
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
