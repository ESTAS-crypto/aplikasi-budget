import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/putar_theme.dart';
import '../../core/games/game_engine.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_chip.dart';
import '../../core/painters/logo_painter.dart';
import '../../core/painters/mochi_painter.dart';
import '../../core/painters/paw_painter.dart';
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
  String? _builtThemeId;

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
          InAppToast.show(
            context,
            message: context.putarTheme.text(PutarCopyKeys.wheelReady),
          );
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
      final t = context.putarTheme;
      SoundService.instance.play(Sfx.uiTap);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.cardRadius),
            side: BorderSide(color: t.ink, width: t.borderWidth),
          ),
          title: Text(
            'Date Masih Aktif!',
            style: TextStyle(
              fontWeight: t.weightExtraBold,
              color: t.ink,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Kamu masih memiliki date yang aktif dengan budget ${RupiahFormatter.format(currentActive.budget)}.\n\nSelesaikan date yang sedang aktif di menu Catatan terlebih dahulu sebelum memulai sesi baru.',
            style: TextStyle(
              color: t.ink,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Tutup',
                style: TextStyle(
                  color: t.textDisabled,
                  fontWeight: t.weightBold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.secondary,
                foregroundColor: t.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: t.ink, width: 2),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/catatan');
              },
              child: Text(
                'Buka Catatan',
                style: TextStyle(fontWeight: t.weightExtraBold),
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

    final t = context.putarTheme;
    final slotsAsync = ref.watch(wheelSlotsStreamProvider);
    final dateCountAsync = ref.watch(currentRoundNumberProvider);
    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final currentActive = activeDateAsync.value;

    final slots = slotsAsync.value?.map((s) => s.amount).toList() ??
        [20000, 40000, 60000, 100000, 30000, 150000, 50000, 80000];

    // Rebuild text cache jika slot atau tema berubah
    if (_currentSlots.toString() != slots.toString() || _builtThemeId != t.id) {
      _currentSlots = slots;
      _builtThemeId = t.id;
      for (final tp in _textPaintersCache.values) {
        tp.dispose();
      }
      _textPaintersCache = WheelPainter.buildTextCache(slots, theme: t);
    }

    final roundNum = dateCountAsync.value ?? 1;

    final mainScrollView = SingleChildScrollView(
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
                                color: t.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: t.ink, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: t.ink,
                                    offset: t.miniShadowOffset,
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: CustomPaint(
                                size: const Size(16, 16),
                                painter: CustomBackIconPainter(
                                  color: t.ink,
                                  strokeWidth: 2.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (t.mascot != null)
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const LogoWidget(size: 36),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () {
                                      SoundService.instance.play(Sfx.uiTap);
                                      context.push('/brand-system');
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Putar Jajan',
                                        style: t.titleLarge.copyWith(
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
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
                                        style: t.titleLarge.copyWith(
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
                                    color: isMuted ? t.surface : t.secondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: t.ink, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: t.ink,
                                        offset: t.miniShadowOffset,
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: CustomPaint(
                                    size: const Size(18, 18),
                                    painter: CustomVolumeIconPainter(
                                      isMuted: isMuted,
                                      color: t.ink,
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
                              backgroundColor: t.accentPurple,
                              borderColor: t.ink,
                              textColor: t.ink,
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
                    style: t.displayMedium.copyWith(
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
                            color: t.secondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.ink,
                              width: 2.5,
                            ),
                          ),
                          child: Text(
                            'berapa?',
                            style: t.displayMedium.copyWith(
                              fontSize: 28,
                              color: t.ink,
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
                t.text(PutarCopyKeys.wheelSubtitle),
                style: t.bodyMedium.copyWith(
                  color: t.textSecondary,
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
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.ink, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: t.ink,
                          offset: const Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: t.ink,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Date aktif: ${RupiahFormatter.format(currentActive.budget)} · Buka Catatan →',
                          style: t.bodySmall.copyWith(
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
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

              if (t.wheelDecor == PutarWheelDecor.ears)
                const SizedBox(height: 18),

              // 3. Roda Putar 300dp dengan pointer & dekorasi bertema
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
                                  pointerFlickAngleDegrees: WheelMath.calculatePointerFlickAngle(
                                    currentAngle: _currentRotationAngle,
                                    totalSlots: _currentSlots.length,
                                  ),
                                  cachedTextPainters: _textPaintersCache,
                                  theme: t,
                                  paintHubMascot: t.mascot == null,
                                  mochiExpression: _isSpinning
                                      ? MochiExpression.wow
                                      : MochiExpression.normal,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (t.mascot == PutarMascotKind.mochi)
                        MochiWidget(
                          size: 52,
                          expression: _isSpinning
                              ? MochiExpression.wow
                              : MochiExpression.normal,
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
                    backgroundColor: t.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Budget kamu malam ini:',
                          style: t.bodyMedium.copyWith(
                            color: t.ink,
                            fontWeight: t.weightBold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RupiahFormatter.format(_wonAmount!),
                          style: t.displayLarge.copyWith(
                            fontSize: 34,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StickerButton(
                          width: double.infinity,
                          height: 48,
                          text: 'Mulai Ngedate!',
                          backgroundColor: t.danger,
                          textColor: t.ink,
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
                backgroundColor: t.danger,
                textColor: t.ink,
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
                    style: t.bodyLargeBold.copyWith(
                      color: t.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: t.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: t.pointerStyle == PutarIconStyle.kucing
            ? Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 68,
                              left: -6,
                              child: _buildPawWatermark(t, 38, -0.35),
                            ),
                            Positioned(
                              top: 220,
                              right: 8,
                              child: _buildPawWatermark(t, 34, 0.4),
                            ),
                            Positioned(
                              bottom: 84,
                              left: 16,
                              child: _buildPawWatermark(t, 36, 0.25),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  mainScrollView,
                ],
              )
            : mainScrollView,
      ),
    );
  }

  Widget _buildPawWatermark(PutarTheme t, double size, double angleRad) {
    return Transform.rotate(
      angle: angleRad,
      child: Opacity(
        opacity: 0.14,
        child: CustomPaint(
          size: Size(size, size),
          painter: PawPainter(
            fillColor: t.primary,
            strokeColor: t.ink,
          ),
        ),
      ),
    );
  }
}
