import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
import '../../utils/sound_service.dart';
import '../painters/group_icons_painter.dart';
import '../../../features/navigation/app_router.dart';

/// Jenis Banner In-App sesuai Spesifikasi UPDATE 3 & Notif1.dc.html
enum InAppBannerCategory {
  expense,
  expenseDeleted,
  spin,
  budgetWarning80,
  budgetOver,
  sessionEnd,
  memberJoin,
  memberLeave,
  codeChanged,
}

/// Notifikasi InAppBanner yang meluncur dari atas sesuai Notif1.dc.html
/// - Background putih (#FFFFFF), border 3px ink (#22163A), radius 20px, shadow 3px 3px 0.
/// - Ikon bulat 36x36 dengan border 3px per jenis event.
/// - Judul 14px w800, Subtitle 12px w500.
/// - Turun dari atas, hilang sendiri setelah 4 detik, hanya maks 1 tampil sekaligus.
/// - Penggabungan event dalam 3 detik ("N aktivitas baru di grup").
class InAppBanner {
  static OverlayEntry? _currentEntry;
  static Timer? _debounceTimer;

  static final List<_BannerPayload> _pendingEvents = [];
  static VoidCallback? _latestOnTap;

  /// Menampilkan InAppBanner untuk aktivitas anggota LAIN atau aksi konfirmasi
  static void show(
    BuildContext context, {
    String? title,
    String? subtitle,
    String? actorName,
    String? message,
    int colorIndex = 0,
    InAppBannerCategory category = InAppBannerCategory.expense,
    Sfx? sound,
    VoidCallback? onTap,
  }) {
    // Dukungan backward-compatibility jika pemanggil lama memakai actorName & message
    final effTitle = title ?? (actorName ?? 'Aktivitas Baru');
    final effSubtitle = subtitle ?? (message ?? '');

    _latestOnTap = onTap;
    _pendingEvents.add(_BannerPayload(
      title: effTitle,
      subtitle: effSubtitle,
      category: category,
      actorName: actorName ?? 'Anggota',
      colorIndex: colorIndex,
      sound: sound,
    ));

    // Debounce / penggabungan event dalam 3 detik
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _displayBanner(context);
    });
  }

  static void _displayBanner(BuildContext context) {
    final overlay = (context.mounted ? Overlay.maybeOf(context, rootOverlay: true) : null) ??
        rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[InAppBanner] Overlay not found, cannot show banner');
      return;
    }

    // Tutup banner yang sedang aktif bila ada secara langsung
    _removeCurrentEntry();

    final count = _pendingEvents.length;
    if (count == 0) return;

    final latest = _pendingEvents.last;
    final String displayTitle;
    final String displaySubtitle;

    if (count > 1) {
      displayTitle = '$count aktivitas baru di grup';
      displaySubtitle = '${latest.title}: ${latest.subtitle}';
    } else {
      displayTitle = latest.title;
      displaySubtitle = latest.subtitle;
    }

    final category = latest.category;
    final customSound = latest.sound;
    _pendingEvents.clear();

    if (customSound != null) {
      SoundService.instance.play(customSound);
    } else if (category == InAppBannerCategory.budgetWarning80 ||
        category == InAppBannerCategory.budgetOver) {
      SoundService.instance.play(Sfx.notifWarning);
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _InAppBannerWidget(
        title: displayTitle,
        subtitle: displaySubtitle,
        category: category,
        onTap: () {
          _latestOnTap?.call();
        },
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry?.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _removeCurrentEntry() {
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }

  /// Menutup banner yang sedang tampil dan membatalkan antrean debounce
  static void dismiss() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingEvents.clear();
    _latestOnTap = null;
    _removeCurrentEntry();
  }
}

class _BannerPayload {
  final String title;
  final String subtitle;
  final InAppBannerCategory category;
  final String actorName;
  final int colorIndex;
  final Sfx? sound;

  _BannerPayload({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.actorName,
    required this.colorIndex,
    this.sound,
  });
}

class _InAppBannerWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final InAppBannerCategory category;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _InAppBannerWidget({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  State<_InAppBannerWidget> createState() => _InAppBannerWidgetState();
}

class _InAppBannerWidgetState extends State<_InAppBannerWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _exitController;

  late Animation<double> _entryY;
  late Animation<double> _entryOpacity;
  late Animation<double> _iconScale;

  late Animation<double> _exitY;
  late Animation<double> _exitOpacity;

  Timer? _stayTimer;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance Controller (420ms) sesuai @keyframes bn & ip
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // bn: 0% translateY(-80px) -> 70% translateY(5px) -> 100% translateY(0px)
    // dengan cubic-bezier(.2, 1.2, .3, 1)
    _entryY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -80.0, end: 5.0)
            .chain(CurveTween(curve: const Cubic(0.2, 1.2, 0.3, 1.0))),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 5.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_entryController);

    // bn: 0% opacity 0 -> 70% opacity 1
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
      ),
    );

    // ip: 0%, 6% scale(.5) -> 12% scale(1.18) -> 16%, 100% scale(1)
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.5),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_entryController);

    // 2. Exit Controller (320ms) sesuai @keyframes bn: 93%,100%{transform:translateY(-44px);opacity:0}
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _exitY = Tween<double>(begin: 0.0, end: -44.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Cubic(0.4, 0.0, 0.2, 1.0),
      ),
    );

    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeIn),
      ),
    );

    // Jalankan masuk, tahan 4 detik lalu keluar otomatis
    _entryController.forward().then((_) {
      if (mounted && !_isExiting) {
        _stayTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            _handleDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stayTimer?.cancel();
    _entryController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss({VoidCallback? thenCallback}) async {
    if (_isExiting) return;
    _stayTimer?.cancel();
    if (mounted) {
      setState(() => _isExiting = true);
    }
    await _exitController.forward();
    if (mounted) {
      widget.onDismissed();
      thenCallback?.call();
    }
  }

  Color _getBadgeColor(PutarTheme t, InAppBannerCategory category) {
    switch (category) {
      case InAppBannerCategory.expense:
      case InAppBannerCategory.budgetWarning80:
        return t.secondary;
      case InAppBannerCategory.expenseDeleted:
      case InAppBannerCategory.memberLeave:
        return t.bg;
      case InAppBannerCategory.spin:
        return t.accentPurple;
      case InAppBannerCategory.budgetOver:
        return t.danger;
      case InAppBannerCategory.sessionEnd:
      case InAppBannerCategory.memberJoin:
        return t.success;
      case InAppBannerCategory.codeChanged:
        return t.accentBlue;
    }
  }

  CustomPainter _getBadgePainter(PutarTheme t, InAppBannerCategory category) {
    switch (category) {
      case InAppBannerCategory.expense:
        return CustomReceiptPainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.expenseDeleted:
        return CustomTrashPainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.spin:
        return CustomWheelPainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.budgetWarning80:
      case InAppBannerCategory.budgetOver:
        return CustomWarningTrianglePainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.sessionEnd:
        return CustomFlagPainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.memberJoin:
        return CustomUserPlusPainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.memberLeave:
        return CustomUserMinusPainter(color: t.ink, strokeWidth: 2.6);
      case InAppBannerCategory.codeChanged:
        return CustomKeyPainter(color: t.ink, strokeWidth: 2.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final badgeColor = _getBadgeColor(t, widget.category);
    final badgePainter = _getBadgePainter(t, widget.category);

    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _exitController]),
      builder: (context, _) {
        final double currentY = _isExiting ? _exitY.value : _entryY.value;
        final double currentOpacity =
            (_isExiting ? _exitOpacity.value : _entryOpacity.value).clamp(0.0, 1.0);
        final double currentIconScale = _isExiting ? 1.0 : _iconScale.value;

        return Positioned(
          top: topPadding + 10,
          left: 16,
          right: 16,
          child: Transform.translate(
            offset: Offset(0, currentY),
            child: Opacity(
              opacity: currentOpacity,
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.uiTap);
                  _handleDismiss(thenCallback: widget.onTap);
                },
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < -3) {
                    _handleDismiss();
                  }
                },
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -80) {
                    // Geser ke atas untuk menutup
                    _handleDismiss();
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.ink, width: t.borderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: t.ink,
                          offset: t.smallShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Transform.scale(
                          scale: currentIconScale,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: t.ink, width: t.borderWidth),
                            ),
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(18, 18),
                              painter: badgePainter,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: t.bodySmall.copyWith(
                                  fontSize: 14,
                                  fontWeight: t.weightExtraBold,
                                  color: t.ink,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  widget.subtitle,
                                  style: t.bodySmall.copyWith(
                                    fontSize: 12,
                                    fontWeight: t.weightMedium,
                                    color: t.textSecondary,
                                    height: 1.25,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
