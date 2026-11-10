import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/games/game_engine.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_chip.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/widgets/in_app_toast.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/wheel_math.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/pop_reveal.dart';
import '../../data/database_provider.dart';
import '../notifications/notification_service.dart';
import '../../core/group/widgets/scope_switcher.dart';
import '../group/screens/group_wheel_view.dart';
import 'wheel_painter.dart';

class WheelScreen extends ConsumerStatefulWidget {
  const WheelScreen({super.key});

  @override
  ConsumerState<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends ConsumerState<WheelScreen>
    with TickerProviderStateMixin {
  static bool _hasShownInitialToast = false;

  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  late AnimationController _pointerFlickController;
  late Animation<double> _pointerFlickAnimation;

  double _currentRotationAngle = 0.0;
  double _lastAngleForHaptic = 0.0;
  bool _isSpinning = false;
  int? _wonAmount;

  // Cache TextPainters untuk performa 60fps tanpa alokasi saat render
  Map<int, TextPainter> _textPaintersCache = {};
  List<int> _currentSlots = [];

  // Pan gesture tracking
  double _panStartAngle = 0.0;
  double _panCurrentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    // Animasi pantulan lentur pointer saat menabrak pasak irisan
    _pointerFlickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _pointerFlickAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -12.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -12.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 65,
      ),
    ]).animate(_pointerFlickController);

    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      // Kurva setara cubic-bezier(.12, .7, .1, 1) sesuai spesifikasi
      curve: const Cubic(0.12, 0.7, 0.1, 1.0),
    );

    _spinAnimation.addListener(_onSpinTick);
    _spinAnimation.addStatusListener(_onSpinStatus);

    // Minta izin notifikasi Android 13+ & tampilkan Toast selamat datang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationService.instance.requestNotificationPermission(context);
        if (!_hasShownInitialToast) {
          _hasShownInitialToast = true;
          InAppToast.show(context, message: 'Roda siap diputar!');
        }
      }
    });
  }

  void _onSpinTick() {
    setState(() {
      _currentRotationAngle = _spinAnimation.value;
    });

    if (_currentSlots.isNotEmpty) {
      final crossed = WheelMath.hasCrossedSliceBoundary(
        previousAngle: _lastAngleForHaptic,
        currentAngle: _currentRotationAngle,
        totalSlots: _currentSlots.length,
      );
      if (crossed) {
        HapticFeedback.selectionClick();
        final deltaAngle = (_currentRotationAngle - _lastAngleForHaptic).abs();
        final speedRatio = (deltaAngle / 30.0).clamp(0.2, 1.0);
        SoundService.instance.playWheelTick(speed: speedRatio);
        _lastAngleForHaptic = _currentRotationAngle;
        _pointerFlickController.forward(from: 0.0);
      }
    }
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      // Suara mendarat roda tepat di slot jarum
      SoundService.instance.play(Sfx.wheelLand);

      // Suara kemenangan sedikit berjeda saat kartu nominal muncul membesar
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          SoundService.instance.play(Sfx.winLolos, volume: 0.85);
        }
      });
      final winningIndex = WheelMath.getSliceIndexAtRotation(
        rotationDegrees: _currentRotationAngle,
        totalSlots: _currentSlots.length,
      );
      setState(() {
        _isSpinning = false;
        _wonAmount = _currentSlots[winningIndex];
      });

      // Bacakan untuk TalkBack / Aksesibilitas
      if (mounted) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Budget kamu ${RupiahFormatter.format(_wonAmount!)}',
          TextDirection.ltr,
        );
      }
    }
  }

  @override
  void dispose() {
    _spinAnimation.removeListener(_onSpinTick);
    _spinAnimation.removeStatusListener(_onSpinStatus);
    _spinController.dispose();
    _pointerFlickController.dispose();
    for (final tp in _textPaintersCache.values) {
      tp.dispose();
    }
    super.dispose();
  }

  void _spinToTarget() {
    if (_isSpinning || _currentSlots.isEmpty) return;

    setState(() {
      _isSpinning = true;
      _wonAmount = null;
    });

    // Mainkan suara putaran roda tombol 6 detik
    SoundService.instance.play(Sfx.wheelSpin);

    // Hitung outcome secara deterministik menggunakan WheelGameEngine
    final engine = WheelGameEngine(slots: _currentSlots);
    final outcome = engine.play();
    final targetAngle = outcome.animationParameters['finalRotation'] as double;

    final startAngle = _currentRotationAngle % 360.0;
    _lastAngleForHaptic = startAngle;

    _spinAnimation = Tween<double>(
      begin: startAngle,
      end: startAngle + targetAngle,
    ).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: const Cubic(0.12, 0.7, 0.1, 1.0),
      ),
    );

    _spinController.forward(from: 0.0);
  }

  // Handle gesture putar manual dengan jari
  void _onPanStart(DragStartDetails details, Size wheelSize) {
    if (_isSpinning) return;
    final center = Offset(wheelSize.width / 2, wheelSize.height / 2);
    final pos = details.localPosition - center;
    _panStartAngle = math.atan2(pos.dy, pos.dx) * 180 / math.pi;
    _panCurrentAngle = _currentRotationAngle;
  }

  void _onPanUpdate(DragUpdateDetails details, Size wheelSize) {
    if (_isSpinning) return;
    final center = Offset(wheelSize.width / 2, wheelSize.height / 2);
    final pos = details.localPosition - center;
    final angle = math.atan2(pos.dy, pos.dx) * 180 / math.pi;
    final delta = angle - _panStartAngle;

    setState(() {
      _currentRotationAngle = _panCurrentAngle + delta;
    });

    if (_currentSlots.isNotEmpty) {
      final crossed = WheelMath.hasCrossedSliceBoundary(
        previousAngle: _lastAngleForHaptic,
        currentAngle: _currentRotationAngle,
        totalSlots: _currentSlots.length,
      );
      if (crossed) {
        final speedRatio = (delta.abs() / 15.0).clamp(0.0, 1.0);
        SoundService.instance.playWheelTick(speed: speedRatio);
        _lastAngleForHaptic = _currentRotationAngle;
        _pointerFlickController.forward(from: 0.0);
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSpinning || _currentSlots.isEmpty) return;
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;

    if (speed > 400) {
      // Putar berdasarkan geseran jari
      final extraTurns = (speed / 300).clamp(3, 7).toDouble();
      final totalAdd = extraTurns * 360.0;

      setState(() {
        _isSpinning = true;
        _wonAmount = null;
      });

      final start = _currentRotationAngle;
      _lastAngleForHaptic = start;

      _spinAnimation = Tween<double>(
        begin: start,
        end: start + totalAdd,
      ).animate(
        CurvedAnimation(
          parent: _spinController,
          curve: const Cubic(0.12, 0.7, 0.1, 1.0),
        ),
      );

      _spinController.forward(from: 0.0);
    } else {
      // Menetap di posisi saat dilepas
      SoundService.instance.play(Sfx.wheelLand);
      final winningIndex = WheelMath.getSliceIndexAtRotation(
        rotationDegrees: _currentRotationAngle,
        totalSlots: _currentSlots.length,
      );
      setState(() {
        _wonAmount = _currentSlots[winningIndex];
      });
    }
  }

  Future<void> _startActiveDate(int budget) async {
    final db = ref.read(databaseProvider);
    final currentActive = await db.getActiveDate();

    // Jika sudah ada sesi date yang aktif, blokir dan arahkan ke Catatan
    if (currentActive != null && mounted) {
      SoundService.instance.play(Sfx.uiTap);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.ink, width: 3),
          ),
          title: const Text(
            'Date Masih Aktif!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Kamu masih memiliki date yang aktif dengan budget ${RupiahFormatter.format(currentActive.budget)}.\n\nSelesaikan date yang sedang aktif di menu Catatan terlebih dahulu sebelum memulai sesi baru.',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: AppColors.disabled,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.matahari,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/catatan');
              },
              child: const Text(
                'Buka Catatan',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Buat sesi Date di database
    await db.createDate(budget);

    // Update notifikasi ongoing
    await NotificationService.instance.showOngoingDateNotification(
      remainingBudget: budget,
      spentAmount: 0,
      totalBudget: budget,
    );

    if (mounted) {
      // Pindah ke tab Catatan
      context.go('/catatan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentScope = ref.watch(appScopeProvider);
    if (currentScope == AppScope.grup) {
      return const GroupWheelView();
    }

    final slotsAsync = ref.watch(wheelSlotsStreamProvider);
    final dateCountAsync = ref.watch(currentRoundNumberProvider);
    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final currentActive = activeDateAsync.value;

    final slots = slotsAsync.value?.map((s) => s.amount).toList() ??
        [20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000];

    // Rebuild text cache jika slot berubah
    if (_currentSlots.toString() != slots.toString()) {
      _currentSlots = slots;
      for (final tp in _textPaintersCache.values) {
        tp.dispose();
      }
      _textPaintersCache = WheelPainter.buildTextCache(slots);
    }

    final roundNum = dateCountAsync.value ?? 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Top Header: Logo + "Putar Jajan" + Chip "Date ke-N"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Kembali ke Pilihan Permainan',
                          child: GestureDetector(
                            onTap: () {
                              SoundService.instance.play(Sfx.uiTap);
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                context.go('/');
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.ink, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.ink,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const CustomPaint(
                                size: Size(16, 16),
                                painter: CustomBackIconPainter(strokeWidth: 2.8),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              SoundService.instance.play(Sfx.uiTap);
                              context.push('/brand-system');
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const LogoWidget(size: 30),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Putar Jajan',
                                      style: AppTypography.titleLarge.copyWith(
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: SoundService.instance.isMutedNotifier,
                          builder: (context, isMuted, _) {
                            return Semantics(
                              button: true,
                              label: isMuted ? 'Aktifkan Suara' : 'Bisukan Suara',
                              child: GestureDetector(
                                onTap: () => SoundService.instance.toggleMute(),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isMuted ? AppColors.surface : AppColors.matahari,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.ink, width: 2.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.ink,
                                        offset: Offset(2, 2),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: CustomPaint(
                                    size: const Size(18, 18),
                                    painter: CustomVolumeIconPainter(
                                      isMuted: isMuted,
                                      color: AppColors.ink,
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: StickerChip(
                              label: 'Date ke-$roundNum',
                              backgroundColor: AppColors.lavender,
                              borderColor: AppColors.ink,
                              textColor: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ScopeSwitcher (Pribadi vs Grup)
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ScopeSwitcher(
                    currentScope: AppScope.pribadi,
                    onScopeChanged: (newScope) {
                      ref.read(appScopeProvider.notifier).state = newScope;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Judul Hero: "Malam ini jajannya maksimal [berapa?]"
              Align(
                alignment: Alignment.center,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 30,
                      height: 1.15,
                    ),
                    children: [
                      const TextSpan(text: 'Malam ini jajannya\nmaksimal '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.matahari,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.ink,
                              width: 2.5,
                            ),
                          ),
                          child: Text(
                            'berapa?',
                            style: AppTypography.displayMedium.copyWith(
                              fontSize: 28,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'Putar dulu, jajan di bawah angkanya.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Banner notifikasi jika sesi date sedang berjalan
              if (currentActive != null) ...[
                GestureDetector(
                  onTap: () => context.go('/catatan'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.matahari,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: AppColors.ink,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Date aktif: ${RupiahFormatter.format(currentActive.budget)} · Buka Catatan →',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 8),

              // 3. Roda Putar 300dp dengan pointer segitiga Tomat
              Center(
                child: SizedBox(
                  width: 300,
                  height: 310,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onPanStart: (d) => _onPanStart(d, const Size(300, 300)),
                        onPanUpdate: (d) => _onPanUpdate(d, const Size(300, 300)),
                        onPanEnd: _onPanEnd,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _pointerFlickAnimation,
                            builder: (context, _) {
                              return CustomPaint(
                                size: const Size(300, 300),
                                painter: WheelPainter(
                                  slots: _currentSlots,
                                  rotationAngleDegrees: _currentRotationAngle,
                                  pointerFlickAngleDegrees: _pointerFlickAnimation.value,
                                  cachedTextPainters: _textPaintersCache,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Kartu Pop-up Hasil Putaran (PopReveal sesuai @keyframes pop)
              if (_wonAmount != null && !_isSpinning) ...[
                PopReveal(
                  child: StickerCard.hero(
                    backgroundColor: AppColors.matahari,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Budget kamu malam ini:',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RupiahFormatter.format(_wonAmount!),
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 34,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StickerButton(
                          width: double.infinity,
                          height: 48,
                          text: 'Mulai Ngedate!',
                          backgroundColor: AppColors.tomat,
                          textColor: AppColors.ink,
                          onPressed: () => _startActiveDate(_wonAmount!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Tombol PUTAR RODA (Tomat, denyut otomatis tiap 2.6s)
              StickerButton.large(
                text: _isSpinning ? 'MEMUTAR...' : 'PUTAR RODA',
                backgroundColor: AppColors.tomat,
                textColor: AppColors.ink,
                autoPulse: !_isSpinning && _wonAmount == null,
                onPressed: _isSpinning ? null : () => _spinToTarget(),
              ),
              const SizedBox(height: 14),

              // 6. Tombol "Isi roda sendiri"
              GestureDetector(
                onTap: _isSpinning
                    ? null
                    : () {
                        SoundService.instance.play(Sfx.uiTap);
                        context.push('/custom-wheel');
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Isi roda sendiri',
                    style: AppTypography.bodyLargeBold.copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
