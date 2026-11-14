import 'package:flutter/material.dart';
import '../theme/putar_theme.dart';
import '../painters/sticker_icons.dart';
import '../utils/rupiah_formatter.dart';
import '../utils/sound_service.dart';

/// Controller & Helper untuk menampilkan Banner Notifikasi Atas 80% (Overlay)
class InAppBanner {
  static OverlayEntry? _currentEntry;

  static void showWarning80(
    BuildContext context, {
    required int remainingBudget,
    required double spentPercentage,
    VoidCallback? onTap,
  }) {
    dismiss();

    SoundService.instance.play(Sfx.notifWarning);

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _BannerWidget(
        remainingBudget: remainingBudget,
        spentPercentage: spentPercentage,
        onDismiss: () => dismiss(),
        onTap: onTap,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _BannerWidget extends StatefulWidget {
  final int remainingBudget;
  final double spentPercentage;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _BannerWidget({
    required this.remainingBudget,
    required this.spentPercentage,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Animasi jatuh dari atas lalu mantul (easeOutBack)
    _slideAnimation = Tween<double>(begin: -150.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto dismiss setelah 5 detik
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  void _dismissWithAnimation() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final progress = widget.spentPercentage.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          top: topPadding + 10 + _slideAnimation.value,
          left: 16,
          right: 16,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                _dismissWithAnimation();
              }
            },
            onTap: () {
              widget.onTap?.call();
              _dismissWithAnimation();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.warning,
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  border: Border.all(
                    color: t.borderColor,
                    width: t.borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.shadowColor,
                      offset: t.standardShadowOffset,
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ikon Peringatan
                        Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 12),
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: t.ink,
                              strokeWidth: 2.8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sisa ${RupiahFormatter.format(widget.remainingBudget)} lagi',
                                style: t.titleMedium.copyWith(
                                  color: t.ink,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sudah ${(progress * 100).toInt()}% terpakai. Pilih jajan yang hemat dulu ya.',
                                style: t.bodySmall.copyWith(
                                  color: t.ink,
                                  fontWeight: t.weightSemiBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Bar mini progres berborder ink
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: t.borderColor,
                          width: t.subtleBorderWidth,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          color: t.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
