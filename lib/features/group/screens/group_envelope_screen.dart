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

/// Layar 59: Pilih Amplop Grup
/// Sesuai acuan visual GAmplop.dc.html & spesifikasi UPDATE 2D
class GroupEnvelopeScreen extends ConsumerStatefulWidget {
  const GroupEnvelopeScreen({super.key});

  @override
  ConsumerState<GroupEnvelopeScreen> createState() => _GroupEnvelopeScreenState();
}

class _GroupEnvelopeScreenState extends ConsumerState<GroupEnvelopeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _openController;

  int _selectedIndex = 1; // Default amplop tengah (indeks 1) sesuai GAmplop.dc.html
  bool _isOpening = false;
  bool _hasOpened = false;
  bool _hasPlayedOpenSound = false;
  int? _wonAmount;

  // 3 warna amplop sesuai GAmplop.dc.html:
  // [0] #3DDBB0 (mint), [1] #FF8FC0 (permen), [2] #6FB1FF (langit)
  static const List<Color> _envelopeColors = [
    AppColors.mint,
    AppColors.permen,
    AppColors.langit,
  ];

  // 3 nominal terundi untuk masing-masing amplop
  List<int> _envelopeAmounts = [];

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _openController.addListener(() {
      if (_isOpening) {
        final t = _openController.value;
        // Pada saat flap mulai membuka (t ~ 0.40)
        if (t >= 0.40 && !_hasPlayedOpenSound) {
          _hasPlayedOpenSound = true;
          SoundService.instance.play(Sfx.envelopeOpen);
          HapticFeedback.heavyImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _openController.dispose();
    super.dispose();
  }

  void _initAmountsIfEmpty(GroupModel group) {
    if (_envelopeAmounts.length == 3) return;

    final pool = group.getEnvelopePool();
    if (pool.isEmpty) {
      _envelopeAmounts = [20000, 40000, 50000];
      return;
    }

    final shuffled = List<int>.from(pool)..shuffle(math.Random());
    if (shuffled.length >= 3) {
      _envelopeAmounts = shuffled.take(3).toList();
    } else {
      // Duplikasi jika kurang dari 3
      _envelopeAmounts = [
        shuffled[0],
        shuffled.length > 1 ? shuffled[1] : shuffled[0],
        shuffled.length > 2 ? shuffled[2] : (shuffled.length > 1 ? shuffled[1] : shuffled[0]),
      ];
    }
  }

  void _selectEnvelopeIndex(int index) {
    if (_isOpening || _hasOpened) return;

    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();

    setState(() {
      _selectedIndex = index.clamp(0, 2);
    });
  }

  Future<void> _openEnvelope(GroupModel group, bool canPlay, bool isLocked) async {
    if (_isOpening || _hasOpened) return;

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

    _initAmountsIfEmpty(group);
    final won = _envelopeAmounts[_selectedIndex];

    _hasPlayedOpenSound = false;
    SoundService.instance.play(Sfx.envelopeShuffle);

    setState(() {
      _isOpening = true;
      _wonAmount = null;
    });

    await _openController.forward(from: 0.0);

    if (!mounted) return;

    SoundService.instance.play(Sfx.winLolos, volume: 0.85);

    setState(() {
      _isOpening = false;
      _hasOpened = true;
      _wonAmount = won;
    });

    SemanticsService.sendAnnouncement(
      View.of(context),
      'Isi amplop ${RupiahFormatter.format(won)}',
      TextDirection.ltr,
    );

    // Tulis hasil permainan & klaim sesi grup
    final gameService = ref.read(groupGameServiceProvider);
    final claimResult = await gameService.claimSessionAndWriteResult(
      gid: group.id,
      game: 'envelope',
      amount: won,
      detail: {
        'chosen_index': _selectedIndex,
        'candidate_amounts': _envelopeAmounts,
        'amount': won,
      },
    );

    if (!mounted) return;

    if (!claimResult.success) {
      InAppToast.show(context, message: claimResult.message);
    } else {
      InAppToast.show(
        context,
        message: 'Budget grup ditentukan: ${RupiahFormatter.format(won)}!',
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

    _initAmountsIfEmpty(group);

    final members = membersAsync.valueOrNull ?? [];
    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid;

    final canPlay = group.canUserPlay(myUid ?? '');
    final isLocked = group.isSessionLocked;
    final session = group.activeSession;

    // Sinkronisasi data sesi aktif bila sudah dimainkan oleh anggota lain
    final isSpectatorResult = session != null &&
        session.game == 'envelope' &&
        !_isOpening &&
        !_hasOpened;

    if (isSpectatorResult) {
      final won = session.budget;
      _wonAmount = won;
      final foundIdx = _envelopeAmounts.indexOf(won);
      if (foundIdx != -1) {
        _selectedIndex = foundIdx;
      }
    }

    final currentBudget = session?.budget ?? _wonAmount ?? 0;
    final showOpenedState = _hasOpened || (session != null && session.budget > 0);

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
                      'Pilih Amplop',
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

              // 2. Pill Subtitle: "Satu amplop, isinya rahasia"
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
                    'Satu amplop, isinya rahasia',
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
              const SizedBox(height: 36),

              // 4. Barisan 3 Amplop (Mint, Permen, Langit)
              _buildEnvelopesShowcase(showOpenedState: showOpenedState),
              const SizedBox(height: 22),

              // Keterangan pilihan amplop
              Center(
                child: Text(
                  _selectedIndex == 0
                      ? 'Amplop kiri yang kamu pilih'
                      : _selectedIndex == 1
                          ? 'Amplop tengah yang kamu pilih'
                          : 'Amplop kanan yang kamu pilih',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 5. Kartu Hasil Pop Reveal
              _buildResultCard(
                session: session,
                showOpenedState: showOpenedState,
              ),
              const SizedBox(height: 24),

              // 6. Bar Budget Grup untuk Date Ini
              _buildBudgetStatusBar(budget: currentBudget, isLocked: isLocked),
              const SizedBox(height: 12),

              // 7. Tombol Aksi BUKA AMPLOP (bg Mint / #3DDBB0)
              _buildActionButton(
                group: group,
                canPlay: canPlay,
                isLocked: isLocked,
                showOpenedState: showOpenedState,
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

  Widget _buildEnvelopesShowcase({required bool showOpenedState}) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 340,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final isChosen = _selectedIndex == index;
              final color = _envelopeColors[index % _envelopeColors.length];
              final amount = _envelopeAmounts.length > index ? _envelopeAmounts[index] : 0;

              return GestureDetector(
                key: ValueKey('envelope_$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectEnvelopeIndex(index),
                child: _GroupEnvelopeItem(
                  index: index,
                  isChosen: isChosen,
                  color: color,
                  controller: _openController,
                  amountText: RupiahFormatter.formatCompact(amount),
                  isOpening: _isOpening,
                  showOpenedState: showOpenedState,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required GroupSessionModel? session,
    required bool showOpenedState,
  }) {
    if (_isOpening) {
      return const SizedBox(height: 68);
    }

    final displayedAmount = _wonAmount ?? session?.budget;

    if (!showOpenedState || displayedAmount == null || displayedAmount == 0) {
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
                'Pilih amplop dan tekan buka',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Rp0',
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
                'Isi amplop',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                RupiahFormatter.format(displayedAmount),
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 30,
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

  Widget _buildActionButton({
    required GroupModel group,
    required bool canPlay,
    required bool isLocked,
    required bool showOpenedState,
  }) {
    final myUid = ref.watch(groupAuthServiceProvider).currentUid ?? '';
    final isOwner = group.isOwner(myUid);
    final isOwnerPolicyBlocked = !canPlay;
    final isSessionLocked = isLocked && group.lockPolicy == 'lock';

    String buttonText = 'BUKA AMPLOP';
    bool isButtonDisabled = _isOpening;

    if (isOwnerPolicyBlocked) {
      buttonText = 'Hanya pemilik yang bisa memainkan';
      isButtonDisabled = true;
    } else if (isSessionLocked) {
      buttonText = 'Date berjalan · permainan terkunci';
      isButtonDisabled = true;
    } else if (_isOpening) {
      buttonText = 'MEMBUKA...';
      isButtonDisabled = true;
    } else if (showOpenedState && group.lockPolicy == 'lock') {
      buttonText = 'AMPLOP SUDAH DIBUKA';
      isButtonDisabled = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerButton.large(
          text: buttonText,
          backgroundColor: isButtonDisabled ? AppColors.surface : AppColors.mint,
          textColor: AppColors.ink,
          borderColor: AppColors.ink,
          onPressed: isButtonDisabled
              ? (isSessionLocked && isOwner ? () => _confirmEndSession(group) : null)
              : () => _openEnvelope(group, canPlay, isSessionLocked),
        ),
        if (isSessionLocked && isOwner) ...[
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
}

/// Widget Amplop Tunggal untuk Grup
/// Mengimplementasikan @keyframes jw, dm, op, sl persis seperti GAmplop.dc.html
class _GroupEnvelopeItem extends StatelessWidget {
  final int index;
  final bool isChosen;
  final Color color;
  final AnimationController controller;
  final String amountText;
  final bool isOpening;
  final bool showOpenedState;

  const _GroupEnvelopeItem({
    required this.index,
    required this.isChosen,
    required this.color,
    required this.controller,
    required this.amountText,
    required this.isOpening,
    required this.showOpenedState,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;

        double opacity = 1.0;
        double scale = 1.0;
        double jiggleAngle = 0.0;
        double flapScaleY = 1.0;
        double slidePaperY = 0.0;

        if (showOpenedState && !isOpening) {
          // Bila sudah terbuka permanen
          if (isChosen) {
            opacity = 1.0;
            scale = 1.0;
            flapScaleY = -1.0;
            slidePaperY = -66.0;
          } else {
            // Amplop lain tampil redup untuk semua anggota sesuai spec UPDATE 2D
            opacity = 0.4;
            scale = 0.92;
            flapScaleY = 1.0;
            slidePaperY = -28.0; // Sedikit mengintip nominalnya
          }
        } else if (isOpening) {
          if (!isChosen) {
            // @keyframes dm: 0%,32% -> 1; 42%,92% -> opacity: .4, scale: .92
            if (t < 0.32) {
              opacity = 1.0;
              scale = 1.0;
            } else if (t < 0.42) {
              final p = (t - 0.32) / 0.10;
              opacity = 1.0 - 0.6 * p;
              scale = 1.0 - 0.08 * p;
            } else {
              opacity = 0.4;
              scale = 0.92;
              slidePaperY = -28.0 * ((t - 0.42) / 0.58).clamp(0.0, 1.0);
            }
          } else {
            // @keyframes jw: goyang 0%-24%
            if (t <= 0.06) {
              jiggleAngle = -4.0 * (t / 0.06);
            } else if (t <= 0.12) {
              final u = (t - 0.06) / 0.06;
              jiggleAngle = -4.0 + 8.0 * u;
            } else if (t <= 0.18) {
              final u = (t - 0.12) / 0.06;
              jiggleAngle = 4.0 - 7.0 * u;
            } else if (t <= 0.24) {
              final u = (t - 0.18) / 0.06;
              jiggleAngle = -3.0 * (1.0 - u);
            } else {
              jiggleAngle = 0.0;
            }

            // @keyframes op: 0%,38% -> 1; 52%,92% -> -1
            if (t <= 0.38) {
              flapScaleY = 1.0;
            } else if (t <= 0.52) {
              final u = (t - 0.38) / 0.14;
              flapScaleY = math.cos(u * math.pi);
            } else {
              flapScaleY = -1.0;
            }

            // @keyframes sl: 0%,48% -> 0; 62%,92% -> -66px
            if (t <= 0.48) {
              slidePaperY = 0.0;
            } else if (t <= 0.62) {
              final u = (t - 0.48) / 0.14;
              slidePaperY = -66.0 * Curves.easeOutCubic.transform(u);
            } else {
              slidePaperY = -66.0;
            }
          }
        }

        final showRevealedAmount = (isChosen && (t > 0.60 || showOpenedState)) ||
            (!isChosen && (t > 0.45 || showOpenedState));

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: jiggleAngle * math.pi / 180,
              child: SizedBox(
                width: 104,
                height: 140,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Kertas hasil di dalam amplop (.pa: top 40px, height 80px, white)
                    Positioned(
                      top: 40 + slidePaperY,
                      child: Container(
                        width: 80,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.ink, width: 3),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          showRevealedAmount ? amountText : '?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.buttonSmall.copyWith(
                            color: AppColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    // Badan Amplop (.bd: top 36px, height 92px, radius 14px, border 3.5px)
                    Positioned(
                      top: 36,
                      child: Container(
                        width: 104,
                        height: 92,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink, width: 3.5),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '?',
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),

                    // Tutup Segitiga Amplop / Flap (.fl: top 36px, width 104, height 52)
                    Positioned(
                      top: 36,
                      child: Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.diagonal3Values(1.0, flapScaleY, 1.0),
                        child: SizedBox(
                          width: 104,
                          height: 52,
                          child: CustomPaint(
                            painter: _GroupEnvelopeFlapPainter(color: color),
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
      },
    );
  }
}

class _GroupEnvelopeFlapPainter extends CustomPainter {
  final Color color;

  const _GroupEnvelopeFlapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;

    // Sesuai GAmplop.dc.html SVG path: M2 2H102L52 48Z
    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(size.width - 2, 2)
      ..lineTo(size.width / 2, size.height - 4)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GroupEnvelopeFlapPainter oldDelegate) =>
      oldDelegate.color != color;
}
