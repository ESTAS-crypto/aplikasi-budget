import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../painters/sticker_icons.dart';

/// Chip bergaya neo-brutalist dengan radius penuh (stadium) dan border ink.
class StickerChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Widget? leading;

  const StickerChip({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.lavender,
    this.textColor = AppColors.ink,
    this.borderColor = AppColors.ink,
    this.borderWidth = 2.5,
    this.onDelete,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.textStyle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: textStyle ??
              AppTypography.chipLabel.copyWith(
                color: textColor,
              ),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Hapus $label',
            child: GestureDetector(
              onTap: onDelete,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(
                  painter: CustomCloseIconPainter(
                    color: textColor,
                    strokeWidth: 2.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    Widget chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999), // Stadium / pill shape
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: content,
    );

    if (onTap != null) {
      chip = GestureDetector(
        onTap: onTap,
        child: chip,
      );
    }

    return chip;
  }
}
