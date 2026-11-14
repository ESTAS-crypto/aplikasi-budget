import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/putar_theme.dart';
import '../utils/sound_service.dart';

/// Tombol bertema dengan efek tekan mengikuti bayangan tanpa blur (120ms).
class StickerButton extends StatefulWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final Color? shadowColor;
  final double? borderWidth;
  final double? borderRadius;
  final double height;
  final double? width;
  final Offset? shadowOffset;
  final Offset? pressOffset;
  final bool isLarge;
  final bool autoPulse; // Untuk tombol PUTAR RODA yang berdenyut tiap 2.6s
  final EdgeInsetsGeometry? padding;

  const StickerButton({
    super.key,
    this.child,
    this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.shadowColor,
    this.borderWidth,
    this.borderRadius,
    this.height = 48.0,
    this.width,
    this.shadowOffset,
    this.pressOffset,
    this.isLarge = false,
    this.autoPulse = false,
    this.padding,
  });

  /// Factory untuk tombol besar pill (tinggi 58)
  factory StickerButton.large({
    Key? key,
    Widget? child,
    String? text,
    VoidCallback? onPressed,
    Color? backgroundColor,
    Color? textColor,
    Color? borderColor,
    Color? shadowColor,
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
      height: 58.0,
      width: width,
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
  void didUpdateWidget(covariant StickerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && _isPressed) {
      _isPressed = false;
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
    final t = context.putarTheme;
    final effectiveBg = widget.backgroundColor ?? t.primary;
    final effectiveText = widget.textColor ?? t.ink;
    final effectiveBorder = widget.borderColor ?? t.borderColor;
    final effectiveShadowColor = widget.shadowColor ?? t.shadowColor;
    final effectiveBorderWidth = widget.borderWidth ?? t.borderWidth;
    final effectiveShadowOffset = widget.shadowOffset ?? t.standardShadowOffset;
    final effectivePressOffset =
        widget.pressOffset ?? widget.shadowOffset ?? t.buttonPressOffset;

    final effectiveHeight = widget.isLarge ? 58.0 : widget.height;
    final effectiveRadius = widget.borderRadius ??
        (widget.isLarge ? t.pillButtonRadius : t.buttonRadius);
    final isDisabled = widget.onPressed == null;

    final currentOffset = _isPressed ? Offset.zero : effectiveShadowOffset;
    final translation = _isPressed ? effectivePressOffset : Offset.zero;

    Widget buttonContent = widget.child ??
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.text ?? '',
            style: widget.isLarge
                ? t.buttonLarge.copyWith(color: effectiveText)
                : t.bodyLargeBold.copyWith(color: effectiveText),
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
                ? effectiveBg.withValues(alpha: 0.5)
                : effectiveBg,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: effectiveBorder,
              width: effectiveBorderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveShadowColor,
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
