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

class _CapsulePos {
  final double left;
  final double top;
  final int colorIndex;
  final double delay;

  const _CapsulePos({
    required this.left,
    required this.top,
    required this.colorIndex,
    required this.delay,
  });
}

/// Posisi dan indeks warna hingga 12 kapsul di dalam kubah sesuai GKapsul.dc.html
const List<_CapsulePos> _kGroupDomeCapsuleSlots = [
  _CapsulePos(left: 28, top: 130, colorIndex: 0, delay: 0.0),
  _CapsulePos(left: 70, top: 140, colorIndex: 1, delay: 0.1),
  _CapsulePos(left: 114, top: 126, colorIndex: 2, delay: 0.2),
  _CapsulePos(left: 150, top: 138, colorIndex: 3, delay: 0.3),
  _CapsulePos(left: 46, top: 92, colorIndex: 4, delay: 0.4),
  _CapsulePos(left: 92, top: 98, colorIndex: 5, delay: 0.0),
  _CapsulePos(left: 136, top: 88, colorIndex: 6, delay: 0.1),
  _CapsulePos(left: 64, top: 52, colorIndex: 7, delay: 0.2),
  _CapsulePos(left: 110, top: 56, colorIndex: 0, delay: 0.3),
  _CapsulePos(left: 36, top: 160, colorIndex: 3, delay: 0.15),
  _CapsulePos(left: 130, top: 160, colorIndex: 1, delay: 0.25),
  _CapsulePos(left: 85, top: 40, colorIndex: 4, delay: 0.35),
];

/// Layar 58: Gacha Kapsul Grup
/// Sesuai acuan visual GKapsul.dc.html & spesifikasi UPDATE 2D
class GroupCapsuleScreen extends ConsumerStatefulWidget {
  const GroupCapsuleScreen({super.key});

  @override
  ConsumerState<GroupCapsuleScreen> createState() => _GroupCapsuleScreenState();
}

class _GroupCapsuleScreenState extends ConsumerState<GroupCapsuleScreen>
    with TickerProviderStateMixin {
  late AnimationController _crankController;
  late Animation<double> _crankCurve;
  late AnimationController _dropController;
  late AnimationController _jiggleController;

  bool _isCranking = false;
  bool _hasPlayedDropSound = false;
  bool _hasPlayedOpenSound = false;
  int? _wonAmount;
  int _wonColorIndex = 5;

  @override
  void initState() {
    super.initState();
    _crankController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _crankCurve = CurvedAnimation(
      parent: _crankController,
      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
    );

    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _dropController.addListener(() {
      if (_isCranking) {
        final t = _dropController.value;
        if (t >= 0.54 && !_hasPlayedDropSound) {
          _hasPlayedDropSound = true;
          SoundService.instance.play(Sfx.capsuleDrop);
          HapticFeedback.mediumImpact();
        }
        if (t >= 0.76 && !_hasPlayedOpenSound) {
          _hasPlayedOpenSound = true;
          SoundService.instance.play(Sfx.capsuleOpen);
          HapticFeedback.heavyImpact();
        }
      }
    });

    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _jiggleController.repeat();
  }

  @override
  void dispose() {
    _crankController.dispose();
    _dropController.dispose();
    _jiggleController.dispose();
    super.dispose();
  }

  Offset _calcJiggle(double t, double delay) {
    final progress = (t + delay) % 1.0;
    if (progress < 0.25) {
      final u = (1 - math.cos(progress / 0.25 * math.pi)) / 2;
      return Offset(5.0 * u, -8.0 * u);
    } else if (progress < 0.50) {
      final u = (1 - math.cos((progress - 0.25) / 0.25 * math.pi)) / 2;
      return Offset(5.0 + (-5.0 - 5.0) * u, -8.0 + (4.0 - (-8.0)) * u);
    } else if (progress < 0.75) {
      final u = (1 - math.cos((progress - 0.50) / 0.25 * math.pi)) / 2;
      return Offset(-5.0 + (4.0 - (-5.0)) * u, 4.0 + (6.0 - 4.0) * u);
    } else {
      final u = (1 - math.cos((progress - 0.75) / 0.25 * math.pi)) / 2;
      return Offset(4.0 * (1 - u), 6.0 * (1 - u));
    }
  }

  Future<void> _turnCrank(GroupModel group, bool canPlay, bool isLocked) async {
    if (_isCranking) return;

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

    final pool = group.getCapsulePool();
    if (pool.isEmpty) return;

    _hasPlayedDropSound = false;
    _hasPlayedOpenSound = false;

    SoundService.instance.play(Sfx.capsuleCrank);

    final random = math.Random.secure();
    final chosenIndex = random.nextInt(pool.length);
    final won = pool[chosenIndex];

    setState(() {
      _isCranking = true;
      _wonColorIndex = chosenIndex;
      _wonAmount = null;
    });

    _crankController.forward(from: 0.0);
    await _dropController.forward(from: 0.0);

    if (!mounted) return;

    SoundService.instance.play(Sfx.winLolos, volume: 0.85);

    setState(() {
      _isCranking = false;
      _wonAmount = won;
    });

    SemanticsService.sendAnnouncement(
      View.of(context),
      'Isi kapsul ${RupiahFormatter.format(won)}',
      TextDirection.ltr,
    );

    // Jika catatan grup sebelumnya masih ada (budget > 0), tanyakan persetujuan terlebih dahulu.
    // Jika catatan grup kosong, langsung pasang hasil kapsul ke catatan grup.
    final groupService = ref.read(groupServiceProvider);
    final existingSession = groupService.getEffectiveActiveSession(group.id, group);
    if (existingSession != null && existingSession.budget > 0) {
      final accepted = await GroupImportantDialog.showConfirmAcceptGameBudget(
        context,
        budget: won,
        currentBudget: existingSession.budget,
        gameName: 'Mesin Kapsul',
      );
      if (!mounted) return;
      if (accepted != true) {
        InAppToast.show(
          context,
          message:
              'Hasil kapsul dibatalkan. Catatan grup tetap ${RupiahFormatter.format(existingSession.budget)}.',
        );
        return;
      }
    }

    // Klaim sesi grup & tulis event game_result
    final gameService = ref.read(groupGameServiceProvider);
    final claimResult = await gameService.claimSessionAndWriteResult(
      gid: group.id,
      game: 'capsule',
      amount: won,
      detail: {
        'capsule_index': chosenIndex,
        'amount': won,
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
    final capsulePool = group.getCapsulePool();

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
                      'Gacha Kapsul',
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

              // 2. Pill Subtitle: "Isi kapsul rahasia, nominal acak"
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.secondary,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: t.ink, width: t.borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: t.shadowColor,
                        offset: t.smallShadowOffset,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Isi kapsul rahasia, nominal acak',
                    style: t.buttonSmall.copyWith(
                      fontSize: 13,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Group Status Strip
              _buildGroupStatusStrip(t: t, group: group, members: members, canPlay: canPlay),
              const SizedBox(height: 22),

              // 4. Mesin Gacha Kapsul (Kubah 230x230 & Base Mesin 250x128)
              _buildCapsuleMachine(theme: t, capsuleCount: capsulePool.length),
              const SizedBox(height: 20),

              // 5. Kartu Hasil Pop Reveal
              _buildResultCard(t: t, session: session),
              const SizedBox(height: 24),

              // 6. Bar Budget Grup untuk Date Ini
              _buildBudgetStatusBar(t: t, budget: currentBudget, isLocked: isLocked),
              const SizedBox(height: 12),

              // 7. Tombol Aksi PUTAR TUAS (bg Permen / #FF8FC0)
              _buildActionButton(t: t, group: group, canPlay: canPlay, isLocked: isLocked),
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
          border: Border.all(color: t.ink, width: t.borderWidth),
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
              strokeWidth: 3.0,
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
        borderRadius: BorderRadius.circular(t.smallCardRadius),
        border: Border.all(color: t.ink, width: t.borderWidth),
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

  Widget _buildCapsuleMachine({required PutarTheme theme, required int capsuleCount}) {
    // Batasi jumlah kapsul di kubah maksimum 12 sesuai spek UPDATE 2D
    final visibleCount = capsuleCount.clamp(2, 12);

    return Column(
      children: [
        // Kubah Transparan Lingkaran 230x230
        Container(
          width: 230,
          height: 230,
          decoration: BoxDecoration(
            color: theme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.ink, width: 4),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                offset: theme.dialogShadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _jiggleController,
                builder: (context, _) {
                  final t = _jiggleController.value;
                  return Stack(
                    children: List.generate(visibleCount, (i) {
                      final pos = _kGroupDomeCapsuleSlots[i % _kGroupDomeCapsuleSlots.length];
                      final offset = _calcJiggle(t, pos.delay);
                      return Positioned(
                        left: pos.left + offset.dx,
                        top: pos.top + offset.dy,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: theme.getWheelColor(pos.colorIndex),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.ink, width: theme.borderWidth),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),

        // Base Mesin Merah 250x128
        Transform.translate(
          offset: const Offset(0, -18),
          child: Container(
            width: 250,
            height: 128,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: theme.ink, width: 4),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor,
                  offset: theme.dialogShadowOffset,
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tuas Putar (Knob)
                AnimatedBuilder(
                  animation: _crankCurve,
                  builder: (context, child) {
                    final rot = _crankCurve.value * 540.0;
                    return Transform.rotate(
                      angle: rot * math.pi / 180,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: theme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.ink, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 46,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.ink,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),

                // Lubang Dispenser & Kapsul Jatuh
                Container(
                  width: 84,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.ink,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  child: AnimatedBuilder(
                    animation: _dropController,
                    builder: (context, child) {
                      final t = _dropController.value;
                      if (!_isCranking && _wonAmount == null) {
                        return const SizedBox.shrink();
                      }

                      double translateY = 0.0;
                      double opacity = 1.0;
                      double scale = 1.0;

                      if (t < 0.36) {
                        translateY = -70.0;
                        opacity = 0.0;
                      } else if (t < 0.40) {
                        final p = (t - 0.36) / 0.04;
                        translateY = -70.0 * (1 - p);
                        opacity = p;
                      } else if (t < 0.54) {
                        final p = (t - 0.40) / 0.14;
                        translateY = 10.0 * p;
                      } else if (t < 0.58) {
                        final p = (t - 0.54) / 0.04;
                        translateY = 10.0 - 18.0 * p;
                      } else if (t < 0.62) {
                        final p = (t - 0.58) / 0.04;
                        translateY = -8.0 + 8.0 * p;
                      } else if (t < 0.76) {
                        translateY = 0.0;
                        scale = 1.0;
                        opacity = 1.0;
                      } else {
                        final p = (t - 0.76) / 0.24;
                        scale = 1.0 + 0.8 * p;
                        opacity = (1.0 - p).clamp(0.0, 1.0);
                      }

                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, translateY),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.getWheelColor(_wonColorIndex),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.surface, width: theme.borderWidth),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({required PutarTheme t, required GroupSessionModel? session}) {
    if (_isCranking) {
      return const SizedBox(height: 72);
    }

    final displayedAmount = _wonAmount ?? session?.budget;

    if (displayedAmount == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
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
            children: [
              Text(
                'Putar tuas untuk buka kapsul',
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
            children: [
              Text(
                'Isi kapsul',
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
            border: Border.all(color: t.ink, width: t.borderWidth),
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
                    color: budget > 0 ? t.ink : Colors.transparent,
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

    if (_isCranking) {
      label = 'MEMUTAR TUAS...';
      isEnabled = false;
    } else if (isLocked) {
      label = 'Date berjalan · permainan terkunci';
      isEnabled = false;
    } else if (!canPlay) {
      label = 'Hanya pemilik yang bisa memainkan';
      isEnabled = false;
    } else {
      label = 'PUTAR TUAS';
      isEnabled = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerButton.large(
          text: label,
          backgroundColor: isEnabled ? t.accentPink : t.surface,
          textColor: t.ink,
          borderColor: t.ink,
          onPressed: isEnabled
              ? () => _turnCrank(group, canPlay, isLocked)
              : (isLocked && isOwner ? () => _confirmEndSession(group) : null),
        ),
        if (isLocked && isOwner) ...[
          const SizedBox(height: 10),
          StickerButton.large(
            text: 'AKHIRI DATE GRUP',
            backgroundColor: t.secondary,
            textColor: t.ink,
            borderColor: t.ink,
            onPressed: () => _confirmEndSession(group),
          ),
        ],
      ],
    );
  }
}
