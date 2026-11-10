import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/rupiah_formatter.dart';
import '../../utils/sound_service.dart';
import '../../utils/wheel_math.dart';
import '../models/live_play_model.dart';
import '../models/group_model.dart';
import '../services/clock_sync_service.dart';
import '../../../features/wheel/wheel_painter.dart';

/// Overlay siaran putaran roda realtime penuh layar (Layar Siaran Bersama)
/// Tampil di atas layar apa pun (Catatan, Riwayat, Home, dsb.) saat anggota grup memutar roda.
/// Roda berputar sinkron identik di semua HP berdasarkan fungsi waktu (server timestamp).
class LiveSpinOverlay extends ConsumerStatefulWidget {
  final LivePlayModel play;
  final VoidCallback onDismiss;

  const LiveSpinOverlay({
    super.key,
    required this.play,
    required this.onDismiss,
  });

  @override
  ConsumerState<LiveSpinOverlay> createState() => _LiveSpinOverlayState();
}

class _LiveSpinOverlayState extends ConsumerState<LiveSpinOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _currentRotationAngle = 0.0;
  double _lastAngleForHaptic = 0.0;
  bool _hasLanded = false;
  Timer? _dismissTimer;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;

  // Animasi flick pointer atas saat melewati batas irisan
  double _pointerFlickAngle = 0.0;

  late final List<int> _slots;
  final Map<int, TextPainter> _cachedTextPainters = {};

  @override
  void initState() {
    super.initState();

    // Ambil slots dari parameter live play atau fallback
    if (widget.play.params['slots'] is List) {
      _slots = (widget.play.params['slots'] as List).cast<int>();
    } else {
      _slots = List<int>.from(GroupModel.defaultSlots);
    }

    _buildTextPainters();

    final clockSync = ref.read(clockSyncServiceProvider);
    final nowMs = clockSync.serverNowMs;

    // Jika siaran sudah kedaluwarsa (> durationMs + 10 detik), langsung abaikan
    if (widget.play.isExpired(nowMs)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismiss();
      });
      return;
    }

    // Jika siaran sudah selesai (progress >= 1.0), langsung tampilkan kartu hasil
    if (widget.play.isCompleted(nowMs)) {
      _hasLanded = true;
      _currentRotationAngle = widget.play.finalAngle;
      _startDismissCountdown();
      return;
    }

    // Hitung posisi sudut awal saat bergabung
    final initialProgress = widget.play.getProgress(nowMs);
    _currentRotationAngle = widget.play.getAngleAtProgress(initialProgress);
    _lastAngleForHaptic = _currentRotationAngle;

    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _buildTextPainters() {
    for (final slot in _slots) {
      final tp = TextPainter(
        text: TextSpan(
          text: RupiahFormatter.formatCompact(slot),
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: AppColors.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _cachedTextPainters[slot] = tp;
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final clockSync = ref.read(clockSyncServiceProvider);
    final nowMs = clockSync.serverNowMs;

    final progress = widget.play.getProgress(nowMs);
    final targetAngle = widget.play.getAngleAtProgress(progress);

    // Deteksi batas irisan terlewati berdasarkan perubahan sudut untuk tick suara & getaran
    if (_slots.isNotEmpty &&
        WheelMath.hasCrossedSliceBoundary(
          previousAngle: _lastAngleForHaptic,
          currentAngle: targetAngle,
          totalSlots: _slots.length,
        )) {
      _lastAngleForHaptic = targetAngle;
      SoundService.instance.play(Sfx.wheelTick1);
      HapticFeedback.selectionClick();
      setState(() {
        _pointerFlickAngle = -12.0;
      });
    } else if (_pointerFlickAngle != 0.0) {
      setState(() {
        _pointerFlickAngle = 0.0;
      });
    }

    setState(() {
      _currentRotationAngle = targetAngle;
    });

    if (progress >= 1.0 && !_hasLanded) {
      _hasLanded = true;
      _ticker.stop();
      SoundService.instance.play(Sfx.wheelLand);
      HapticFeedback.heavyImpact();
      _startDismissCountdown();
    }
  }

  void _startDismissCountdown() {
    _countdownSeconds = 3;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 1) {
          _countdownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });

    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    if (!_hasLanded) {
      try {
        _ticker.dispose();
      } catch (_) {}
    }
    _countdownTimer?.cancel();
    _dismissTimer?.cancel();
    for (final tp in _cachedTextPainters.values) {
      tp.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actorName = widget.play.startedByName.isNotEmpty
        ? widget.play.startedByName
        : 'Seseorang';
    final amountFormatted = RupiahFormatter.format(widget.play.amount);

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.ink, width: 3.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(6, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header bar dengan judul pemutar & tombol tutup
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.matahari,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.ink, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sync, size: 16, color: AppColors.ink),
                          const SizedBox(width: 6),
                          Text(
                            'SIARAN LANGSUNG',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: AppColors.ink,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Tombol Tutup X jika ingin menutup overlay lebih cepat
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 2),
                        ),
                        child: const Icon(Icons.close, size: 16, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Judul besar pemutar
                Text(
                  '$actorName memutar roda!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hasLanded
                      ? '🎯 Roda mendarat pada hasil budget!'
                      : 'Semua anggota melihat putaran bersamaan...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 20),

                // Roda Putar Besar Realtime
                SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Roda Canvas
                      RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(250, 250),
                          painter: WheelPainter(
                            slots: _slots,
                            rotationAngleDegrees: _currentRotationAngle,
                            cachedTextPainters: _cachedTextPainters,
                            isMiniPreview: false,
                            pointerFlickAngleDegrees: _pointerFlickAngle,
                          ),
                        ),
                      ),
                      // Pointer Atas (12 O'Clock)
                      Positioned(
                        top: 2,
                        child: Transform.rotate(
                          angle: _pointerFlickAngle * math.pi / 180,
                          child: const _LiveWheelPointer(),
                        ),
                      ),
                      // Pin Tengah
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.matahari,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(1.5, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Kartu Hasil Putaran (Muncul otomatis saat roda mendarat)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _hasLanded
                      ? Container(
                          key: const ValueKey('result_card'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.ink, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.ink,
                                offset: Offset(4, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'BUDGET DITENTUKAN',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: AppColors.ink,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                amountFormatted,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Menutup otomatis dalam $_countdownSeconds detik...',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('spinning_pill'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.ink, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: AppColors.ink,
                                  strokeWidth: 2.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sinkronisasi putaran...',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pointer segitiga neo-brutalist di atas roda
class _LiveWheelPointer extends StatelessWidget {
  const _LiveWheelPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 30),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(2, 2)),
      Paint()..color = AppColors.ink,
    );

    // Body
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.tomat
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
