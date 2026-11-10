import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/sound_service.dart';

/// Tombol neo-brutalist dengan efek tekan translate (4,4) dan shadow menghilang (120ms).
class StickerButton extends StatefulWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Color shadowColor;
  final double borderWidth;
  final double borderRadius;
  final double height;
  final double? width;
  final Offset shadowOffset;
  final bool isLarge;
  final bool autoPulse; // Untuk tombol PUTAR RODA yang berdenyut tiap 2.6s
  final EdgeInsetsGeometry? padding;

  const StickerButton({
    super.key,
    this.child,
    this.text,
    this.onPressed,
    this.backgroundColor = AppColors.tomat,
    this.textColor = AppColors.ink,
    this.borderColor = AppColors.ink,
    this.shadowColor = AppColors.ink,
    this.borderWidth = 3.0,
    this.borderRadius = 22.0,
    this.height = 48.0,
    this.width,
    this.shadowOffset = const Offset(4, 4),
    this.isLarge = false,
    this.autoPulse = false,
    this.padding,
  });

  /// Factory untuk tombol besar pill (tinggi 58, radius 29, shadow 4,4)
  factory StickerButton.large({
    Key? key,
    Widget? child,
    String? text,
    VoidCallback? onPressed,
    Color backgroundColor = AppColors.tomat,
    Color textColor = AppColors.ink,
    Color borderColor = AppColors.ink,
    Color shadowColor = AppColors.ink,
    double? width = double.infinity,
    bool autoPulse = false,
  }) {
    return StickerButton(
      key: key,
      text: text,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      textColor: textColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      borderWidth: 3.0,
      borderRadius: 29.0,
      height: 58.0,
      width: width,
      shadowOffset: const Offset(4, 4),
      isLarge: true,
      autoPulse: autoPulse,
      child: child,
    );
  }

  @override
  State<StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<StickerButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.autoPulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();

      // Denyut halus tiap 2.6 detik
      _pulseAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.04)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 15,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.04, end: 0.98)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 15,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.98, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 15,
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(1.0),
          weight: 55, // istirahat sejenak
        ),
      ]).animate(_pulseController!);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    HapticFeedback.selectionClick();
    SoundService.instance.play(Sfx.uiTap);
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.isLarge ? 58.0 : widget.height;
    final effectiveRadius = widget.isLarge ? 29.0 : widget.borderRadius;
    final isDisabled = widget.onPressed == null;

    final currentOffset = _isPressed ? Offset.zero : widget.shadowOffset;
    final translation = _isPressed ? widget.shadowOffset : Offset.zero;

    Widget buttonContent = widget.child ??
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.text ?? '',
            style: widget.isLarge
                ? AppTypography.buttonLarge.copyWith(color: widget.textColor)
                : AppTypography.bodyLargeBold.copyWith(color: widget.textColor),
          ),
        );

    Widget button = Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.text,
      child: GestureDetector(
        onTapDown: isDisabled ? null : _handleTapDown,
        onTapUp: isDisabled ? null : _handleTapUp,
        onTapCancel: isDisabled ? null : _handleTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(translation.dx, translation.dy, 0),
          width: widget.width,
          height: effectiveHeight,
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: Alignment.center,
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isDisabled
                ? widget.backgroundColor.withValues(alpha: 0.5)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: widget.borderColor,
              width: widget.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor,
                offset: currentOffset,
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: buttonContent,
        ),
      ),
    );

    if (widget.autoPulse && _pulseAnimation != null && !isDisabled) {
      button = AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation!.value,
            child: child,
          );
        },
        child: button,
      );
    }

    return button;
  }
}
