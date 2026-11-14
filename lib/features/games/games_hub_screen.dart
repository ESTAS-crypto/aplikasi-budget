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
import '../../core/theme/putar_theme.dart';
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

    final t = context.putarTheme;
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
      backgroundColor: t.bg,
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
                          style: t.bodyMedium.copyWith(
                            fontWeight: t.weightBold,
                            color: t.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGroupMode ? 'Permainan Grup' : 'Pilih permainan',
                          style: t.displayMedium.copyWith(
                            fontSize: 30,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
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
                              color: t.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: t.ink,
                                width: t.subtleBorderWidth,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: t.shadowColor,
                                  offset: t.smallShadowOffset,
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(20, 20),
                              painter: CustomBellPainter(
                                color: t.ink,
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
                                  color: t.danger,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: t.ink, width: 1.8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$unreadCount',
                                  style: t.buttonSmall.copyWith(
                                    fontSize: 10,
                                    color: t.surface,
                                    fontWeight: t.weightExtraBold,
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
                          color: t.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: t.ink,
                            width: t.subtleBorderWidth,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.shadowColor,
                              offset: t.smallShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(9),
                        child: CustomPaint(
                          painter: CustomSettingsIconPainter(
                            color: t.ink,
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
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(t.smallCardRadius),
                      border: Border.all(color: t.ink, width: t.subtleBorderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: t.smallShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomPaint(
                            painter: CustomWarningIconPainter(
                              color: t.ink,
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
                                style: t.bodySmall.copyWith(
                                  fontWeight: t.weightExtraBold,
                                  color: t.ink,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Budget: ${RupiahFormatter.format(activeDate.budget)} · Ketuk untuk buka Catatan',
                                style: t.bodySmall.copyWith(
                                  color: t.ink,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CustomPaint(
                            painter: CustomForwardIconPainter(
                              color: t.ink,
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
                      color: t.success.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.ink, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: const Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: t.success,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: t.ink, width: 1.5),
                          ),
                          child: CustomPaint(
                            size: const Size(20, 20),
                            painter: CustomGroupsIconPainter(
                              color: t.ink,
                              strokeWidth: 2.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grup: ${group.name}',
                                style: t.buttonSmall.copyWith(
                                  fontSize: 13,
                                  fontWeight: t.weightExtraBold,
                                ),
                              ),
                              Text(
                                'Kode: ${group.code} · ${group.budgetMode == "fixed" ? "Mode Angka Tetap" : "Mode Putar Roda"}',
                                style: t.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: t.textSecondary,
                                ),
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
                              color: t.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.ink, width: 1.8),
                            ),
                            child: Text(
                              'Kelola',
                              style: t.buttonSmall.copyWith(
                                fontSize: 11,
                                fontWeight: t.weightExtraBold,
                              ),
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
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.smallCardRadius),
                      border: Border.all(color: t.ink, width: t.subtleBorderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: t.smallShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum Ada Grup Aktif',
                          style: t.titleMedium.copyWith(
                            fontSize: 16,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Buat grup atau masukkan kode undangan untuk bermain bersama teman.',
                          style: t.bodySmall.copyWith(
                            fontSize: 12,
                            color: t.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StickerButton.large(
                          text: 'BUAT ATAU GABUNG GRUP',
                          backgroundColor: t.success,
                          textColor: t.ink,
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
                badgeColor: isGroupMode ? t.success : t.surface,
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
                      backgroundColor: t.accentBlue,
                      gameType: GameType.dice,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: t.secondary,
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
                      backgroundColor: t.accentPink,
                      gameType: GameType.capsule,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: t.secondary,
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
                      backgroundColor: t.accentMint,
                      gameType: GameType.envelope,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: t.secondary,
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
                      backgroundColor: t.accentOrange,
                      gameType: GameType.coin,
                      badgeText: isGroupMode ? '🛠️ SEGERA HADIR' : null,
                      badgeColor: t.secondary,
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
                borderRadius: t.pillButtonRadius,
                backgroundColor: t.ink,
                textColor: t.bg,
                shadowColor: t.textDisabled,
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
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(
                        painter: ShuffleIconPainter(
                          color: t.secondary,
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
                          style: t.buttonLarge.copyWith(
                            color: t.bg,
                            fontSize: 16,
                            fontWeight: t.weightExtraBold,
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
                backgroundColor: t.surface,
                borderRadius: t.smallCardRadius,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomPaint(
                            painter: CustomSettingsIconPainter(
                              color: t.ink,
                              strokeWidth: 2.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kustomisasi Budget Game',
                            style: t.titleMedium.copyWith(
                              fontWeight: t.weightExtraBold,
                              color: t.ink,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mau atur uang di roda, kapsul, amplop, atau kelipatan dadu? Pilih game di bawah:',
                      style: t.bodySmall.copyWith(
                        color: t.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickEditChip('Atur Roda', t.secondary, () {
                          context.push('/custom-wheel?game=wheel');
                        }),
                        _buildQuickEditChip('Atur Kapsul', t.accentPink, () {
                          context.push('/custom-wheel?game=capsule');
                        }),
                        _buildQuickEditChip('Atur Amplop', t.accentMint, () {
                          context.push('/custom-wheel?game=envelope');
                        }),
                        _buildQuickEditChip('Atur Dadu', t.accentBlue, () {
                          context.push('/dice-game');
                        }),
                        _buildQuickEditChip('Atur Koin', t.accentOrange, () {
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
    final t = context.putarTheme;
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(t.chipRadius),
          border: Border.all(color: t.ink, width: 2),
          boxShadow: [
            BoxShadow(
              color: t.shadowColor,
              offset: t.miniShadowOffset,
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
                painter: CustomSettingsIconPainter(
                  color: t.ink,
                  strokeWidth: 2.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: t.chipLabel.copyWith(
                fontWeight: t.weightExtraBold,
                color: t.ink,
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
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    final t = context.putarTheme;
    return StickerCard.hero(
      backgroundColor: t.secondary,
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
                      style: t.titleLarge.copyWith(
                        fontSize: 24,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: t.bodySmall.copyWith(
                        fontSize: 13,
                        fontWeight: t.weightSemiBold,
                        color: t.ink,
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
                      painter: _MiniWheelPainter(t),
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
                color: badgeColor ?? t.surface,
                borderRadius: BorderRadius.circular(t.chipRadius),
                border: Border.all(color: t.ink, width: 2),
              ),
              child: Text(
                badgeText,
                style: t.chipLabel.copyWith(
                  fontSize: 11,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
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
    Color? badgeColor,
    bool isDimmed = false,
    VoidCallback? onTap,
  }) {
    final t = context.putarTheme;
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
                  style: t.titleMedium.copyWith(
                    fontSize: 18,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: t.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: t.weightSemiBold,
                    color: t.ink,
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
                    color: badgeColor ?? t.surface,
                    borderRadius: BorderRadius.circular(t.chipRadius),
                    border: Border.all(color: t.ink, width: 2),
                  ),
                  child: Text(
                    badgeText,
                    style: t.chipLabel.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: t.ink,
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
        final t = ctx.putarTheme;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.ink, width: t.borderWidth),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.ink, width: 2),
                    ),
                    child: Text(
                      '🛠️ MODE GRUP DALAM PENGEMBANGAN',
                      style: t.buttonSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: t.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.ink, width: 2),
                      ),
                      child: CustomPaint(
                        size: const Size(18, 18),
                        painter: CustomCloseIconPainter(
                          color: t.ink,
                          strokeWidth: 2.6,
                        ),
                      ),
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
                      color: t.accentBlue,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.ink, width: t.subtleBorderWidth),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: const Offset(2.5, 2.5),
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
                          style: t.titleLarge.copyWith(
                            fontSize: 20,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                        Text(
                          'Multiplayer Realtime',
                          style: t.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: t.weightSemiBold,
                            color: t.textSecondary,
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
                  color: t.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.ink, width: 1.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitur multiplayer realtime untuk $gameName sedang dalam tahap pengembangan & uji kestabilan sinkronisasi server.',
                      style: t.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight: t.weightSemiBold,
                        color: t.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Saat ini di mode grup kamu sudah bisa menikmati:',
                      style: t.bodySmall.copyWith(
                        fontSize: 12,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• 🎯 Putar Jajan (Roda) — Sinkron live 100% antar-anggota\n• 💰 Mode Angka Tetap — Budget pasti tanpa undian',
                      style: t.bodySmall.copyWith(
                        fontSize: 12,
                        color: t.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StickerButton.large(
                text: 'MAINKAN PUTAR RODA BERSAMA',
                backgroundColor: t.success,
                textColor: t.ink,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(appScopeProvider.notifier).state = AppScope.grup;
                  context.go('/roda');
                },
              ),
              const SizedBox(height: 8),
              StickerButton.large(
                text: 'MENGERTI',
                backgroundColor: t.surface,
                textColor: t.ink,
                borderColor: t.ink,
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
  final PutarTheme theme;

  const _MiniWheelPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.0;

    final borderPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final linePaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const sweepAngle = (2 * math.pi) / 8;

    for (int i = 0; i < 8; i++) {
      final startAngle = i * sweepAngle;
      final fillPaint = Paint()
        ..color = theme.getWheelColor(i)
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
    canvas.drawCircle(center, 12, Paint()..color = theme.surface);
    canvas.drawCircle(center, 12, borderPaint);
    canvas.drawCircle(center, 4, Paint()..color = theme.ink);
  }

  @override
  bool shouldRepaint(covariant _MiniWheelPainter oldDelegate) =>
      oldDelegate.theme.id != theme.id;
}
