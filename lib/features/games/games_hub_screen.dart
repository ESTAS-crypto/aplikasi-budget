import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../group/screens/group_games_hub_view.dart';
import '../../core/games/game_engine.dart';
import '../../core/group/painters/group_icons_painter.dart';
import '../../core/group/services/group_service.dart';
import '../../core/group/widgets/scope_switcher.dart';
import '../../core/painters/game_icons_painter.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/sticker_button.dart';
import '../../core/widgets/sticker_card.dart';
import '../../core/widgets/sticker_snackbar.dart';
import '../../data/database_provider.dart';

/// Layar 11: Pilih Permainan (Games Hub)
/// Sesuai design/source/Games.dc.html
class GamesHubScreen extends ConsumerStatefulWidget {
  const GamesHubScreen({super.key});

  @override
  ConsumerState<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends ConsumerState<GamesHubScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _miniWheelController;

  @override
  void initState() {
    super.initState();
    // Animasi putaran roda mini: 12 detik linear infinite
    _miniWheelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _miniWheelController.dispose();
    super.dispose();
  }

  void _navigateToGame(GameType gameType) {
    SoundService.instance.play(Sfx.uiTap);

    switch (gameType) {
      case GameType.wheel:
        context.push('/wheel-game');
        break;
      case GameType.dice:
        context.push('/dice-game');
        break;
      case GameType.capsule:
        context.push('/capsule-game');
        break;
      case GameType.envelope:
        context.push('/envelope-game');
        break;
      case GameType.coin:
        context.push('/coin-game');
        break;
    }
  }

  void _chooseRandomGame() {
    SoundService.instance.play(Sfx.uiTap);
    final activeGames = [
      GameType.wheel,
      GameType.dice,
      GameType.capsule,
      GameType.envelope,
      GameType.coin,
    ];
    final selected = activeGames[math.Random.secure().nextInt(activeGames.length)];
    _navigateToGame(selected);
  }

  @override
  Widget build(BuildContext context) {
    final currentScope = ref.watch(appScopeProvider);
    if (currentScope == AppScope.grup) {
      return const GroupGamesHubView();
    }

    final isGroupMode = currentScope == AppScope.grup;

    final activeDateAsync = ref.watch(activeDateStreamProvider);
    final activeDate = activeDateAsync.value;
    final unreadCount = ref.watch(unreadActivityCountProvider);

    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final group = activeGroupAsync.valueOrNull ??
        (activeGroupId != null && activeGroupId.isNotEmpty
            ? ref.read(groupServiceProvider).getLocalGroup(activeGroupId)
            : null);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header dengan Tombol Notifikasi & Pengaturan
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGroupMode ? 'Main bareng teman di grup' : 'Malam ini mau main apa?',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGroupMode ? 'Permainan Grup' : 'Pilih permainan',
                          style: AppTypography.displayMedium.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 14),

              // ScopeSwitcher (Pribadi vs Grup)
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ScopeSwitcher(
                    currentScope: currentScope,
                    onScopeChanged: (newScope) {
                      ref.read(appScopeProvider.notifier).state = newScope;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Banner jika ada date aktif (Mode Pribadi)
              if (!isGroupMode && activeDate != null) ...[
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    context.go('/catatan');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.matahari,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: AppColors.ink,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ada date yang sedang berjalan!',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Budget: ${RupiahFormatter.format(activeDate.budget)} · Ketuk untuk buka Catatan',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.ink,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CustomPaint(
                            painter: CustomForwardIconPainter(
                              color: AppColors.ink,
                              strokeWidth: 3.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Info Grup Aktif / Banner Gabung Grup (Mode Grup)
              if (isGroupMode) ...[
                if (group != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.mint.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.ink, width: 2.2),
                      boxShadow: const [
                        BoxShadow(color: AppColors.ink, offset: Offset(2.5, 2.5), blurRadius: 0),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.ink, width: 1.5),
                          ),
                          child: const Icon(Icons.groups_rounded, size: 20, color: AppColors.ink),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grup: ${group.name}',
                                style: AppTypography.buttonSmall.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Kode: ${group.code} · ${group.budgetMode == "fixed" ? "Mode Angka Tetap" : "Mode Putar Roda"}',
                                style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            SoundService.instance.play(Sfx.uiTap);
                            context.push('/group/invite/${group.id}');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.ink, width: 1.8),
                            ),
                            child: Text(
                              'Kelola',
                              style: AppTypography.buttonSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: AppColors.ink, offset: Offset(3, 3), blurRadius: 0),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum Ada Grup Aktif',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Buat grup atau masukkan kode undangan untuk bermain bersama teman.',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StickerButton.large(
                          text: 'BUAT ATAU GABUNG GRUP',
                          backgroundColor: AppColors.mint,
                          textColor: AppColors.ink,
                          onPressed: () {
                            context.push('/group/join-or-create');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // Hero Card: Roda Putar (#FFD23F)
              _buildHeroWheelCard(
                title: isGroupMode ? 'Putar Jajan Grup' : 'Roda Putar',
                subtitle: isGroupMode
                    ? 'Mode aktif! Putar roda bersama anggota secara live dan sinkron.'
                    : 'Klasik. Putar roda, terima nasib.',
                badgeText: isGroupMode ? '🟢 AKTIF & SINKRON' : 'Favorit',
                badgeColor: isGroupMode ? AppColors.mint : AppColors.surface,
                onTap: isGroupMode
                    ? () {
                        SoundService.instance.play(Sfx.uiTap);
                        context.go('/roda');
                      }
                    : null,
              ),
              const SizedBox(height: 14),

              // Grid 2x2: Dadu, Kapsul, Amplop, Koin
              Row(
                children: [
                  Expanded(
                    child: _buildGameCard(
                      title: isGroupMode ? 'Kocok Dadu Grup' : 'Kocok Dadu',
                      subtitle: isGroupMode
                          ? 'Dua dadu dikali nominal budget.'
                          : 'Dua dadu, hasilnya dikali nominal.',
                      backgroundColor: AppColors.langit,
                      gameType: GameType.dice,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: AppColors.matahari,
                      isDimmed: isGroupMode,
                      onTap: isGroupMode
                          ? () => _showGameUpcomingModal(
                                context,
                                gameName: 'Kocok Dadu Bersama',
                                gameEmoji: '🎲',
                                groupName: group?.name,
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildGameCard(
                      title: isGroupMode ? 'Gacha Kapsul Grup' : 'Gacha Kapsul',
                      subtitle: isGroupMode
                          ? 'Tarik tuas gacha live bareng anggota.'
                          : 'Putar tuas, kapsul jatuh.',
                      backgroundColor: AppColors.permen,
                      gameType: GameType.capsule,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: AppColors.matahari,
                      isDimmed: isGroupMode,
                      onTap: isGroupMode
                          ? () => _showGameUpcomingModal(
                                context,
                                gameName: 'Gacha Kapsul Grup',
                                gameEmoji: '🔮',
                                groupName: group?.name,
                              )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildGameCard(
                      title: isGroupMode ? 'Pilih Amplop Grup' : 'Pilih Amplop',
                      subtitle: isGroupMode
                          ? 'Tiga amplop misteri pilihan anggota.'
                          : 'Tiga amplop, satu pilihan.',
                      backgroundColor: AppColors.mint,
                      gameType: GameType.envelope,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: AppColors.matahari,
                      isDimmed: isGroupMode,
                      onTap: isGroupMode
                          ? () => _showGameUpcomingModal(
                                context,
                                gameName: 'Pilih Amplop Grup',
                                gameEmoji: '✉️',
                                groupName: group?.name,
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildGameCard(
                      title: isGroupMode ? 'Lempar Koin Grup' : 'Lempar Koin',
                      subtitle: isGroupMode
                          ? 'Tebak koin bareng melipatgandakan budget.'
                          : 'Gandakan atau setengah.',
                      backgroundColor: AppColors.jeruk,
                      gameType: GameType.coin,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: AppColors.matahari,
                      isDimmed: isGroupMode,
                      onTap: isGroupMode
                          ? () => _showGameUpcomingModal(
                                context,
                                gameName: 'Lempar Koin Grup',
                                gameEmoji: '🪙',
                                groupName: group?.name,
                              )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tombol Acak Aja
              StickerButton(
                height: 58,
                borderRadius: 29,
                backgroundColor: AppColors.ink,
                textColor: AppColors.cream,
                shadowColor: AppColors.disabled,
                onPressed: () {
                  if (isGroupMode) {
                    SoundService.instance.play(Sfx.uiTap);
                    showStickerSnackbar(
                      context,
                      message: 'Mode grup saat ini menggunakan Putar Roda Jajan & Mode Angka Tetap.',
                    );
                    context.go('/roda');
                  } else {
                    _chooseRandomGame();
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(
                        painter: ShuffleIconPainter(
                          color: AppColors.matahari,
                          strokeWidth: 2.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Acak aja, serahkan ke aplikasi',
                          style: AppTypography.buttonLarge.copyWith(
                            color: AppColors.cream,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Banner / Tombol Atur Budget Permainan
              StickerCard(
                backgroundColor: AppColors.surface,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomPaint(
                            painter: CustomSettingsIconPainter(
                              color: AppColors.ink,
                              strokeWidth: 2.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kustomisasi Budget Game',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mau atur uang di roda, kapsul, amplop, atau kelipatan dadu? Pilih game di bawah:',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickEditChip('Atur Roda', AppColors.matahari, () {
                          context.push('/custom-wheel?game=wheel');
                        }),
                        _buildQuickEditChip('Atur Kapsul', AppColors.permen, () {
                          context.push('/custom-wheel?game=capsule');
                        }),
                        _buildQuickEditChip('Atur Amplop', AppColors.mint, () {
                          context.push('/custom-wheel?game=envelope');
                        }),
                        _buildQuickEditChip('Atur Dadu', AppColors.langit, () {
                          context.push('/dice-game');
                        }),
                        _buildQuickEditChip('Atur Koin', AppColors.jeruk, () {
                          context.push('/custom-wheel?game=coin');
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickEditChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.ink, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(2, 2),
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
                painter: CustomSettingsIconPainter(
                  color: AppColors.ink,
                  strokeWidth: 2.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.chipLabel.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroWheelCard({
    String title = 'Roda Putar',
    String subtitle = 'Klasik. Putar roda, terima nasib.',
    String badgeText = 'Favorit',
    Color badgeColor = AppColors.surface,
    VoidCallback? onTap,
  }) {
    return StickerCard.hero(
      backgroundColor: AppColors.matahari,
      padding: const EdgeInsets.all(18),
      onTap: onTap ?? () => _navigateToGame(GameType.wheel),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Mini Roda Putar 96x96 berputar kontinu 12 detik
              SizedBox(
                width: 96,
                height: 96,
                child: AnimatedBuilder(
                  animation: _miniWheelController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _miniWheelController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(96, 96),
                      painter: const _MiniWheelPainter(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Badge Favorit / Status
          Positioned(
            right: 0,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(
                badgeText,
                style: AppTypography.chipLabel.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required GameType gameType,
    String? badgeText,
    Color badgeColor = AppColors.surface,
    bool isDimmed = false,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: isDimmed ? 0.75 : 1.0,
      child: StickerCard(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.all(14),
        onTap: onTap ?? () => _navigateToGame(gameType),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: GameIconWidget(
                    gameType: gameType.name,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            if (badgeText != null)
              Positioned(
                right: 0,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: Text(
                    badgeText,
                    style: AppTypography.chipLabel.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showGameUpcomingModal(
    BuildContext context, {
    required String gameName,
    required String gameEmoji,
    String? groupName,
  }) {
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.matahari,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: Text(
                      '🛠️ MODE GRUP DALAM PENGEMBANGAN',
                      style: AppTypography.buttonSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.langit,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(gameEmoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameName,
                          style: AppTypography.titleLarge.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Multiplayer Realtime',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitur multiplayer realtime untuk $gameName sedang dalam tahap pengembangan & uji kestabilan sinkronisasi server.',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Saat ini di mode grup kamu sudah bisa menikmati:',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• 🎯 Putar Jajan (Roda) — Sinkron live 100% antar-anggota\n• 💰 Mode Angka Tetap — Budget pasti tanpa undian',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StickerButton.large(
                text: 'MAINKAN PUTAR RODA BERSAMA',
                backgroundColor: AppColors.mint,
                textColor: AppColors.ink,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(appScopeProvider.notifier).state = AppScope.grup;
                  context.go('/roda');
                },
              ),
              const SizedBox(height: 8),
              StickerButton.large(
                text: 'MENGERTI',
                backgroundColor: AppColors.surface,
                textColor: AppColors.ink,
                borderColor: AppColors.ink,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mini Roda 96x96 untuk kartu hero Games Hub
class _MiniWheelPainter extends CustomPainter {
  const _MiniWheelPainter();

  static const List<Color> _palette = [
    Color(0xFFFF6B5A), // Tomat
    Color(0xFFFF9F1C), // Jeruk
    Color(0xFFFFD23F), // Matahari
    Color(0xFF3DDBB0), // Mint
    Color(0xFF6FB1FF), // Langit
    Color(0xFFB8A4FF), // Lavender
    Color(0xFFFF8FC0), // Permen
    Color(0xFFB8E986), // Lemon
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.0;

    final borderPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final linePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const sweepAngle = (2 * math.pi) / 8;

    for (int i = 0; i < 8; i++) {
      final startAngle = i * sweepAngle;
      final fillPaint = Paint()
        ..color = _palette[i]
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    // Outer border
    canvas.drawCircle(center, radius, borderPaint);

    // Center hub
    canvas.drawCircle(center, 12, Paint()..color = AppColors.surface);
    canvas.drawCircle(center, 12, borderPaint);
    canvas.drawCircle(center, 4, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
