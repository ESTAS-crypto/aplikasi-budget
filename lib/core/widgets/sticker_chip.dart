import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';
import '../painters/sticker_icons.dart';

/// Chip bertema dengan radius penuh (stadium) dan border ink.
class StickerChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? borderWidth;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Widget? leading;

  const StickerChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderWidth,
    this.onDelete,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.textStyle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final effectiveBg = backgroundColor ?? t.accentPurple;
    final effectiveText = textColor ?? t.ink;
    final effectiveBorder = borderColor ?? t.borderColor;
    final effectiveBorderWidth = borderWidth ?? t.subtleBorderWidth;

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
              t.chipLabel.copyWith(
                color: effectiveText,
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
                    color: effectiveText,
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
        color: effectiveBg,
        borderRadius: BorderRadius.circular(t.chipRadius), // Stadium / pill shape
        border: Border.all(
          color: effectiveBorder,
          width: effectiveBorderWidth,
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
