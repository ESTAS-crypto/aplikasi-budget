import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
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

  Color _getBackgroundColor(PutarTheme t, SyncState state) {
    switch (state) {
      case SyncState.tersinkron:
        return t.success;
      case SyncState.menunggu:
        return t.accentOrange;
      case SyncState.menyinkronkan:
        return t.accentBlue;
      case SyncState.offline:
        return t.secondary;
      case SyncState.gagal:
        return t.danger;
    }
  }

  Widget _buildIcon(PutarTheme t, SyncState state) {
    switch (state) {
      case SyncState.tersinkron:
        return CustomPaint(
          size: const Size(18, 18),
          painter: CustomCheckPainter(color: t.ink),
        );
      case SyncState.menunggu:
        return CustomPaint(
          size: const Size(18, 18),
          painter: CustomClockPainter(color: t.ink),
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
            painter: CustomSyncArrowsPainter(color: t.ink),
          ),
        );
      case SyncState.offline:
        return CustomPaint(
          size: const Size(20, 18),
          painter: CustomCloudOfflinePainter(color: t.ink),
        );
      case SyncState.gagal:
        return CustomPaint(
          size: const Size(18, 18),
          painter: CustomWarningTrianglePainter(color: t.ink),
        );
    }
  }

  String _getMessage(PutarTheme t, SyncState state) {
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
        return '${t.text(PutarCopyKeys.syncFailed)} sinkron ke server';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final bgColor = _getBackgroundColor(t, widget.state);
    final message = _getMessage(t, widget.state);

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
                color: t.ink,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: t.ink,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                _buildIcon(t, widget.state),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: t.bodySmall.copyWith(
                      color: t.ink,
                      fontWeight: t.weightBold,
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
                          color: t.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: t.ink,
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.ink,
                              offset: const Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          'Coba lagi',
                          style: t.buttonSmall.copyWith(
                            fontSize: 11,
                            fontWeight: t.weightExtraBold,
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

