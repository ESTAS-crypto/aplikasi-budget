import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../painters/group_icons_painter.dart';
import '../sync/sync_state.dart';

/// Neo-Brutalist Strip Status Sinkronisasi
/// Ditampilkan di bagian atas layar grup dengan animasi transisi & debounce anti-kedip
class SyncStrip extends StatefulWidget {
  final SyncState state;
  final bool isVisible;
  final VoidCallback? onRetry;

  const SyncStrip({
    super.key,
    required this.state,
    this.isVisible = true,
    this.onRetry,
  });

  @override
  State<SyncStrip> createState() => _SyncStripState();
}

class _SyncStripState extends State<SyncStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.state == SyncState.menyinkronkan) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SyncStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == SyncState.menyinkronkan) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else {
      if (_spinController.isAnimating) {
        _spinController.stop();
        _spinController.reset();
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(SyncState state) {
    switch (state) {
      case SyncState.tersinkron:
        return AppColors.mint;
      case SyncState.menunggu:
        return AppColors.jeruk;
      case SyncState.menyinkronkan:
        return AppColors.langit;
      case SyncState.offline:
        return AppColors.matahari;
      case SyncState.gagal:
        return AppColors.tomat;
    }
  }

  Widget _buildIcon(SyncState state) {
    switch (state) {
      case SyncState.tersinkron:
        return CustomPaint(
          size: const Size(18, 18),
          painter: const CustomCheckPainter(color: AppColors.ink),
        );
      case SyncState.menunggu:
        return CustomPaint(
          size: const Size(18, 18),
          painter: const CustomClockPainter(color: AppColors.ink),
        );
      case SyncState.menyinkronkan:
        return AnimatedBuilder(
          animation: _spinController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _spinController.value * 2 * math.pi,
              child: child,
            );
          },
          child: CustomPaint(
            size: const Size(18, 18),
            painter: const CustomSyncArrowsPainter(color: AppColors.ink),
          ),
        );
      case SyncState.offline:
        return CustomPaint(
          size: const Size(20, 18),
          painter: const CustomCloudOfflinePainter(color: AppColors.ink),
        );
      case SyncState.gagal:
        return CustomPaint(
          size: const Size(18, 18),
          painter: const CustomWarningTrianglePainter(color: AppColors.ink),
        );
    }
  }

  String _getMessage(SyncState state) {
    switch (state) {
      case SyncState.tersinkron:
        return 'Semua data tersinkron';
      case SyncState.menunggu:
        return 'Menunggu jaringan untuk mengirim';
      case SyncState.menyinkronkan:
        return 'Sedang menyinkronkan data...';
      case SyncState.offline:
        return 'Offline: Menggunakan data di HP ini';
      case SyncState.gagal:
        return 'Gagal sinkron ke server';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(widget.state);
    final message = _getMessage(widget.state);

    return AnimatedSlide(
      offset: widget.isVisible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Semantics(
          liveRegion: true,
          label: 'Status sinkronisasi: $message',
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.ink,
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                _buildIcon(widget.state),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.state == SyncState.gagal && widget.onRetry != null) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Coba lagi sinkronisasi data',
                    child: GestureDetector(
                      onTap: widget.onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.ink,
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          'Coba lagi',
                          style: AppTypography.buttonSmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

