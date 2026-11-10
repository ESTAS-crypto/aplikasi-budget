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
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/in_app_toast.dart';
import '../../../core/widgets/pop_reveal.dart';
import '../../../core/widgets/sticker_button.dart';

enum _CoinSide { gambar, angka }

class _FlipRecord {
  final _CoinSide side;
  final int beforeAmount;
  final int afterAmount;

  const _FlipRecord({
    required this.side,
    required this.beforeAmount,
    required this.afterAmount,
  });

  Map<String, dynamic> toJson() => {
        'side': side == _CoinSide.gambar ? 'gambar' : 'angka',
        'before': beforeAmount,
        'after': afterAmount,
      };
}

/// Layar 60: Lempar Koin Grup
/// Sesuai acuan visual GKoin.dc.html & spesifikasi UPDATE 2D
class GroupCoinScreen extends ConsumerStatefulWidget {
  const GroupCoinScreen({super.key});

  @override
  ConsumerState<GroupCoinScreen> createState() => _GroupCoinScreenState();
}

class _GroupCoinScreenState extends ConsumerState<GroupCoinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  bool _isFlipping = false;
  bool _hasStarted = false;
  bool _isFinished = false;
  bool _hasPlayedLandSound = false;

  int _currentAmount = 50000;
  int _flipCount = 0;
  final List<_FlipRecord> _history = [];

  _CoinSide _lastSide = _CoinSide.gambar;
  _CoinSide _animTargetSide = _CoinSide.gambar;

  // Track apakah giliran koin sedang dipegang oleh user saat ini
  bool _heldTurnLock = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _flipController.addListener(() {
      if (_isFlipping) {
        final t = _flipController.value;
        // Pada saat koin mendarat kembali di lantai (t ~ 0.62)
        if (t >= 0.62 && !_hasPlayedLandSound) {
          _hasPlayedLandSound = true;
          SoundService.instance.play(Sfx.coinLand);
          HapticFeedback.mediumImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    // Bila user memegang kunci giliran dan meninggalkan layar sebelum "Ambil", lepas kunci
    if (_heldTurnLock) {
      final activeGroupId = ref.read(activeGroupIdProvider);
      final myUid = ref.read(groupAuthServiceProvider).currentUid;
      if (activeGroupId != null && myUid != null) {
        ref.read(groupGameServiceProvider).releaseCoinTurn(
              gid: activeGroupId,
              uid: myUid,
            );
      }
    }
    super.dispose();
  }

  void _initBaseAmount(GroupModel group) {
    if (!_hasStarted && _flipCount == 0) {
      _currentAmount = group.coinBase > 0 ? group.coinBase : 50000;
    }
  }

  Future<void> _flip(GroupModel group, bool canPlay, bool isLocked, String myUid, String myName) async {
    if (_isFlipping || _isFinished || _flipCount >= 3) return;

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

    // Kunci giliran koin di dokumen sesi jika belum dikunci oleh kita
    final gameService = ref.read(groupGameServiceProvider);
    if (!_heldTurnLock) {
      final locked = await gameService.claimCoinTurn(
        gid: group.id,
        uid: myUid,
        userName: myName,
      );
      if (!locked) {
        final session = group.activeSession;
        final lockOwner = session?.turnLockedByName ?? 'anggota lain';
        SoundService.instance.play(Sfx.notifWarning);
        if (mounted) {
          InAppToast.show(context, message: 'Giliran sedang dimainkan $lockOwner');
        }
        return;
      }
      _heldTurnLock = true;
    }

    _hasPlayedLandSound = false;
    SoundService.instance.play(Sfx.coinFlip);

    final before = _currentAmount;
    final isGambar = math.Random().nextBool();
    final targetSide = isGambar ? _CoinSide.gambar : _CoinSide.angka;
    final after = isGambar ? before * 2 : math.max(1000, (before / 2).round());

    setState(() {
      _isFlipping = true;
      _hasStarted = true;
      _animTargetSide = targetSide;
    });

    await _flipController.forward(from: 0.0);

    if (!mounted) return;

    // Mainkan efek audio hasil lemparan (Gambar x2 atau Angka setengah)
    if (targetSide == _CoinSide.gambar) {
      SoundService.instance.play(Sfx.coinDouble);
    } else {
      SoundService.instance.play(Sfx.coinHalve);
    }

    final record = _FlipRecord(
      side: targetSide,
      beforeAmount: before,
      afterAmount: after,
    );

    setState(() {
      _isFlipping = false;
      _lastSide = targetSide;
      _currentAmount = after;
      _flipCount++;
      _history.add(record);

      if (_flipCount >= 3) {
        _isFinished = true;
        SoundService.instance.play(Sfx.winLolos, volume: 0.85);
      }
    });

    SemanticsService.sendAnnouncement(
      View.of(context),
      '${targetSide == _CoinSide.gambar ? "Gambar" : "Angka"}! Budget sekarang ${RupiahFormatter.format(after)}',
      TextDirection.ltr,
    );
  }

  Future<void> _takeBudget(GroupModel group, String myUid) async {
    if (_isFlipping) return;

    SoundService.instance.play(Sfx.winLolos);
    HapticFeedback.heavyImpact();

    setState(() {
      _isFinished = true;
    });

    final gameService = ref.read(groupGameServiceProvider);

    // Tulis hasil permainan & klaim sesi grup
    final claimResult = await gameService.claimSessionAndWriteResult(
      gid: group.id,
      game: 'coin',
      amount: _currentAmount,
      detail: {
        'coin_base': group.coinBase > 0 ? group.coinBase : 50000,
        'flips': _history.map((h) => h.toJson()).toList(),
        'flip_count': _flipCount,
        'amount': _currentAmount,
      },
    );

    // Lepas kunci giliran
    if (_heldTurnLock) {
      await gameService.releaseCoinTurn(gid: group.id, uid: myUid);
      _heldTurnLock = false;
    }

    if (!mounted) return;

    if (!claimResult.success) {
      InAppToast.show(context, message: claimResult.message);
    } else {
      InAppToast.show(
        context,
        message: 'Budget grup ditentukan: ${RupiahFormatter.format(_currentAmount)}!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final membersAsync = ref.watch(activeGroupMembersStreamProvider);

    final group = activeGroupAsync.valueOrNull ??
        (activeGroupId != null && activeGroupId.isNotEmpty
            ? ref.read(groupServiceProvider).getLocalGroup(activeGroupId)
            : null);

    if (group == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Grup tidak ditemukan',
                    style: AppTypography.displayMedium.copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    _initBaseAmount(group);

    final members = membersAsync.valueOrNull ?? [];
    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid ?? '';
    final myName = authService.displayName ?? 'Anggota';

    final canPlay = group.canUserPlay(myUid);
    final isLocked = group.isSessionLocked;
    final session = group.activeSession;

    // Cek apakah giliran sedang dikunci anggota lain
    final isTurnLockedByOther = session != null &&
        session.isTurnLocked &&
        !session.isTurnLockedBy(myUid);

    // Sinkronisasi bila spectator melihat sesi coin aktif yang sudah diambil
    final isSpectatorResult = session != null &&
        session.game == 'coin' &&
        !_isFlipping &&
        !_hasStarted;

    final currentBudget = session?.budget ?? (_hasStarted ? _currentAmount : 0);
    final isCoinClaimed = (session != null && session.budget > 0);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Bar: Tombol Kembali & Judul Layar
              Row(
                children: [
                  _buildBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Lempar Koin',
                      style: AppTypography.displayMedium.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Pill Subtitle: "Gambar x2 · Angka setengah"
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.matahari,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Gambar x2 · Angka setengah',
                    style: AppTypography.buttonSmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Group Status Strip
              _buildGroupStatusStrip(group: group, members: members, canPlay: canPlay),
              const SizedBox(height: 18),

              // 4. Arena Lempar Koin 300px
              _buildCoinArena(),
              const SizedBox(height: 16),

              // 5. Indikator Lemparan (1 dari 3)
              _buildFlipIndicators(),
              const SizedBox(height: 14),

              // 6. Kartu Hasil Pop Reveal
              _buildResultCard(
                session: session,
                isSpectatorResult: isSpectatorResult,
              ),
              const SizedBox(height: 24),

              // 7. Bar Budget Grup untuk Date Ini
              _buildBudgetStatusBar(budget: currentBudget, isLocked: isLocked),
              const SizedBox(height: 12),

              // 8. Tombol Aksi (LEMPAR KOIN / LEMPAR LAGI & AMBIL)
              _buildActionButtons(
                group: group,
                canPlay: canPlay,
                isLocked: isLocked,
                isTurnLockedByOther: isTurnLockedByOther,
                isCoinClaimed: isCoinClaimed,
                myUid: myUid,
                myName: myName,
                session: session,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
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
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(
            painter: CustomBackIconPainter(
              color: AppColors.ink,
              strokeWidth: 3.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupStatusStrip({
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 3),
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
                  style: AppTypography.buttonSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                Text(
                  '$onlineCount online · $turnPolicyLabel · hasil dilihat semua',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinArena() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9A8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Bayangan Koin di Lantai
          Positioned(
            bottom: 30,
            child: AnimatedBuilder(
              animation: _flipController,
              builder: (context, _) {
                final t = _flipController.value;
                double scale = 1.0;
                double opacity = 0.28;

                if (_isFlipping) {
                  if (t < 0.40) {
                    final p = t / 0.40;
                    scale = 1.0 - (0.5 * math.sin(p * math.pi));
                    opacity = 0.28 - (0.16 * math.sin(p * math.pi));
                  } else if (t < 0.62) {
                    final p = (t - 0.40) / 0.22;
                    scale = 0.5 + (0.5 * p);
                    opacity = 0.12 + (0.16 * p);
                  }
                }

                return Transform.scale(
                  scaleX: scale,
                  scaleY: scale * 0.8,
                  child: Container(
                    width: 130,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                );
              },
            ),
          ),

          // Koin 3D dengan Rotasi Sumbu Y
          Positioned(
            bottom: 45,
            child: AnimatedBuilder(
              animation: _flipController,
              builder: (context, _) {
                final t = _flipController.value;

                double translateY = 0.0;
                double rotY = 0.0;
                double scale = 1.0;

                if (_isFlipping) {
                  final targetTurns = (_animTargetSide == _CoinSide.gambar) ? 5.0 : 5.5;

                  if (t < 0.40) {
                    final p = t / 0.40;
                    final easeP = Curves.easeOutCubic.transform(p);
                    translateY = -130.0 * easeP;
                    scale = 1.0 + (0.12 * easeP);
                    rotY = (targetTurns * 2 * math.pi) * (p * 0.5);
                  } else if (t < 0.62) {
                    final p = (t - 0.40) / 0.22;
                    final easeP = Curves.easeInQuad.transform(p);
                    translateY = -130.0 * (1.0 - easeP);
                    scale = 1.12 - (0.12 * easeP);
                    rotY = (targetTurns * 2 * math.pi) * (0.5 + 0.5 * p);
                  } else if (t < 0.66) {
                    final p = (t - 0.62) / 0.04;
                    translateY = -22.0 * math.sin(p * math.pi);
                    rotY = targetTurns * 2 * math.pi;
                  } else {
                    translateY = 0.0;
                    rotY = targetTurns * 2 * math.pi;
                  }
                } else {
                  rotY = (_lastSide == _CoinSide.gambar) ? 0.0 : math.pi;
                }

                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0015) // perspective 700
                  ..multiply(Matrix4.translationValues(0.0, translateY, 0.0))
                  ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0))
                  ..rotateY(rotY);

                final isShowingFront = (math.cos(rotY) >= 0);

                return Transform(
                  transform: transform,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: isShowingFront
                        ? const _CoinFaceGambar()
                        : const _CoinFaceAngka(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Lemparan ${_flipCount.clamp(0, 3)} dari 3',
          style: AppTypography.buttonSmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 10),
        for (int i = 1; i <= 3; i++)
          Container(
            margin: const EdgeInsets.only(left: 6),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= _flipCount ? AppColors.mint : Colors.white,
              border: Border.all(color: AppColors.ink, width: 3),
            ),
          ),
      ],
    );
  }

  Widget _buildResultCard({
    required GroupSessionModel? session,
    required bool isSpectatorResult,
  }) {
    if (_isFlipping) {
      return const SizedBox(height: 68);
    }

    if (isSpectatorResult && session != null) {
      return PopReveal(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
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
              children: [
                Text(
                  'Hasil Lempar Koin grup',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  RupiahFormatter.format(session.budget),
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasStarted || _history.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
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
            children: [
              Text(
                'Nominal dasar',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                RupiahFormatter.format(_currentAmount),
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final last = _history.last;
    final sideText = last.side == _CoinSide.gambar ? 'Gambar! ' : 'Angka! ';

    return PopReveal(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
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
            children: [
              Text(
                '$sideText${RupiahFormatter.format(last.beforeAmount)} jadi',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                RupiahFormatter.format(_currentAmount),
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetStatusBar({required int budget, required bool isLocked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget grup untuk date ini',
              style: AppTypography.buttonSmall.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Text(
              RupiahFormatter.format(budget),
              style: AppTypography.buttonSmall.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.ink, width: 3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: budget > 0 ? 1.0 : 0.0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.mint,
                border: Border(
                  right: BorderSide(color: AppColors.ink, width: 3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Permainan lain terkunci sampai date selesai.',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmEndSession(GroupModel group) async {
    final confirm = await GroupImportantDialog.showConfirmEndGroupSession(
      context,
      groupName: group.name,
      budget: group.activeSession?.budget,
    );
    if (confirm == true) {
      await ref.read(groupGameServiceProvider).endSession(gid: group.id);
      if (mounted) {
        InAppToast.show(context, message: 'Date grup telah diakhiri. Permainan kini terbuka!');
      }
    }
  }

  Widget _buildActionButtons({
    required GroupModel group,
    required bool canPlay,
    required bool isLocked,
    required bool isTurnLockedByOther,
    required bool isCoinClaimed,
    required String myUid,
    required String myName,
    required GroupSessionModel? session,
  }) {
    // 1. Kebijakan siapa boleh bermain
    if (!canPlay) {
      return StickerButton.large(
        text: 'Hanya pemilik yang bisa memainkan',
        backgroundColor: AppColors.surface,
        textColor: AppColors.textSecondary,
        borderColor: AppColors.ink,
        onPressed: null,
      );
    }

    // 2. Kunci sesi jika date sudah berjalan dan lockPolicy == 'lock'
    if (isLocked && group.lockPolicy == 'lock') {
      final isOwner = group.isOwner(myUid);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StickerButton.large(
            text: 'Date berjalan · permainan terkunci',
            backgroundColor: AppColors.surface,
            textColor: AppColors.textSecondary,
            borderColor: AppColors.ink,
            onPressed: isOwner ? () => _confirmEndSession(group) : null,
          ),
          if (isOwner) ...[
            const SizedBox(height: 10),
            StickerButton.large(
              text: 'AKHIRI DATE GRUP',
              backgroundColor: AppColors.matahari,
              textColor: AppColors.ink,
              borderColor: AppColors.ink,
              onPressed: () => _confirmEndSession(group),
            ),
          ],
        ],
      );
    }

    // 3. Kunci giliran oleh anggota lain
    if (isTurnLockedByOther) {
      final locker = session?.turnLockedByName ?? 'anggota lain';
      return StickerButton.large(
        text: 'Giliran dimainkan $locker',
        backgroundColor: AppColors.surface,
        textColor: AppColors.textSecondary,
        borderColor: AppColors.ink,
        onPressed: null,
      );
    }

    // 4. Koin sudah diambil dan selesai
    if (isCoinClaimed && !_hasStarted) {
      return StickerButton.large(
        text: 'KOIN SUDAH DIAMBIL',
        backgroundColor: AppColors.surface,
        textColor: AppColors.textSecondary,
        borderColor: AppColors.ink,
        onPressed: null,
      );
    }

    // 5. Belum mulai lemparan pertama
    if (!_hasStarted) {
      return StickerButton.large(
        text: 'LEMPAR KOIN',
        backgroundColor: AppColors.tomat,
        textColor: AppColors.ink,
        borderColor: AppColors.ink,
        onPressed: _isFlipping ? null : () => _flip(group, canPlay, isLocked, myUid, myName),
      );
    }

    // 6. Sedang berlangsung (setelah lemparan 1 atau 2, belum 3)
    if (!_isFinished && _flipCount < 3) {
      return Row(
        children: [
          Expanded(
            child: StickerButton(
              height: 58,
              borderRadius: 29,
              backgroundColor: _isFlipping ? AppColors.surface : AppColors.tomat,
              textColor: AppColors.ink,
              borderColor: AppColors.ink,
              text: 'LEMPAR LAGI',
              onPressed: _isFlipping ? null : () => _flip(group, canPlay, isLocked, myUid, myName),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StickerButton(
              height: 58,
              borderRadius: 29,
              backgroundColor: _isFlipping ? AppColors.surface : AppColors.mint,
              textColor: AppColors.ink,
              borderColor: AppColors.ink,
              text: 'AMBIL',
              onPressed: _isFlipping ? null : () => _takeBudget(group, myUid),
            ),
          ),
        ],
      );
    }

    // 7. Sudah 3 lemparan atau selesai -> Tombol AMBIL BUDGET
    return StickerButton.large(
      text: 'AMBIL BUDGET (${RupiahFormatter.format(_currentAmount)})',
      backgroundColor: AppColors.mint,
      textColor: AppColors.ink,
      borderColor: AppColors.ink,
      onPressed: _isFlipping ? null : () => _takeBudget(group, myUid),
    );
  }
}

/// Sisi Gambar Koin (#FFD23F) dengan logo vektor Putar Jajan
class _CoinFaceGambar extends StatelessWidget {
  const _CoinFaceGambar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.matahari,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 4.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: CustomPaint(
                painter: _CoinLogoPainter(),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'GAMBAR',
              style: AppTypography.chipLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sisi Angka Koin (#FF9F1C Jeruk) dengan simbol '½' besar
class _CoinFaceAngka extends StatelessWidget {
  const _CoinFaceAngka();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.jeruk,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 4.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '½',
              style: AppTypography.displayLarge.copyWith(
                fontSize: 58,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                height: 1.0,
              ),
            ),
            Text(
              'ANGKA',
              style: AppTypography.chipLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter untuk Logo Roda Koin
class _CoinLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;

    final coralPaint = Paint()
      ..color = AppColors.tomat
      ..style = PaintingStyle.fill;

    final mintPaint = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    // Sektor Coral
    final pathCoral = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 1.5,
        false,
      )
      ..close();
    canvas.drawPath(pathCoral, coralPaint);
    canvas.drawPath(pathCoral, strokePaint);

    // Sektor Mint
    final pathMint = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * 0.5,
        false,
      )
      ..close();
    canvas.drawPath(pathMint, mintPaint);
    canvas.drawPath(pathMint, strokePaint);

    // Titik Mata Hitam & Hub Putih
    final eyePos = Offset(center.dx + radius * 0.45, center.dy - radius * 0.45);
    canvas.drawCircle(eyePos, 4, Paint()..color = AppColors.ink);

    canvas.drawCircle(center, 7, whitePaint);
    canvas.drawCircle(center, 7, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
