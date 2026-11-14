import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/models/group_event_model.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_game_service.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/painters/game_icons_painter.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/in_app_toast.dart';

/// Layar 55 & 56: Home Grup - Pilih Permainan
/// Sesuai acuan visual GGames.dc.html (Layar 55) & GGames2.dc.html (Layar 56)
class GroupGamesHubView extends ConsumerStatefulWidget {
  const GroupGamesHubView({super.key});

  @override
  ConsumerState<GroupGamesHubView> createState() => _GroupGamesHubViewState();
}

class _GroupGamesHubViewState extends ConsumerState<GroupGamesHubView>
    with SingleTickerProviderStateMixin {
  late AnimationController _wheelRotationController;

  @override
  void initState() {
    super.initState();
    // Animasi putaran roda 12 detik linear infinite sesuai GGames.dc.html line 2
    _wheelRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _wheelRotationController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hr lalu';
  }

  Color _getMemberColor(PutarTheme t, int index) {
    final palette = t.gamesHubCardColors;
    return palette[index.abs() % palette.length];
  }

  void _navigateToGroupGame(String gameKey) {
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();

    switch (gameKey.toLowerCase().trim()) {
      case 'wheel':
        context.go('/roda');
        break;
      case 'dice':
        context.push('/group/dice');
        break;
      case 'capsule':
        context.push('/group/capsule');
        break;
      case 'envelope':
        context.push('/group/envelope');
        break;
      case 'coin':
        context.push('/group/coin');
        break;
      default:
        context.go('/roda');
    }
  }

  void _pickRandomGroupGame(GroupModel group) {
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();

    final enabled = group.enabledGames;
    if (enabled.isEmpty) {
      InAppToast.show(context, message: 'Semua permainan dimatikan pemilik');
      return;
    }

    final randomKey = enabled[math.Random.secure().nextInt(enabled.length)];
    _navigateToGroupGame(randomKey);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final group = activeGroupAsync.valueOrNull ??
        (activeGroupId != null && activeGroupId.isNotEmpty
            ? ref.read(groupServiceProvider).getLocalGroup(activeGroupId)
            : null);

    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final members = membersAsync.valueOrNull ?? [];
    final unreadCount = ref.watch(unreadActivityCountProvider);

    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid ?? '';

    // Bila belum ada grup aktif
    if (group == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(t: t, unreadCount: unreadCount, group: null),
                const SizedBox(height: 14),
                _buildScopeSwitcher(t: t, groupName: 'Grup'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.borderColor, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(color: t.shadowColor, offset: t.standardShadowOffset, blurRadius: 0),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Belum Ada Grup Aktif',
                        style: t.displayMedium.copyWith(fontSize: 20, color: t.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buat grup baru atau gabung dengan kode undangan untuk bermain bersama teman.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall.copyWith(color: t.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      StickerButton.large(
                        text: 'BUAT ATAU GABUNG GRUP',
                        backgroundColor: t.secondary,
                        textColor: t.ink,
                        onPressed: () {
                          context.push('/group/join-or-create');
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
    }

    final isSessionLocked = group.isSessionLocked;
    final activeSession = group.activeSession;
    final canPlay = group.canUserPlay(myUid);
    final isFixedMode = group.budgetMode == 'fixed';

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (GGames.dc.html line 6)
              _buildHeader(t: t, unreadCount: unreadCount, group: group),
              const SizedBox(height: 12),

              // 2. ScopeSwitcher (GGames.dc.html line 7)
              _buildScopeSwitcher(t: t, groupName: group.name),
              const SizedBox(height: 12),

              // 3. Hero Feature: Roda Putar (GGames.dc.html line 7 & GGames2.dc.html line 7)
              _buildHeroWheelCard(
                t: t,
                group: group,
                isLocked: isSessionLocked,
                isEnabled: group.isGameEnabled('wheel'),
                canPlay: canPlay,
                myUid: myUid,
              ),
              const SizedBox(height: 14),

              // 4. Grid 2x2: Dadu, Kapsul, Amplop, Koin (GGames.dc.html line 8)
              _buildGamesGrid(
                t: t,
                group: group,
                isLocked: isSessionLocked,
                canPlay: canPlay,
                myUid: myUid,
              ),
              const SizedBox(height: 14),

              // 5. Status Info Card (GGames.dc.html line 9 vs GGames2.dc.html line 9)
              _buildStatusCard(
                t: t,
                group: group,
                isLocked: isSessionLocked,
                activeSession: activeSession,
                members: members,
                isFixedMode: isFixedMode,
                myUid: myUid,
              ),
              const SizedBox(height: 18),

              // 6. Action Button (GGames.dc.html line 9 vs GGames2.dc.html line 9)
              _buildBottomActionButton(
                t: t,
                group: group,
                isLocked: isSessionLocked,
                canPlay: canPlay,
                isFixedMode: isFixedMode,
                myUid: myUid,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header Widget ---
  Widget _buildHeader({
    required PutarTheme t,
    required int unreadCount,
    required GroupModel? group,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Malam ini mau main apa?',
                style: t.bodyMedium.copyWith(
                  fontWeight: t.weightBold,
                  color: t.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pilih permainan',
                style: t.displayMedium.copyWith(
                  fontSize: 30,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Aktivitas / Lonceng
            Semantics(
              label: unreadCount > 0
                  ? 'Aktivitas grup, $unreadCount baru'
                  : 'Aktivitas grup',
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
                        shape: BoxShape.circle,
                        color: t.surface,
                        border: Border.all(color: t.borderColor, width: t.borderWidth),
                        boxShadow: [
                          BoxShadow(color: t.shadowColor, offset: t.smallShadowOffset, blurRadius: 0),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: CustomPaint(
                        size: const Size(21, 21),
                        painter: CustomBellPainter(
                          color: t.ink,
                          strokeWidth: 2.8,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 19),
                          height: 19,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: t.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.borderColor, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: t.buttonSmall.copyWith(
                              fontSize: 11,
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

            // Tombol Pengaturan
            Semantics(
              label: 'Pengaturan grup',
              button: true,
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.uiTap);
                  if (group != null) {
                    context.push('/group/budget-settings/${group.id}');
                  } else {
                    context.push('/settings');
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surface,
                    border: Border.all(color: t.borderColor, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(color: t.shadowColor, offset: t.smallShadowOffset, blurRadius: 0),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(21, 21),
                    painter: CustomSettingsIconPainter(
                      color: t.ink,
                      strokeWidth: 2.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Scope Switcher ---
  Widget _buildScopeSwitcher({required PutarTheme t, required String groupName}) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.borderColor, width: t.borderWidth),
        boxShadow: [
          BoxShadow(color: t.shadowColor, offset: t.smallShadowOffset, blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                SoundService.instance.play(Sfx.uiTap);
                ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.transparent, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Pribadi',
                  style: t.buttonSmall.copyWith(
                    fontSize: 14,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: t.secondary,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: t.borderColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                'Grup · $groupName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.buttonSmall.copyWith(
                  fontSize: 14,
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

  // --- Hero Card: Roda Putar ---
  Widget _buildHeroWheelCard({
    required PutarTheme t,
    required GroupModel group,
    required bool isLocked,
    required bool isEnabled,
    required bool canPlay,
    required String myUid,
  }) {
    final isOwner = group.isOwner(myUid);
    final playPerm = evaluateCanPlay(group: group, session: group.activeSession, uid: myUid);
    final isDimmed = !isEnabled || (!isOwner && isLocked);

    return Opacity(
      opacity: isDimmed ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: () {
          if (!isEnabled) {
            InAppToast.show(context, message: 'Roda Putar dimatikan oleh pemilik grup');
            return;
          }
          if (isOwner) {
            // Aturan F1: Pemilik SELALU boleh memutar atau mengulang
            _navigateToGroupGame('wheel');
            return;
          }
          if (!playPerm.allowed) {
            InAppToast.show(context, message: playPerm.message);
            return;
          }
          _navigateToGroupGame('wheel');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: t.secondary,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
            boxShadow: [
              BoxShadow(color: t.shadowColor, offset: t.heroShadowOffset, blurRadius: 0),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roda Putar',
                          style: t.displayMedium.copyWith(
                            fontSize: 24,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Klasik. Putar roda, terima nasib.',
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
                  // Animated Mini Wheel Neo-Brutalist (96x96) dengan jarum penunjuk
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        RotationTransition(
                          turns: _wheelRotationController,
                          child: CustomPaint(
                            size: const Size(96, 96),
                            painter: _HubMiniWheelPainter(t),
                          ),
                        ),
                        // Jarum Penunjuk Atas Neo-Brutalist
                        Positioned(
                          top: -6,
                          child: CustomPaint(
                            size: const Size(16, 14),
                            painter: _HubWheelPointerPainter(t),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: t.borderColor, width: 2),
                  ),
                  child: Text(
                    !isEnabled ? 'Dimatikan pemilik' : 'Favorit',
                    style: t.buttonSmall.copyWith(
                      fontSize: 11,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Grid Permainan 2x2 ---
  Widget _buildGamesGrid({
    required PutarTheme t,
    required GroupModel group,
    required bool isLocked,
    required bool canPlay,
    required String myUid,
  }) {
    final diceEnabled = group.isGameEnabled('dice');
    final capsuleEnabled = group.isGameEnabled('capsule');
    final envelopeEnabled = group.isGameEnabled('envelope');
    final coinEnabled = group.isGameEnabled('coin');
    final isOwner = group.isOwner(myUid);
    final playPerm = evaluateCanPlay(group: group, session: group.activeSession, uid: myUid);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                t: t,
                title: 'Kocok Dadu',
                subtitle: 'Dua dadu, hasilnya dikali nominal.',
                backgroundColor: t.accentBlue,
                isEnabled: diceEnabled,
                isLocked: isLocked,
                canPlay: canPlay,
                isOwner: isOwner,
                playPerm: playPerm,
                iconPainter: DiceIconPainter(
                  diceColor: t.surface,
                  dotColor: t.ink,
                  strokeColor: t.ink,
                ),
                onTap: () => _navigateToGroupGame('dice'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildGridItem(
                t: t,
                title: 'Gacha Kapsul',
                subtitle: 'Putar tuas, kapsul jatuh.',
                backgroundColor: t.accentPink,
                isEnabled: capsuleEnabled,
                isLocked: isLocked,
                canPlay: canPlay,
                isOwner: isOwner,
                playPerm: playPerm,
                iconPainter: CapsuleIconPainter(
                  topColor: t.accentCoral,
                  bottomColor: t.surface,
                  strokeColor: t.ink,
                ),
                onTap: () => _navigateToGroupGame('capsule'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildGridItem(
                t: t,
                title: 'Pilih Amplop',
                subtitle: 'Tiga amplop, satu pilihan.',
                backgroundColor: t.accentMint,
                isEnabled: envelopeEnabled,
                isLocked: isLocked,
                canPlay: canPlay,
                isOwner: isOwner,
                playPerm: playPerm,
                iconPainter: EnvelopeIconPainter(
                  envelopeColor: t.surface,
                  coinColor: t.accentYellow,
                  strokeColor: t.ink,
                ),
                onTap: () => _navigateToGroupGame('envelope'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildGridItem(
                t: t,
                title: 'Lempar Koin',
                subtitle: 'Gandakan atau setengah.',
                backgroundColor: t.accentOrange,
                isEnabled: coinEnabled,
                isLocked: isLocked,
                canPlay: canPlay,
                isOwner: isOwner,
                playPerm: playPerm,
                iconPainter: CoinIconPainter(
                  coinColor: t.accentYellow,
                  strokeColor: t.ink,
                ),
                onTap: () => _navigateToGroupGame('coin'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem({
    required PutarTheme t,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required bool isEnabled,
    required bool isLocked,
    required bool canPlay,
    required bool isOwner,
    required PlayPermissionResult playPerm,
    required CustomPainter iconPainter,
    required VoidCallback onTap,
  }) {
    final isDimmed = !isEnabled || (!isOwner && isLocked);

    return Opacity(
      opacity: isDimmed ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: () {
          if (!isEnabled) {
            InAppToast.show(context, message: '$title dimatikan oleh pemilik grup');
            return;
          }
          if (isOwner) {
            // Pemilik selalu boleh bermain / mengulang
            onTap();
            return;
          }
          if (!playPerm.allowed) {
            InAppToast.show(context, message: playPerm.message);
            return;
          }
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
            boxShadow: [
              BoxShadow(color: t.shadowColor, offset: t.standardShadowOffset, blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 64,
                child: CustomPaint(
                  size: const Size(64, 64),
                  painter: iconPainter,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: t.displayMedium.copyWith(
                  fontSize: 19,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                !isEnabled ? 'Dimatikan pemilik' : subtitle,
                style: t.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: t.weightSemiBold,
                  color: !isEnabled ? t.danger : t.ink,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Status Info Card ---
  Widget _buildStatusCard({
    required PutarTheme t,
    required GroupModel group,
    required bool isLocked,
    required GroupSessionModel? activeSession,
    required List<GroupMemberModel> members,
    required bool isFixedMode,
    required String myUid,
  }) {
    // 1. Fixed Budget Mode
    if (isFixedMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.borderColor, width: t.borderWidth),
          boxShadow: [
            BoxShadow(color: t.shadowColor, offset: t.smallShadowOffset, blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.secondary,
                border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
              ),
              alignment: Alignment.center,
              child: Text(
                'Rp',
                style: t.buttonSmall.copyWith(
                  fontWeight: t.weightExtraBold,
                  fontSize: 14,
                  color: t.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget tetap ${RupiahFormatter.format(group.fixedBudget)}',
                    style: t.bodyMedium.copyWith(
                      fontWeight: t.weightExtraBold,
                      fontSize: 13,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    'Mode angka tetap aktif · Mainkan di tab Pribadi bila ingin solo',
                    style: t.bodySmall.copyWith(
                      fontSize: 11,
                      fontWeight: t.weightSemiBold,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Layar 56: Sesi Terkunci / Date Berjalan
    if (isLocked && activeSession != null) {
      final actorInitial = activeSession.startedByName.isNotEmpty
          ? activeSession.startedByName[0].toUpperCase()
          : 'A';
      final gameName = GroupEventModel.formatGameName(activeSession.game);
      final timeStr = _formatTimeAgo(activeSession.startedAt);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.borderColor, width: t.borderWidth),
          boxShadow: [
            BoxShadow(color: t.shadowColor, offset: t.smallShadowOffset, blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.info,
                border: Border.all(color: t.borderColor, width: t.borderWidth),
              ),
              alignment: Alignment.center,
              child: Text(
                actorInitial,
                style: t.buttonSmall.copyWith(
                  fontWeight: t.weightExtraBold,
                  fontSize: 15,
                  color: t.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: t.bodyMedium.copyWith(
                        fontSize: 13,
                        color: t.ink,
                        height: 1.25,
                      ),
                      children: [
                        TextSpan(
                          text: activeSession.startedByName,
                          style: TextStyle(fontWeight: t.weightExtraBold),
                        ),
                        TextSpan(text: ' memainkan $gameName'),
                      ],
                    ),
                  ),
                  Text(
                    'Budget date ini ${RupiahFormatter.format(activeSession.budget)} · $timeStr',
                    style: t.bodySmall.copyWith(
                      fontSize: 11,
                      fontWeight: t.weightSemiBold,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                if (group.isOwner(myUid)) {
                  _showEndSessionPrompt(group);
                } else {
                  InAppToast.show(context, message: 'Date berjalan · permainan terkunci');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: t.secondary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: t.borderColor, width: 2),
                ),
                child: Text(
                  'Terkunci',
                  style: t.buttonSmall.copyWith(
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

    // 3. Layar 55: Belum Ada Budget
    final displayMembers = members.take(4).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.borderColor, width: t.borderWidth, strokeAlign: BorderSide.strokeAlignCenter),
      ),
      child: Row(
        children: [
          // Overlapping Avatars
          if (displayMembers.isNotEmpty)
            SizedBox(
              width: 28.0 + (displayMembers.length - 1) * 20.0,
              height: 28,
              child: Stack(
                children: [
                  for (int i = 0; i < displayMembers.length; i++)
                    Positioned(
                      left: i * 20.0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getMemberColor(t, displayMembers[i].colorIndex),
                          border: Border.all(color: t.borderColor, width: t.borderWidth),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          displayMembers[i].name.isNotEmpty
                              ? displayMembers[i].name[0].toUpperCase()
                              : 'A',
                          style: t.buttonSmall.copyWith(
                            fontSize: 13,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.secondary,
                border: Border.all(color: t.borderColor, width: t.borderWidth),
              ),
              alignment: Alignment.center,
              child: Text(
                'G',
                style: t.buttonSmall.copyWith(
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date ini belum punya budget',
                  style: t.bodyMedium.copyWith(
                    fontWeight: t.weightBold,
                    fontSize: 12.5,
                    color: t.ink,
                    height: 1.25,
                  ),
                ),
                Text(
                  'Mainkan satu permainan. Hasilnya jadi budget grup.',
                  style: t.bodySmall.copyWith(
                    fontWeight: t.weightSemiBold,
                    fontSize: 11,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEndSessionPrompt(GroupModel group) async {
    final groupService = ref.read(groupServiceProvider);
    final summary = groupService.getActiveSessionSummary(group.id);
    final confirm = await GroupImportantDialog.showConfirmEndGroupSession(
      context,
      groupName: group.name,
      budget: summary.budget > 0 ? summary.budget : group.activeSession?.budget,
      totalSpent: summary.totalSpent,
      itemCount: summary.itemCount,
    );
    if (confirm == true) {
      await ref.read(groupGameServiceProvider).endSession(gid: group.id);
      if (mounted) {
        InAppToast.show(context, message: 'Date grup telah diakhiri. Permainan kini terbuka!');
      }
    }
  }

  // --- Bottom Action Button ---
  Widget _buildBottomActionButton({
    required PutarTheme t,
    required GroupModel group,
    required bool isLocked,
    required bool canPlay,
    required bool isFixedMode,
    required String myUid,
  }) {
    // Mode Fixed Budget: MULAI DATE
    if (isFixedMode) {
      if (isLocked) {
        final isOwner = group.isOwner(myUid);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPillActionButton(
              t: t,
              label: 'Date berjalan · permainan terkunci',
              isDimmed: true,
              onTap: () {
                if (isOwner) {
                  _showEndSessionPrompt(group);
                } else {
                  InAppToast.show(context, message: 'Date sedang berjalan');
                }
              },
            ),
            if (isOwner) ...[
              const SizedBox(height: 10),
              StickerButton.large(
                text: 'AKHIRI DATE GRUP',
                backgroundColor: t.secondary,
                textColor: t.ink,
                borderColor: t.borderColor,
                onPressed: () => _showEndSessionPrompt(group),
              ),
            ],
          ],
        );
      }
      if (!canPlay) {
        return _buildPillActionButton(
          t: t,
          label: 'Hanya pemilik yang bisa memainkan',
          isDimmed: true,
          onTap: () {
            InAppToast.show(context, message: 'Hanya pemilik grup yang bisa memulai date');
          },
        );
      }
      return _buildPillActionButton(
        t: t,
        label: 'MULAI DATE',
        isDimmed: false,
        onTap: () async {
          SoundService.instance.play(Sfx.uiTap);
          final res = await ref.read(groupGameServiceProvider).startFixedBudgetSession(
                gid: group.id,
                fixedBudget: group.fixedBudget,
              );
          if (res.success && mounted) {
            InAppToast.show(context, message: res.message);
          }
        },
      );
    }

    // Layar 56: Sesi Terkunci
    if (isLocked) {
      final isOwner = group.isOwner(myUid);
      final playPerm = evaluateCanPlay(group: group, session: group.activeSession, uid: myUid);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOwner) ...[
            _buildPillActionButton(
              t: t,
              label: 'ULANGI BUDGET',
              isDimmed: false,
              showIcon: true,
              onTap: () async {
                final session = group.activeSession;
                final startedByName = session?.startedByName ?? 'anggota';
                final currentBudget = session?.budget ?? 0;
                final confirm = await GroupImportantDialog.showConfirmRerunBudget(
                  context,
                  startedByName: startedByName,
                  budget: currentBudget,
                );
                if (confirm == true) {
                  _navigateToGroupGame('wheel');
                }
              },
            ),
            const SizedBox(height: 10),
            StickerButton.large(
              text: 'AKHIRI DATE GRUP',
              backgroundColor: t.secondary,
              textColor: t.ink,
              borderColor: t.borderColor,
              onPressed: () => _showEndSessionPrompt(group),
            ),
          ] else ...[
            _buildPillActionButton(
              t: t,
              label: 'Date berjalan · permainan terkunci',
              isDimmed: true,
              showIcon: true,
              onTap: () {
                InAppToast.show(context, message: playPerm.message);
              },
            ),
          ],
        ],
      );
    }

    // Layar 55: Belum Ada Budget
    final playPerm = evaluateCanPlay(group: group, session: group.activeSession, uid: myUid);
    if (!playPerm.allowed) {
      return _buildPillActionButton(
        t: t,
        label: 'Hanya pemilik yang bisa memutar',
        isDimmed: true,
        showIcon: false,
        onTap: () {
          InAppToast.show(context, message: playPerm.message);
        },
      );
    }

    return _buildPillActionButton(
      t: t,
      label: 'Acak aja, serahkan ke aplikasi',
      isDimmed: false,
      showIcon: true,
      onTap: () => _pickRandomGroupGame(group),
    );
  }

  Widget _buildPillActionButton({
    required PutarTheme t,
    required String label,
    required bool isDimmed,
    bool showIcon = false,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: t.ink,
            borderRadius: BorderRadius.circular(t.pillButtonRadius),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
            boxShadow: [
              BoxShadow(
                color: t.textDisabled,
                offset: t.standardShadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showIcon) ...[
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
                const SizedBox(width: 10),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: t.buttonLarge.copyWith(
                      color: t.bg,
                      fontSize: 18,
                      fontWeight: t.weightExtraBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Painter Mini Roda Neo-Brutalist untuk Kartu Hero Games Hub (UPDATE F1)
/// 8 irisan warna solid dengan garis pembatas hitam 2.2px, border tebal 3.5px,
/// center hub putih, dan pin tengah hitam.
class _HubMiniWheelPainter extends CustomPainter {
  final PutarTheme theme;

  const _HubMiniWheelPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.5;

    final borderPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final linePaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

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

    // Outer circle border
    canvas.drawCircle(center, radius, borderPaint);

    // Center hub outer
    canvas.drawCircle(center, 14, Paint()..color = theme.surface);
    canvas.drawCircle(center, 14, borderPaint);

    // Center pin
    canvas.drawCircle(center, 5, Paint()..color = theme.ink);
  }

  @override
  bool shouldRepaint(covariant _HubMiniWheelPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

/// Pointer segitiga neo-brutalist penunjuk roda
class _HubWheelPointerPainter extends CustomPainter {
  final PutarTheme theme;

  const _HubWheelPointerPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = theme.primary
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = theme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HubWheelPointerPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
