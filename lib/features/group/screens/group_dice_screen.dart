import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_game_service.dart';
import '../../../core/group/widgets/member_avatar.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/in_app_toast.dart';
import '../../../core/widgets/pop_reveal.dart';
import '../../../core/widgets/sticker_button.dart';

/// Layar 57: Kocok Dadu Grup
/// Sesuai acuan visual GDadu.dc.html & spesifikasi UPDATE 2D
class GroupDiceScreen extends ConsumerStatefulWidget {
  const GroupDiceScreen({super.key});

  @override
  ConsumerState<GroupDiceScreen> createState() => _GroupDiceScreenState();
}

class _GroupDiceScreenState extends ConsumerState<GroupDiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rollController;

  int _diceCount = 2;
  int _selectedMultiplier = 10000;
  List<int> _currentValues = [3, 5];
  bool _isRolling = false;
  int? _wonAmount;

  final List<int> _presetMultipliers = [5000, 10000, 20000];
  bool _hasPlayedLandSound = false;
  bool _hasPlayedBounceSound = false;

  @override
  void initState() {
    super.initState();
    _rollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _rollController.addListener(() {
      if (_isRolling) {
        final t = _rollController.value;
        if (t >= 0.30 && !_hasPlayedLandSound) {
          _hasPlayedLandSound = true;
          SoundService.instance.play(Sfx.diceLand);
        }
        if (t >= 0.43 && !_hasPlayedBounceSound) {
          _hasPlayedBounceSound = true;
          SoundService.instance.play(Sfx.diceLand, volume: 0.75, pitch: 1.1);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGroupConfig();
    });
  }

  void _initGroupConfig() {
    final activeGroupId = ref.read(groupServiceProvider).getActiveGroupId();
    if (activeGroupId == null) return;
    final group = ref.read(groupServiceProvider).getLocalGroup(activeGroupId);
    if (group != null) {
      final count = (group.diceConfig['count'] as num?)?.toInt() ?? 2;
      final mult = (group.diceConfig['multiplier'] as num?)?.toInt() ?? 10000;
      setState(() {
        _diceCount = count.clamp(1, 3);
        _selectedMultiplier = mult;
        _currentValues = List.filled(_diceCount, 4);
      });
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _handleRoll(GroupModel group, bool canPlay, bool isLocked) async {
    if (_isRolling) return;

    if (!canPlay) {
      SoundService.instance.play(Sfx.notifWarning);
      HapticFeedback.lightImpact();
      InAppToast.show(context, message: 'Hanya pemilik yang bisa memainkan');
      return;
    }

    if (isLocked) {
      SoundService.instance.play(Sfx.notifWarning);
      HapticFeedback.lightImpact();
      InAppToast.show(context, message: 'Date berjalan · permainan terkunci');
      return;
    }

    _hasPlayedLandSound = false;
    _hasPlayedBounceSound = false;
    SoundService.instance.play(Sfx.diceRoll);

    final random = math.Random.secure();
    final rolls = List.generate(_diceCount, (_) => 1 + random.nextInt(6));
    final sum = rolls.fold(0, (a, b) => a + b);
    final won = sum * _selectedMultiplier;

    setState(() {
      _isRolling = true;
      _wonAmount = null;
    });

    await _rollController.forward(from: 0.0);

    if (!mounted) return;

    SoundService.instance.play(Sfx.winLolos, volume: 0.85);
    HapticFeedback.heavyImpact();

    setState(() {
      _isRolling = false;
      _currentValues = rolls;
      _wonAmount = won;
    });

    SemanticsService.sendAnnouncement(
      View.of(context),
      'Budget date ${RupiahFormatter.format(won)}',
      TextDirection.ltr,
    );

    // Jika catatan grup sebelumnya masih ada (budget > 0), tanyakan persetujuan terlebih dahulu.
    // Jika catatan grup kosong, langsung pasang hasil dadu ke catatan grup.
    final groupService = ref.read(groupServiceProvider);
    final existingSession = groupService.getEffectiveActiveSession(group.id, group);
    if (existingSession != null && existingSession.budget > 0) {
      final accepted = await GroupImportantDialog.showConfirmAcceptGameBudget(
        context,
        budget: won,
        currentBudget: existingSession.budget,
        gameName: 'Lempar Dadu',
      );
      if (!mounted) return;
      if (accepted != true) {
        InAppToast.show(
          context,
          message:
              'Hasil dadu dibatalkan. Catatan grup tetap ${RupiahFormatter.format(existingSession.budget)}.',
        );
        return;
      }
    }

    // Klaim sesi dan tulis event dalam satu transaksi atomik
    final gameService = ref.read(groupGameServiceProvider);
    final claimResult = await gameService.claimSessionAndWriteResult(
      gid: group.id,
      game: 'dice',
      amount: won,
      detail: {
        'rolls': rolls,
        'sum': sum,
        'multiplier': _selectedMultiplier,
      },
    );

    if (!mounted) return;

    if (!claimResult.success) {
      InAppToast.show(
        context,
        message: claimResult.message,
      );
    } else {
      InAppToast.show(
        context,
        message: 'Budget grup ditentukan: ${RupiahFormatter.format(won)}!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final groupService = ref.read(groupServiceProvider);

    final streamedGroup = activeGroupAsync.valueOrNull;
    final localGroup = (activeGroupId != null && activeGroupId.isNotEmpty)
        ? groupService.getLocalGroup(activeGroupId)
        : null;
    final rawGroup = streamedGroup ?? localGroup;
    final resolvedSession = rawGroup != null
        ? groupService.resolveEffectiveSession(
            rawGroup.id,
            streamedGroup?.activeSession,
            localGroup?.activeSession,
          )
        : null;
    final group = rawGroup?.copyWith(
      activeSession: resolvedSession,
      clearActiveSession: resolvedSession == null,
    );

    if (group == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(t),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Grup tidak ditemukan',
                    style: t.displayMedium.copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final members = membersAsync.valueOrNull ?? [];
    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid;

    final canPlay = group.canUserPlay(myUid ?? '');
    final isLocked = group.isSessionLocked;
    final session = group.activeSession;

    // Sinkronkan multiplier dan count dari grup jika belum rolling
    final configCount = (group.diceConfig['count'] as num?)?.toInt() ?? 2;
    if (!_isRolling && _diceCount != configCount) {
      _diceCount = configCount.clamp(1, 3);
      if (_currentValues.length != _diceCount) {
        _currentValues = List.filled(_diceCount, 4);
      }
    }

    // Kelipatan preset gabungan
    final effectivePresets = Set<int>.from(_presetMultipliers)
      ..add((group.diceConfig['multiplier'] as num?)?.toInt() ?? 10000);
    final sortedPresets = effectivePresets.toList()..sort();

    final currentBudget = session?.budget ?? _wonAmount ?? 0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Bar: Tombol Kembali & Judul Layar
              Row(
                children: [
                  _buildBackButton(t),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Kocok Dadu',
                      style: t.displayMedium.copyWith(
                        fontSize: 24,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Pill Subtitle: "{N} dadu × nominal pilihanmu"
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.secondary,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: t.borderColor, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: t.shadowColor,
                        offset: t.smallShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    '$_diceCount dadu × nominal pilihanmu',
                    style: t.buttonSmall.copyWith(
                      fontSize: 13,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Group Status Strip (Layar 57: Avatar, Nama Grup, "3 online · giliran semua · hasil dilihat semua")
              _buildGroupStatusStrip(t: t, group: group, members: members, canPlay: canPlay),
              const SizedBox(height: 24),

              // 4. Dice Arena (Height 230, Bg #FFE9A8, Dadu 1-3)
              _buildDiceArena(t),
              const SizedBox(height: 22),

              // 5. Kartu Hasil Pop Reveal
              _buildResultCard(t: t, session: session),
              const SizedBox(height: 20),

              // 6. Pilihan Kelipatan (Chips)
              _buildMultiplierSection(
                t: t,
                presets: sortedPresets,
                canPlay: canPlay,
                isLocked: isLocked,
              ),
              const SizedBox(height: 26),

              // 7. Budget Grup Bar untuk Date Ini
              _buildBudgetStatusBar(t: t, budget: currentBudget, isLocked: isLocked),
              const SizedBox(height: 12),

              // 8. Tombol Aksi KOCOK DADU
              _buildActionButton(
                t: t,
                group: group,
                canPlay: canPlay,
                isLocked: isLocked,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(PutarTheme t) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: t.surface,
          shape: BoxShape.circle,
          border: Border.all(color: t.borderColor, width: t.borderWidth),
          boxShadow: [
            BoxShadow(
              color: t.shadowColor,
              offset: t.smallShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(
            painter: CustomBackIconPainter(
              color: t.ink,
              strokeWidth: t.borderWidth,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupStatusStrip({
    required PutarTheme t,
    required GroupModel group,
    required List<GroupMemberModel> members,
    required bool canPlay,
  }) {
    final now = DateTime.now();
    final onlineCount = members.where((m) {
      return m.lastSeenAt == null || now.difference(m.lastSeenAt!).inMinutes < 15;
    }).length.clamp(1, 99);

    final turnPolicyLabel = group.playPolicy == 'owner' ? 'giliran pemilik' : 'giliran semua';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.borderColor, width: t.borderWidth),
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
          // Overlapping Avatars
          if (members.isNotEmpty)
            SizedBox(
              height: 28,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < members.length.clamp(0, 3); i++)
                    Align(
                      widthFactor: 0.72,
                      child: MemberAvatar(
                        name: members[i].name,
                        colorIndex: members[i].colorIndex,
                        size: 28,
                      ),
                    ),
                ],
              ),
            )
          else
            const MemberAvatar(name: 'Grup', colorIndex: 0, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Grup · ${group.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.buttonSmall.copyWith(
                    fontSize: 13,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                    height: 1.2,
                  ),
                ),
                Text(
                  '$onlineCount online · $turnPolicyLabel · hasil dilihat semua',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildDiceArena(PutarTheme t) {
    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.accentWarmSoft,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.borderColor, width: t.borderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.standardShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bayangan di bawah dadu
          Positioned(
            bottom: 24,
            child: AnimatedBuilder(
              animation: _rollController,
              builder: (context, _) {
                final v = _rollController.value;
                final scale = _isRolling
                    ? (0.4 + 0.6 * math.sin(v * math.pi).abs())
                    : 1.0;
                return Transform.scale(
                  scaleX: scale,
                  scaleY: 0.8,
                  child: Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.ink.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ),
          // Deretan Dadu
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_diceCount, (index) {
                  final dieBg = index == 0
                      ? t.surface
                      : index == 1
                          ? t.accentBlue
                          : t.accentPink; // Pink untuk dadu ke-3
                  final dieSize = _diceCount == 1
                      ? 116.0
                      : _diceCount == 2
                          ? 104.0
                          : 88.0;
                  final hPadding = _diceCount == 3 ? 6.0 : 10.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
                    child: _AnimatedDie(
                      value: _currentValues[index.clamp(0, _currentValues.length - 1)],
                      isRolling: _isRolling,
                      controller: _rollController,
                      delayFraction: index * (120.0 / 950.0),
                      backgroundColor: dieBg,
                      size: dieSize,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required PutarTheme t,
    required GroupSessionModel? session,
  }) {
    if (_isRolling) {
      return const SizedBox(height: 72);
    }

    final sum = _currentValues.fold(0, (a, b) => a + b);
    final displayedAmount = _wonAmount ?? session?.budget;

    if (displayedAmount == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
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
            children: [
              Text(
                'Kocok dadu untuk menentukan budget grup',
                style: t.bodySmall.copyWith(
                  fontWeight: t.weightBold,
                  color: t.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Rp0',
                style: t.displayMedium.copyWith(
                  fontSize: 26,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopReveal(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
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
            children: [
              Text(
                'Total $sum × ${RupiahFormatter.format(_selectedMultiplier)} = budget kamu',
                style: t.bodySmall.copyWith(
                  fontWeight: t.weightBold,
                  color: t.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                RupiahFormatter.format(displayedAmount),
                style: t.displayLarge.copyWith(
                  fontSize: 30,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplierSection({
    required PutarTheme t,
    required List<int> presets,
    required bool canPlay,
    required bool isLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kelipatan',
          style: t.titleMedium.copyWith(
            fontWeight: t.weightExtraBold,
            color: t.ink,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: presets.map((m) {
              final isSelected = _selectedMultiplier == m;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    if (_isRolling || isLocked || !canPlay) return;
                    SoundService.instance.play(Sfx.uiTap);
                    setState(() {
                      _selectedMultiplier = m;
                      _wonAmount = null;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? t.secondary : t.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: t.borderColor, width: t.borderWidth),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: t.shadowColor,
                                offset: t.smallShadowOffset,
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      RupiahFormatter.format(m),
                      style: t.buttonSmall.copyWith(
                        fontSize: 14,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetStatusBar({
    required PutarTheme t,
    required int budget,
    required bool isLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget grup untuk date ini',
              style: t.buttonSmall.copyWith(
                fontSize: 12.5,
                fontWeight: t.weightExtraBold,
                color: t.ink,
              ),
            ),
            Text(
              RupiahFormatter.format(budget),
              style: t.buttonSmall.copyWith(
                fontSize: 12.5,
                fontWeight: t.weightExtraBold,
                color: t.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: t.borderColor, width: t.borderWidth),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: budget > 0 ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                color: t.success,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  right: BorderSide(
                    color: budget > 0 ? t.borderColor : Colors.transparent,
                    width: t.borderWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Permainan lain terkunci sampai date selesai.',
          style: t.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: t.weightSemiBold,
            color: t.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmEndSession(GroupModel group) async {
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
        setState(() {
          _wonAmount = null;
        });
        InAppToast.show(context, message: 'Date grup telah diakhiri. Permainan kini terbuka!');
      }
    }
  }

  Widget _buildActionButton({
    required PutarTheme t,
    required GroupModel group,
    required bool canPlay,
    required bool isLocked,
  }) {
    final myUid = ref.watch(groupAuthServiceProvider).currentUid ?? '';
    final isOwner = group.isOwner(myUid);
    final String label;
    final bool isEnabled;

    if (_isRolling) {
      label = 'MENGUMPULKAN HASIL...';
      isEnabled = false;
    } else if (isLocked) {
      label = 'Date berjalan · permainan terkunci';
      isEnabled = false;
    } else if (!canPlay) {
      label = 'Hanya pemilik yang bisa memainkan';
      isEnabled = false;
    } else {
      label = 'KOCOK DADU';
      isEnabled = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerButton.large(
          text: label,
          backgroundColor: isEnabled ? t.primary : t.surface,
          textColor: t.ink,
          borderColor: t.borderColor,
          onPressed: isEnabled
              ? () => _handleRoll(group, canPlay, isLocked)
              : (isLocked && isOwner ? () => _confirmEndSession(group) : null),
        ),
        if (isLocked && isOwner) ...[
          const SizedBox(height: 10),
          StickerButton.large(
            text: 'AKHIRI DATE GRUP',
            backgroundColor: t.secondary,
            textColor: t.ink,
            borderColor: t.borderColor,
            onPressed: () => _confirmEndSession(group),
          ),
        ],
      ],
    );
  }
}

/// Satu Dadu dengan Animasi Fisika Sesuai GDadu.dc.html (@keyframes rl)
class _AnimatedDie extends StatelessWidget {
  final int value;
  final bool isRolling;
  final AnimationController controller;
  final double delayFraction;
  final Color backgroundColor;
  final double size;

  const _AnimatedDie({
    required this.value,
    required this.isRolling,
    required this.controller,
    required this.delayFraction,
    required this.backgroundColor,
    this.size = 104.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.putarTheme;
    if (!isRolling) {
      return _buildDieBody(theme, value);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final rawT = (controller.value - delayFraction) / (1.0 - delayFraction);
        final t = rawT.clamp(0.0, 1.0);

        double translateY = 0.0;
        double rotation = 0.0;
        double opacity = 1.0;

        if (t < 0.30) {
          final p = t / 0.30;
          final easeP = Curves.easeInQuad.transform(p);
          translateY = -170.0 * (1.0 - easeP);
          rotation = -420.0 * (1.0 - p);
          opacity = (p * 5.0).clamp(0.0, 1.0);
        } else if (t < 0.38) {
          final p = (t - 0.30) / 0.08;
          translateY = -46.0 * math.sin(p * math.pi);
          rotation = 0.0 + 110.0 * p;
        } else if (t < 0.46) {
          final p = (t - 0.38) / 0.08;
          translateY = -46.0 * (1.0 - p);
          rotation = 110.0 + 90.0 * p;
        } else if (t < 0.52) {
          final p = (t - 0.46) / 0.06;
          translateY = -14.0 * math.sin(p * math.pi);
          rotation = 200.0 + 130.0 * p;
        } else if (t < 0.60) {
          final p = (t - 0.52) / 0.08;
          translateY = 0.0;
          rotation = 330.0 + 30.0 * p;
        } else {
          translateY = 0.0;
          rotation = 360.0;
        }

        final displayVal = t < 0.58
            ? (((t * 26).toInt() + (delayFraction * 10).toInt()) % 6) + 1
            : value;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.rotate(
              angle: rotation * math.pi / 180,
              child: _buildDieBody(theme, displayVal),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDieBody(PutarTheme theme, int val) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: theme.borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            offset: theme.dialogShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.13),
      child: CustomPaint(
        painter: _DieDotsPainter(val, dotColor: theme.ink),
      ),
    );
  }
}

class _DieDotsPainter extends CustomPainter {
  final int value;
  final Color dotColor;

  const _DieDotsPainter(this.value, {required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.11;

    final left = size.width * 0.22;
    final center = size.width * 0.5;
    final right = size.width * 0.78;

    final top = size.height * 0.22;
    final middle = size.height * 0.5;
    final bottom = size.height * 0.78;

    void draw(double x, double y) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }

    switch (value) {
      case 1:
        draw(center, middle);
        break;
      case 2:
        draw(left, top);
        draw(right, bottom);
        break;
      case 3:
        draw(left, top);
        draw(center, middle);
        draw(right, bottom);
        break;
      case 4:
        draw(left, top);
        draw(right, top);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 5:
        draw(left, top);
        draw(right, top);
        draw(center, middle);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 6:
        draw(left, top);
        draw(right, top);
        draw(left, middle);
        draw(right, middle);
        draw(left, bottom);
        draw(right, bottom);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DieDotsPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.dotColor != dotColor;
}
