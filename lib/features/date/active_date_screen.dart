import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/putar_theme.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_snackbar.dart';
import '../../core/widgets/sheet_inline_error_banner.dart';
import '../../core/widgets/overbudget_dialog.dart';
import '../../core/painters/mochi_painter.dart';
import '../../core/painters/paw_painter.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/budget_calculator.dart';
import '../../core/utils/indonesian_date_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../core/group/widgets/scope_switcher.dart';
import '../group/screens/group_notes_view.dart';
import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../notifications/notification_service.dart';
import '../../core/notifications/notifications.dart';

class ActiveDateScreen extends ConsumerStatefulWidget {
  final bool autoOpenAdd;

  const ActiveDateScreen({super.key, this.autoOpenAdd = false});

  @override
  ConsumerState<ActiveDateScreen> createState() => _ActiveDateScreenState();
}

class _ActiveDateScreenState extends ConsumerState<ActiveDateScreen> {
  bool _didAutoOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_didAutoOpen && mounted) {
          _didAutoOpen = true;
          _openAddExpenseSheet();
        }
      });
    }
  }

  void _openAddExpenseSheet() {
    final activeDateAsync = ref.read(activeDateStreamProvider);
    final activeDate = activeDateAsync.value;
    if (activeDate == null) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExpenseBottomSheet(
        activeDate: activeDate,
        onItemAdded: (item, previousSpent) => _handleItemAdded(item, activeDate, previousSpent),
      ),
    );
  }

  Future<void> _handleItemAdded(
    DateItemRecord item,
    DateRecord activeDate,
    int previousSpent,
  ) async {
    final newSpent = previousSpent + item.price;
    final remaining = activeDate.budget - newSpent;

    // Mainkan suara koin tercatat & haptic feedback seketika
    SoundService.instance.play(Sfx.coinRecord);
    HapticFeedback.mediumImpact();

    // 1. Tampilkan notifikasi status bar luar aplikasi (Alert & Pengingat jajan)
    try {
      await NotificationService.instance.showExpenseLoggedNotification(
        itemName: item.name,
        itemPrice: item.price,
        remainingBudget: remaining,
        totalSpent: newSpent,
        totalBudget: activeDate.budget,
      );
    } catch (_) {}

    // 2. Update notifikasi ongoing persisten (Progress bar)
    try {
      await NotificationService.instance.showOngoingDateNotification(
        remainingBudget: remaining,
        spentAmount: newSpent,
        totalBudget: activeDate.budget,
      );
    } catch (_) {}

    // 3. Cek peringatan 80% melalui satu pintu NotificationCoordinator
    if (BudgetCalculator.shouldShow80Warning(
      previousSpent: previousSpent,
      newSpent: newSpent,
      budget: activeDate.budget,
    )) {
      try {
        await NotificationCoordinator.instance.dispatch(
          NotificationIntent.budget80(
            scopeId: 'local',
            sessionId: activeDate.id.toString(),
            groupOrAppName: 'Putar Jajan',
            remainingBudget: remaining,
            totalBudget: activeDate.budget,
            spentAmount: newSpent,
          ),
        );
      } catch (_) {}
    }

    // 4. Tampilkan Snackbar dengan aksi Urungkan (durasi 3 detik)
    if (mounted) {
      showStickerSnackbar(
        context,
        message: '${item.name} dicatat',
        onUndo: () async {
          SoundService.instance.play(Sfx.uiTap);
          final db = ref.read(databaseProvider);
          await db.removeItem(item.id);
          // Batalkan notifikasi pencatatan
          try {
            await NotificationService.instance.cancelExpenseLoggedNotification();
            await NotificationService.instance.showOngoingDateNotification(
              remainingBudget: activeDate.budget - previousSpent,
              spentAmount: previousSpent,
              totalBudget: activeDate.budget,
            );
          } catch (_) {}
        },
      );
    }
  }

  Future<void> _finishCurrentDate(DateRecord activeDate, List<DateItemRecord> items) async {
    final totalSpent = items.fold(0, (sum, item) => sum + item.price);
    final isPassed = totalSpent <= activeDate.budget;

    final t = context.putarTheme;

    // Dialog konfirmasi penutupan sesi date
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius),
          side: BorderSide(color: t.ink, width: t.borderWidth),
        ),
        title: Text(
          'Selesaikan Date?',
          style: TextStyle(
            fontWeight: t.weightExtraBold,
            color: t.ink,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Date malam ini akan ditutup dengan total belanja ${RupiahFormatter.format(totalSpent)} dari budget ${RupiahFormatter.format(activeDate.budget)}.\n\nLanjutkan?',
          style: TextStyle(
            color: t.ink,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Selesaikan',
              style: TextStyle(fontWeight: t.weightExtraBold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    SoundService.instance.play(Sfx.uiTap);

    final db = ref.read(databaseProvider);
    await db.finishDate(activeDate.id, isPassed);

    // Hapus ongoing notification
    try {
      await NotificationService.instance.cancelOngoingNotification();
    } catch (_) {}

    // Jika lolos, kirim notifikasi streak melalui NotificationCoordinator
    if (isPassed) {
      try {
        final currentStreak = ref.read(currentStreakProvider);
        await NotificationCoordinator.instance.dispatch(
          NotificationIntent.streakCelebration(
            streakWeeks: currentStreak + 1,
            date: DateTime.now(),
          ),
        );
      } catch (_) {}
    }

    if (mounted) {
      context.go('/date-result/${activeDate.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentScope = ref.watch(appScopeProvider);
    if (currentScope == AppScope.grup) {
      return GroupNotesView(autoOpenAdd: widget.autoOpenAdd);
    }

    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final itemsAsync = ref.watch(activeDateItemsStreamProvider);

    final activeDate = activeDateAsync.value;
    final items = itemsAsync.value ?? [];
    final t = context.putarTheme;

    if (activeDate == null) {
      // Tidak ada date yang sedang aktif
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ScopeSwitcher(
                    currentScope: AppScope.pribadi,
                    onScopeChanged: (newScope) {
                      ref.read(appScopeProvider.notifier).state = newScope;
                    },
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: t.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.ink, width: t.heroBorderWidth),
                            boxShadow: [
                              BoxShadow(
                                color: t.shadowColor,
                                offset: t.standardShadowOffset,
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CustomPaint(
                              painter: CustomWarningIconPainter(
                                color: t.ink,
                                markColor: t.ink,
                                strokeWidth: 3.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Belum ada date yang berjalan',
                          style: t.displayMedium.copyWith(
                            fontSize: 24,
                            color: t.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Putar roda dulu untuk menentukan batas maksimal jajan malam ini!',
                          style: t.bodyMedium.copyWith(
                            color: t.textSecondary,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        StickerButton.large(
                          text: 'PUTAR RODA SEKARANG',
                          backgroundColor: t.danger,
                          textColor: t.ink,
                          onPressed: () => context.go('/roda'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalSpent = items.fold(0, (sum, it) => sum + it.price);
    final remaining = activeDate.budget - totalSpent;
    final progress = activeDate.budget > 0 ? (totalSpent / activeDate.budget) : 1.0;
    final statusColor = BudgetCalculator.getStatusColor(
      spent: totalSpent,
      budget: activeDate.budget,
      theme: t,
    );

    // Format tanggal
    final dateString = IndonesianDateFormatter.dayWithNight(activeDate.startedAt);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScopeSwitcher(
                      currentScope: AppScope.pribadi,
                      onScopeChanged: (newScope) {
                        ref.read(appScopeProvider.notifier).state = newScope;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Header: subtitle + tanggal (+ badge status di tema Kucing)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lagi ngedate',
                                style: t.bodySmall.copyWith(
                                  fontWeight: t.weightBold,
                                  color: t.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateString.isNotEmpty ? dateString : 'Malam ini',
                                style: t.displayMedium.copyWith(
                                  fontSize: 32,
                                  color: t.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (t.mascot != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 0,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 155),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: remaining >= 0
                                    ? t.success
                                    : t.softDangerBg,
                                borderRadius:
                                    BorderRadius.circular(t.chipRadius),
                                border: Border.all(
                                  color: t.ink,
                                  width: t.borderWidth,
                                ),
                              ),
                              child: Text(
                                remaining >= 0
                                    ? t.text(PutarCopyKeys.budgetSafe)
                                    : t.text(PutarCopyKeys.budgetOverShort),
                                style: t.chipLabel.copyWith(
                                  color: t.ink,
                                  fontWeight: t.weightBold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: t.mascot != null ? 4 : 16),

                    // Kartu Matahari Hero: Sisa Budget (+ Mochi mengintip di tema Kucing)
                    Builder(
                      builder: (context) {
                        final heroCard = StickerCard.hero(
                          backgroundColor: t.secondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sisa budget',
                                style: t.bodyLargeBold.copyWith(
                                  fontSize: 16,
                                  color: t.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Angka sisa besar "Rp36.000"
                              Text(
                                remaining >= 0
                                    ? RupiahFormatter.format(remaining)
                                    : '-${RupiahFormatter.format(remaining.abs())}',
                                style: t.displayLarge.copyWith(
                                  fontSize: 42,
                                  color: t.ink,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Bar progres berborder ink dengan animasi terisi halus
                              Container(
                                height: 20,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: t.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: t.ink,
                                    width: t.borderWidth,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0.0,
                                        end: progress.clamp(0.0, 1.0),
                                      ),
                                      duration:
                                          const Duration(milliseconds: 600),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, val, child) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: constraints.maxWidth * val,
                                            color: statusColor,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),

                              // "Terpakai Rp64.000 dari Rp100.000"
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Terpakai ${RupiahFormatter.format(totalSpent)}',
                                      style: t.bodySmall.copyWith(
                                        fontWeight: t.weightBold,
                                        color: t.ink,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'dari ${RupiahFormatter.format(activeDate.budget)}',
                                      style: t.bodySmall.copyWith(
                                        fontWeight: t.weightBold,
                                        color: t.ink,
                                      ),
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );

                        if (t.mascot != PutarMascotKind.mochi) {
                          return heroCard;
                        }

                        return Stack(
                          children: [
                            Positioned(
                              right: 22,
                              top: 2,
                              child: MochiWidget(
                                size: 76,
                                expression: remaining < 0
                                    ? MochiExpression.sad
                                    : MochiExpression.normal,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 46),
                              child: heroCard,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Judul Bagian: "Jajan malam ini"
                    Text(
                      'Jajan malam ini',
                      style: t.titleLarge.copyWith(
                        fontSize: 20,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Daftar Item Jajan dengan animasi staggered slide-in (jeda 150ms)
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Belum ada jajan yang dicatat.\nTekan tombol di bawah untuk mencatat!',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium.copyWith(
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(items.length, (index) {
                        final item = items[index];
                        final dotColor = t.getWheelColor(index);
                        return _StaggeredItemCard(
                          key: ValueKey(item.id),
                          index: index,
                          dotColor: dotColor,
                          name: item.name,
                          price: item.price,
                          onDelete: () async {
                            final db = ref.read(databaseProvider);
                            await db.removeItem(item.id);
                          },
                        );
                      }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bagian Bawah: Tombol Selesaikan & Tombol "Catat jajan"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (items.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _finishCurrentDate(activeDate, items),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Selesaikan date malam ini',
                          style: t.bodyLargeBold.copyWith(
                            color: t.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                  StickerButton.large(
                    text: 'Catat jajan',
                    backgroundColor: t.danger,
                    textColor: t.ink,
                    onPressed: _openAddExpenseSheet,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item belanja kartu dengan staggered slide-in (150ms per item)
class _StaggeredItemCard extends StatefulWidget {
  final int index;
  final Color dotColor;
  final String name;
  final int price;
  final VoidCallback onDelete;

  const _StaggeredItemCard({
    super.key,
    required this.index,
    required this.dotColor,
    required this.name,
    required this.price,
    required this.onDelete,
  });

  @override
  State<_StaggeredItemCard> createState() => _StaggeredItemCardState();
}

class _StaggeredItemCardState extends State<_StaggeredItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Staggered delay 150ms * index
    final delayMs = math.min(widget.index * 150, 900);
    if (delayMs == 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: StickerCard(
            backgroundColor: t.surface,
            borderRadius: t.cardRadius,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Penanda item: tapak kucing (Kucing Manis) atau titik bulat (Pasar Malam)
                if (t.iconStyle == PutarIconStyle.kucing)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(
                      painter: PawPainter(
                        fillColor: widget.dotColor,
                        strokeColor: t.ink,
                        strokeWidth: 2.2,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: widget.dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: t.ink,
                        width: 2.2,
                      ),
                    ),
                  ),
                const SizedBox(width: 14),
                // Nama jajan
                Expanded(
                  child: Text(
                    widget.name,
                    style: t.bodyLargeBold.copyWith(
                      color: t.ink,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Harga jajan
                Text(
                  RupiahFormatter.format(widget.price),
                  style: t.bodyLargeBold.copyWith(
                    color: t.ink,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol hapus silang
                GestureDetector(
                  onTap: widget.onDelete,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CustomPaint(
                      painter: CustomCloseIconPainter(
                        color: t.textDisabled,
                        strokeWidth: 2.4,
                      ),
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

/// Bottom Sheet Input Catat Jajan
class _AddExpenseBottomSheet extends ConsumerStatefulWidget {
  final DateRecord activeDate;
  final Function(DateItemRecord item, int previousSpent) onItemAdded;

  const _AddExpenseBottomSheet({
    required this.activeDate,
    required this.onItemAdded,
  });

  @override
  ConsumerState<_AddExpenseBottomSheet> createState() =>
      _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends ConsumerState<_AddExpenseBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final rawName = _nameController.text.trim();
    final name = rawName.isEmpty ? 'Jajan' : rawName;
    final parsedPrice = RupiahFormatter.parse(_priceController.text);
    if (parsedPrice <= 0) {
      SoundService.instance.play(Sfx.uiTap);
      setState(() => _errorMessage = 'Masukkan nominal harga jajan');
      _priceFocusNode.requestFocus();
      return;
    }
    final price = parsedPrice;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final currentItems = await db.getItemsForDate(widget.activeDate.id);
      final currentSpent = currentItems.fold(0, (sum, i) => sum + i.price);
      final newTotalSpent = currentSpent + price;

      // Cek apakah jajan ini menyebabkan budget lewat (100%+)
      if (newTotalSpent > widget.activeDate.budget) {
        final excess = newTotalSpent - widget.activeDate.budget;
        if (!mounted) return;
        final proceed = await showOverbudgetDialog(context, excessAmount: excess);
        if (proceed != true) {
          // Pengguna memilih "Hapus item"
          return;
        }
      }

      final itemId = await db.addItem(
        dateId: widget.activeDate.id,
        name: name,
        price: price,
      );

      final newItem = DateItemRecord(
        id: itemId,
        dateId: widget.activeDate.id,
        name: name,
        price: price,
        createdAt: DateTime.now(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onItemAdded(newItem, currentSpent);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal menyimpan jajan. Coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset > 0 ? bottomInset + 16 : bottomPadding + 20,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.sheetRadius)),
        border: Border(
          top: BorderSide(color: t.ink, width: t.heroBorderWidth),
          left: BorderSide(color: t.ink, width: t.heroBorderWidth),
          right: BorderSide(color: t.ink, width: t.heroBorderWidth),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: t.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'Catat Jajan',
              style: t.titleLarge.copyWith(
                fontSize: 22,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 16),

            // Input Nama Jajan
            Text(
              'Nama Jajan / Makanan',
              style: t.bodySmall.copyWith(
                fontWeight: t.weightBold,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.ink, width: t.subtleBorderWidth),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: false,
                onChanged: (_) => _clearError(),
                style: t.bodyLargeBold.copyWith(color: t.ink),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Misal: Sate taichan',
                  hintStyle: TextStyle(color: t.textDisabled),
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _priceFocusNode.requestFocus(),
              ),
            ),
            const SizedBox(height: 14),

            // Input Harga Jajan
            Text(
              'Harga',
              style: t.bodySmall.copyWith(
                fontWeight: t.weightBold,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.ink, width: t.subtleBorderWidth),
              ),
              child: Row(
                children: [
                  Text(
                    'Rp ',
                    style: t.titleMedium.copyWith(
                      color: t.danger,
                      fontWeight: t.weightExtraBold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      focusNode: _priceFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [ThousandsSeparatorInputFormatter()],
                      onChanged: (_) => _clearError(),
                      style: t.titleMedium.copyWith(color: t.ink),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '32.000',
                        hintStyle: TextStyle(color: t.textDisabled),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SheetInlineErrorBanner(message: _errorMessage),

            // Tombol Simpan Jajan
            StickerButton.large(
              text: _isSaving ? 'Menyimpan...' : 'Simpan Jajan',
              backgroundColor: t.danger,
              textColor: t.ink,
              onPressed: _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
