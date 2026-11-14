import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/group/models/group_event_model.dart';
import '../../../core/group/models/group_history_models.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_note_model.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/painters/confetti_painter.dart';
import '../../../core/painters/mochi_painter.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/indonesian_date_formatter.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import 'group_date_detail_screen.dart';

/// Pembangun URI terpusat untuk navigasi ke Layar 68/69 (/group/date-result)
/// agar pemanggil di layar catatan, game, maupun realtime listener seragam.
Uri buildGroupDateResultUri({
  required String groupName,
  required int budget,
  required int totalSpent,
  required int itemCount,
  String? groupId,
  String? sessionId,
  String? budgetByName,
  String? budgetGame,
  String? endedByName,
  String? endedByUid,
  DateTime? sessionDate,
  DateTime? endedAt,
}) {
  return Uri(
    path: '/group/date-result',
    queryParameters: {
      'groupName': groupName,
      'budget': budget.toString(),
      'totalSpent': totalSpent.toString(),
      'itemCount': itemCount.toString(),
      if (groupId != null && groupId.isNotEmpty) 'gid': groupId,
      if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
      if (budgetByName != null && budgetByName.isNotEmpty)
        'budgetByName': budgetByName,
      if (budgetGame != null && budgetGame.isNotEmpty) 'budgetGame': budgetGame,
      if (endedByName != null && endedByName.isNotEmpty)
        'endedByName': endedByName,
      if (endedByUid != null && endedByUid.isNotEmpty) 'endedByUid': endedByUid,
      if (sessionDate != null)
        'sessionDateMs': sessionDate.millisecondsSinceEpoch.toString(),
      if (endedAt != null)
        'endedAtMs': endedAt.millisecondsSinceEpoch.toString(),
    },
  );
}

/// Layar 68 & 69: Hasil Date Grup (Hgrup1.dc.html & Hgrup2.dc.html)
/// - Layar 68 (Lolos): latar Mint (#3DDBB0), konfeti, stempel centang Matahari
/// - Layar 69 (Lewat): latar Peach pastel (#FFC9BE), tanpa konfeti, stempel segitiga peringatan Tomat
class GroupDateResultScreen extends ConsumerStatefulWidget {
  final String groupName;
  final int budget;
  final int totalSpent;
  final int itemCount;
  final String? groupId;
  final String? sessionId;
  final DateTime? sessionDate;
  final String? budgetByName;
  final String? budgetGame;
  final String? endedByName;
  final String? endedByUid;
  final DateTime? endedAt;
  final List<MemberSpendingSummary>? memberSpendings;

  const GroupDateResultScreen({
    super.key,
    required this.groupName,
    required this.budget,
    required this.totalSpent,
    required this.itemCount,
    this.groupId,
    this.sessionId,
    this.sessionDate,
    this.budgetByName,
    this.budgetGame,
    this.endedByName,
    this.endedByUid,
    this.endedAt,
    this.memberSpendings,
  });

  @override
  ConsumerState<GroupDateResultScreen> createState() =>
      _GroupDateResultScreenState();
}

class _GroupDateResultScreenState extends ConsumerState<GroupDateResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _stampController;
  late final AnimationController _contentController;
  late final Animation<double> _stampScale;
  late final Animation<double> _stampRotation;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  Timer? _contentDelayTimer;
  bool _didStartEntry = false;

  @override
  void initState() {
    super.initState();

    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // Stempel: scale(2.2) -> scale(1.0) easeOutBack, rotasi -25 deg -> -6 deg
    _stampScale = Tween<double>(begin: 2.2, end: 1.0).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.easeOutBack),
    );
    _stampRotation = Tween<double>(
      begin: -25.0 * math.pi / 180.0,
      end: -6.0 * math.pi / 180.0,
    ).animate(
      CurvedAnimation(parent: _stampController, curve: Curves.easeOutCubic),
    );

    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartEntry) return;
    _didStartEntry = true;

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _stampController.duration = const Duration(milliseconds: 100);
      _contentController.duration = const Duration(milliseconds: 100);
    }

    final isPassed = widget.totalSpent <= widget.budget;
    if (isPassed) {
      SoundService.instance.play(Sfx.winLolos);
      HapticFeedback.mediumImpact();
    } else {
      SoundService.instance.play(Sfx.overBudget);
      HapticFeedback.lightImpact();
    }

    _stampController.forward();
    if (disableAnimations) {
      _contentController.forward();
    } else {
      _contentDelayTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) {
          _contentController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _contentDelayTimer?.cancel();
    _stampController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _shareResult({
    required String groupTitle,
    required bool isPassed,
    required int diff,
    required int totalSpent,
    required int budget,
    required int itemCount,
  }) {
    SoundService.instance.play(Sfx.uiTap);
    final statusText = isPassed
        ? 'Lolos budget! Grup hemat ${RupiahFormatter.format(diff)}'
        : 'Budget lewat ${RupiahFormatter.format(diff)} (Terpakai ${RupiahFormatter.format(totalSpent)})';
    try {
      SharePlus.instance.share(
        ShareParams(
          text:
              'Hasil Date Grup $groupTitle pakai Putar Jajan:\n$statusText\nBudget: ${RupiahFormatter.format(budget)} · $itemCount catatan.',
        ),
      );
    } catch (_) {}
  }

  void _openDetailDate(String? gid, String? sessionId) {
    SoundService.instance.play(Sfx.uiTap);
    if (gid != null &&
        gid.isNotEmpty &&
        sessionId != null &&
        sessionId.isNotEmpty) {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.pushReplacement('/group/history/$gid/$sessionId');
        return;
      }
    }
    _exitResult();
  }

  void _exitResult() {
    SoundService.instance.play(Sfx.uiTap);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.maybeOf(context)?.go('/catatan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final gid = widget.groupId;
    final sessionId = widget.sessionId;
    final hasGroupContext = gid != null && gid.isNotEmpty;

    final groupService = ref.watch(groupServiceProvider);
    final authService = ref.watch(groupAuthServiceProvider);

    final activeGroup = hasGroupContext
        ? (ref.watch(activeGroupStreamProvider).valueOrNull ??
            groupService.getLocalGroup(gid))
        : null;

    GroupSessionModel? resolvedSession;
    List<GroupNoteModel> sessionNotes = const [];
    if (hasGroupContext && sessionId != null && sessionId.isNotEmpty) {
      final sessions = groupService.getLocalSessions(gid);
      final sIdx = sessions.indexWhere((s) => s.sessionId == sessionId);
      if (sIdx != -1) {
        resolvedSession = sessions[sIdx];
      }
      sessionNotes = GroupHistoryCalculator.sortActiveNotesChronologically(
        groupService
            .getLocalNotes(gid)
            .where((n) => n.sessionId == sessionId)
            .toList(),
      );
    }

    final members = hasGroupContext
        ? (ref.watch(activeGroupMembersStreamProvider).valueOrNull ??
            groupService.getLocalMembers(gid))
        : const <GroupMemberModel>[];

    final effectiveGroupName =
        activeGroup?.name.isNotEmpty == true ? activeGroup!.name : widget.groupName;
    final effectiveBudget =
        widget.budget > 0 ? widget.budget : (resolvedSession?.budget ?? 0);
    final effectiveTotalSpent = resolvedSession != null && widget.totalSpent == 0
        ? resolvedSession.totalSpent
        : widget.totalSpent;
    final effectiveItemCount =
        widget.itemCount > 0 ? widget.itemCount : sessionNotes.length;

    final isPassed = effectiveTotalSpent <= effectiveBudget;
    final diff = (effectiveBudget - effectiveTotalSpent).abs();
    final bgColor = isPassed ? t.success : t.softDangerBg;

    final effectiveDate = widget.sessionDate ??
        resolvedSession?.startedAt ??
        widget.endedAt ??
        DateTime.now();
    final pillText =
        '$effectiveGroupName · ${IndonesianDateFormatter.fullDayAndDate(effectiveDate)}';

    final rawBudgetBy = widget.budgetByName?.trim().isNotEmpty == true
        ? widget.budgetByName!.trim()
        : (resolvedSession?.budgetByName.trim().isNotEmpty == true
            ? resolvedSession!.budgetByName.trim()
            : (resolvedSession?.startedByName.trim().isNotEmpty == true
                ? resolvedSession!.startedByName.trim()
                : 'Anggota'));
    final rawGame = widget.budgetGame?.trim().isNotEmpty == true
        ? widget.budgetGame!.trim()
        : (resolvedSession?.game.trim().isNotEmpty == true
            ? resolvedSession!.game.trim()
            : 'wheel');
    final gameLabel = GroupEventModel.formatGameName(rawGame);

    final endedByUid = widget.endedByUid?.isNotEmpty == true
        ? widget.endedByUid!
        : (resolvedSession?.endedByUid ?? '');
    final isEndedByMe =
        endedByUid.isNotEmpty && authService.isCurrentUser(endedByUid);
    final rawEndedByName = widget.endedByName?.trim().isNotEmpty == true
        ? widget.endedByName!.trim()
        : (resolvedSession?.endedByName?.trim().isNotEmpty == true
            ? resolvedSession!.endedByName!.trim()
            : 'Pemilik');
    final endedByDisplay = isEndedByMe
        ? 'Kamu (pemilik)'
        : '$rawEndedByName (pemilik)';

    final effectiveEndedAt =
        widget.endedAt ?? resolvedSession?.endedAt ?? DateTime.now();
    final endedTime = GroupDateDetailScreen.formatDotTime(effectiveEndedAt);

    final computedSpendings = widget.memberSpendings ??
        (members.isNotEmpty
            ? GroupHistoryCalculator.computeMemberSpending(
                members: members,
                notes: sessionNotes,
              )
            : const <MemberSpendingSummary>[]);

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 340 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (isPassed && !disableAnimations)
            Positioned.fill(
              child: IgnorePointer(
                child: t.celebration == PutarCelebrationStyle.hearts
                    ? const HeartConfettiField(particleCount: 28)
                    : const ConfettiField(particleCount: 28),
              ),
            ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Pill Konteks Atas ("{Grup} · {Tanggal}")
                  Center(
                    child: Semantics(
                      label: 'Hasil date $pillText',
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: screenWidth - horizontalPadding * 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(t.chipRadius),
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
                          pillText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Stempel Bulat 110x110 (Lolos: Matahari + Check; Lewat: Tomat + Warning)
                  Center(
                    child: _buildAnimatedStamp(
                      t: t,
                      isPassed: isPassed,
                      disableAnimations: disableAnimations,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Headline, Subjudul, Nominal Besar + Kartu (stagger +100ms)
                  _buildAnimatedContent(
                    disableAnimations: disableAnimations,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          label: isPassed
                              ? 'Lolos budget! Grup hemat ${RupiahFormatter.format(diff)}'
                              : '${t.text(PutarCopyKeys.budgetOverAmount, params: {'amount': RupiahFormatter.format(diff).replaceFirst('Rp', '')})}, total terpakai ${RupiahFormatter.format(effectiveTotalSpent)}',
                          child: Column(
                            children: [
                              Text(
                                isPassed
                                    ? 'Lolos budget!'
                                    : t.text(
                                        PutarCopyKeys.budgetOverAmount,
                                        params: {
                                          'amount': RupiahFormatter.format(diff)
                                              .replaceFirst('Rp', ''),
                                        },
                                      ),
                                textAlign: TextAlign.center,
                                style: t.displayLarge.copyWith(
                                  fontSize: isPassed ? 34 : 26,
                                  fontWeight: t.weightExtraBold,
                                  color: t.ink,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPassed
                                    ? 'Grup hemat'
                                    : 'Gak apa-apa, catat dan putar lagi minggu depan',
                                textAlign: TextAlign.center,
                                style: t.bodyMedium.copyWith(
                                  fontSize: isPassed ? 16 : 14,
                                  fontWeight: t.weightBold,
                                  color: t.ink.withValues(alpha: 0.85),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isPassed
                                      ? RupiahFormatter.format(diff)
                                      : RupiahFormatter.format(
                                          effectiveTotalSpent,
                                        ),
                                  textAlign: TextAlign.center,
                                  style: t.displayLarge.copyWith(
                                    fontSize: isPassed ? 46 : 40,
                                    fontWeight: t.weightExtraBold,
                                    color: t.ink,
                                    letterSpacing: -1.4,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Kartu 1: Ringkasan 3 Kolom (Budget | Terpakai | Catatan)
                        _ResultNeoCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SummaryStatCol(
                                  label: 'Budget',
                                  value: RupiahFormatter.format(effectiveBudget),
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 34,
                                color: t.ink.withValues(alpha: 0.16),
                              ),
                              Expanded(
                                child: _SummaryStatCol(
                                  label: 'Terpakai',
                                  value: RupiahFormatter.format(
                                    effectiveTotalSpent,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 34,
                                color: t.ink.withValues(alpha: 0.16),
                              ),
                              Expanded(
                                child: _SummaryStatCol(
                                  label: 'Catatan',
                                  value: '$effectiveItemCount',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Kartu 2: PENGELUARAN PER ORANG (netral tanpa ranking)
                        _ResultNeoCard(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'PENGELUARAN PER ORANG',
                                textAlign: TextAlign.center,
                                style: t.bodySmall.copyWith(
                                  fontSize: 11,
                                  fontWeight: t.weightExtraBold,
                                  letterSpacing: 0.8,
                                  color: t.ink.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildMembersGrid(
                                computedSpendings,
                                effectiveTotalSpent,
                              ),
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 9),
                                color: t.ink.withValues(alpha: 0.14),
                              ),
                              Text(
                                'Penentu budget: $rawBudgetBy · $gameLabel',
                                textAlign: TextAlign.center,
                                style: t.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: t.weightBold,
                                  color: t.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tombol 1: Matahari "Lihat detail date"
                        _ResultActionButton(
                          label: 'Lihat detail date',
                          backgroundColor: t.secondary,
                          semanticLabel: 'Lihat detail date',
                          onTap: () => _openDetailDate(gid, sessionId),
                        ),
                        const SizedBox(height: 8),

                        // Tombol 2 & 3: Bagikan | Tutup
                        Row(
                          children: [
                            Expanded(
                              child: _ResultActionButton(
                                label: 'Bagikan',
                                backgroundColor: t.surface,
                                semanticLabel: 'Bagikan hasil date',
                                onTap: () => _shareResult(
                                  groupTitle: effectiveGroupName,
                                  isPassed: isPassed,
                                  diff: diff,
                                  totalSpent: effectiveTotalSpent,
                                  budget: effectiveBudget,
                                  itemCount: effectiveItemCount,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ResultActionButton(
                                label: 'Tutup',
                                backgroundColor: t.surface,
                                semanticLabel: 'Tutup hasil date',
                                onTap: _exitResult,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Footer Info
                        Text(
                          'Diselesaikan $endedByDisplay · $endedTime · dilihat semua anggota',
                          textAlign: TextAlign.center,
                          style: t.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: t.weightSemiBold,
                            color: t.ink.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStamp({
    required PutarTheme t,
    required bool isPassed,
    required bool disableAnimations,
  }) {
    if (t.mascot == PutarMascotKind.mochi) {
      final mochi = MochiWidget(
        size: 124,
        expression: isPassed ? MochiExpression.happy : MochiExpression.sad,
        animate: !disableAnimations,
      );
      if (disableAnimations) {
        return FadeTransition(
          opacity: _stampController,
          child: mochi,
        );
      }
      return AnimatedBuilder(
        animation: _stampController,
        builder: (context, child) {
          final jumpDy = isPassed
              ? -12.0 * math.sin(_stampController.value * math.pi).clamp(0.0, 1.0)
              : 0.0;
          return Transform.translate(
            offset: Offset(0, jumpDy),
            child: Transform.scale(
              scale: _stampScale.value,
              child: child,
            ),
          );
        },
        child: mochi,
      );
    }

    final badge = Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: isPassed ? t.secondary : t.danger,
        shape: BoxShape.circle,
        border: Border.all(color: t.ink, width: 4),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.dialogShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 56,
        height: 56,
        child: CustomPaint(
          painter: isPassed
              ? CustomCheckIconPainter(
                  color: t.ink,
                  strokeWidth: 5.0,
                )
              : CustomWarningTrianglePainter(
                  color: t.ink,
                  strokeWidth: 4.5,
                ),
        ),
      ),
    );

    if (disableAnimations) {
      return FadeTransition(
        opacity: _stampController,
        child: Transform.rotate(
          angle: -6.0 * math.pi / 180.0,
          child: badge,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _stampController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _stampRotation.value,
          child: Transform.scale(
            scale: _stampScale.value,
            child: child,
          ),
        );
      },
      child: badge,
    );
  }

  Widget _buildAnimatedContent({
    required bool disableAnimations,
    required Widget child,
  }) {
    if (disableAnimations) {
      return FadeTransition(
        alwaysIncludeSemantics: true,
        opacity: _contentFade,
        child: child,
      );
    }
    return FadeTransition(
      alwaysIncludeSemantics: true,
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: child,
      ),
    );
  }

  Widget _buildMembersGrid(
    List<MemberSpendingSummary> members,
    int totalSpent,
  ) {
    if (members.isEmpty) {
      return Center(
        child: _MemberSpendBadge(
          name: 'Grup',
          amount: totalSpent,
          color: GroupDateDetailScreen.avatarColorFor(0),
        ),
      );
    }

    if (members.length <= 4) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < members.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: _MemberSpendBadge(
                  name: members[i].name,
                  amount: members[i].amountSpent,
                  color: GroupDateDetailScreen.avatarColorFor(
                    members[i].colorIndex > 0 ? members[i].colorIndex : i,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        for (var i = 0; i < members.length; i++)
          SizedBox(
            width: 68,
            child: _MemberSpendBadge(
              name: members[i].name,
              amount: members[i].amountSpent,
              color: GroupDateDetailScreen.avatarColorFor(
                members[i].colorIndex > 0 ? members[i].colorIndex : i,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultNeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ResultNeoCard({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.ink, width: t.borderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.standardShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryStatCol extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStatCol({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: t.weightBold,
            color: t.ink.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: t.bodyLargeBold.copyWith(
              fontSize: 15,
              fontWeight: t.weightExtraBold,
              color: t.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberSpendBadge extends StatelessWidget {
  final String name;
  final int amount;
  final Color color;

  const _MemberSpendBadge({
    required this.name,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final formattedAmount = RupiahFormatter.format(amount);
    return Semantics(
      label: '$name menghabiskan $formattedAmount',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GroupCircleAvatar(
            name: name,
            color: color,
            size: 36,
            fontSize: 14,
            borderWidth: 3,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.bodySmall.copyWith(
              fontSize: 12,
              fontWeight: t.weightBold,
              color: t.ink,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formattedAmount,
              style: t.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: t.weightBold,
                color: t.ink.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final String semanticLabel;
  final VoidCallback onTap;

  const _ResultActionButton({
    required this.label,
    required this.backgroundColor,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.ink, width: t.borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: t.standardShadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: t.buttonLarge.copyWith(
                    fontSize: 15,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
