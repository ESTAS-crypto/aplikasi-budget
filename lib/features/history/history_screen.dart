import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/group/painters/group_icons_painter.dart';
import '../../core/group/services/group_service.dart';
import '../../core/group/widgets/scope_switcher.dart';
import '../group/screens/group_history_view.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_chip.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/indonesian_date_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../data/database.dart';
import '../../data/database_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScope = ref.watch(appScopeProvider);
    if (currentScope == AppScope.grup) {
      return const GroupHistoryView();
    }

    final finishedDatesAsync = ref.watch(finishedDatesStreamProvider);
    final streak = ref.watch(currentStreakProvider);
    final unreadCount = ref.watch(unreadActivityCountProvider);

    final dates = finishedDatesAsync.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul Halaman, Tombol Notifikasi & Tombol Pengaturan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Riwayat date',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 32,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Notifikasi / Aktivitas dengan Badge
                  Semantics(
                    label: unreadCount > 0
                        ? 'Notifikasi dan aktivitas grup, $unreadCount baru'
                        : 'Notifikasi dan aktivitas grup',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        context.push('/group/activity');
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.ink, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.ink,
                                  offset: Offset(3, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const CustomPaint(
                              size: Size(20, 20),
                              painter: CustomBellPainter(
                                color: AppColors.ink,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -3,
                              top: -3,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 18),
                                height: 18,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.tomat,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: AppColors.ink, width: 1.8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$unreadCount',
                                  style: AppTypography.buttonSmall.copyWith(
                                    fontSize: 10,
                                    color: AppColors.surface,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Buka Pengaturan',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        context.push('/settings');
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(9),
                        child: const CustomPaint(
                          painter: CustomSettingsIconPainter(
                            color: AppColors.ink,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Pemilih Pribadi / Grup (ScopeSwitcher)
              ScopeSwitcher(
                currentScope: AppScope.pribadi,
                onScopeChanged: (newScope) {
                  ref.read(appScopeProvider.notifier).state = newScope;
                },
              ),
              const SizedBox(height: 14),

              // Kartu Matahari Hero: "Beruntun lolos budget"
              StickerCard.hero(
                backgroundColor: AppColors.matahari,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beruntun lolos budget',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$streak minggu',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 42,
                        color: AppColors.ink,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 7 Batang Mingguan Berwarna yang Tumbuh dari Bawah Berurutan
                    SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _AnimatedBar(index: 0, heightFraction: 0.45, color: AppColors.tomat),
                          _AnimatedBar(index: 1, heightFraction: 0.72, color: AppColors.jeruk),
                          _AnimatedBar(index: 2, heightFraction: 0.40, color: AppColors.matahari),
                          _AnimatedBar(index: 3, heightFraction: 1.00, color: AppColors.mint),
                          _AnimatedBar(index: 4, heightFraction: 0.65, color: AppColors.langit),
                          _AnimatedBar(index: 5, heightFraction: 0.85, color: AppColors.lavender),
                          _AnimatedBar(index: 6, heightFraction: 0.55, color: AppColors.permen),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Bagian "Date sebelumnya"
              Text(
                'Date sebelumnya',
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),

              if (dates.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'Belum ada riwayat kencan.\nSelesaikan date pertama kamu!',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dates.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    return _DateHistoryCard(date: date);
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Batang grafik bertumbuh dari bawah berurutan
class _AnimatedBar extends StatefulWidget {
  final int index;
  final double heightFraction;
  final Color color;

  const _AnimatedBar({
    required this.index,
    required this.heightFraction,
    required this.color,
  });

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heightAnimation = Tween<double>(begin: 0.0, end: widget.heightFraction).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Staggered delay 100ms per batang
    final delayMs = widget.index * 100;
    if (delayMs == 0) {
      _controller.forward();
    } else {
      _timer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _heightAnimation,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: 110 * _heightAnimation.value.clamp(0.06, 1.0),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.ink,
                    width: 2.8,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Kartu Riwayat Date per item
class _DateHistoryCard extends ConsumerWidget {
  final DateRecord date;

  const _DateHistoryCard({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final isPassed = date.isPassed ?? true;
    final dateFormatted = IndonesianDateFormatter.fullDayAndDate(date.startedAt);

    return FutureBuilder<List<DateItemRecord>>(
      future: db.getItemsForDate(date.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final totalSpent = items.fold(0, (sum, i) => sum + i.price);
        final diff = (totalSpent - date.budget).abs();

        return GestureDetector(
          onTap: () {
            SoundService.instance.play(Sfx.uiTap);
            context.push('/date-result/${date.id}');
          },
          child: StickerCard(
            backgroundColor: AppColors.surface,
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormatted,
                        style: AppTypography.bodyLargeBold.copyWith(
                          color: AppColors.ink,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Budget ${RupiahFormatter.format(date.budget)} · terpakai ${RupiahFormatter.formatRb(totalSpent)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Lencana Lolos (Mint) / Lewat (Tomat)
                StickerChip(
                  label: isPassed ? 'Lolos' : 'Lewat ${RupiahFormatter.formatRb(diff)}',
                  backgroundColor: isPassed ? AppColors.mint : AppColors.tomat,
                  textColor: AppColors.ink,
                  borderColor: AppColors.ink,
                  borderWidth: 2.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
