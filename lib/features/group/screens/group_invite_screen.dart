import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/sticker_card.dart';
import '../../../core/widgets/sticker_snackbar.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/widgets/invite_code_boxes.dart';
import '../../../core/group/widgets/member_avatar.dart';
import '../../../core/group/widgets/dashed_member_slot.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../../navigation/app_router.dart';

/// Layar 17: Kode Undangan, Daftar Anggota Realtime & Kelola Grup
class GroupInviteScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupInviteScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  bool _isRegenerating = false;
  bool _initialCheckDone = false;
  bool _wasInWaitingRoom = false;
  bool _hasAutoNavigatedToWheel = false;
  Timer? _presenceHeartbeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(groupServiceProvider).ensureRealtimeActive(widget.groupId);
        ref.read(groupServiceProvider).updatePresence(widget.groupId);
      }
    });
    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.read(groupServiceProvider).updatePresence(widget.groupId);
      }
    });
  }

  @override
  void dispose() {
    _presenceHeartbeat?.cancel();
    super.dispose();
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    showStickerSnackbar(context, message: 'Kode $code berhasil disalin!');
  }

  void _shareCode(String code, String groupName) {
    SharePlus.instance.share(
      ShareParams(text: 'Gabung grup "$groupName" di Putar Jajan: kode $code'),
    );
  }

  Future<void> _handleRegenerateCode(GroupModel group) async {
    final confirmed = await GroupImportantDialog.showConfirmRegenerateCode(
      context,
      oldCode: group.code,
    );

    if (confirmed == true) {
      setState(() => _isRegenerating = true);
      try {
        final groupService = ref.read(groupServiceProvider);
        final newCode = await groupService.regenerateInviteCode(widget.groupId);
        if (mounted) {
          showStickerSnackbar(context, message: 'Kode baru: $newCode');
        }
      } catch (e) {
        if (mounted) {
          showStickerSnackbar(context, message: 'Gagal mengganti kode');
        }
      } finally {
        if (mounted) {
          setState(() => _isRegenerating = false);
        }
      }
    }
  }

  Future<void> _handleRemoveMember(GroupMemberModel member) async {
    final confirmed = await GroupImportantDialog.showConfirmKickMember(
      context,
      memberName: member.name,
    );

    if (confirmed == true) {
      try {
        final groupService = ref.read(groupServiceProvider);
        await groupService.removeMember(
          gid: widget.groupId,
          memberUid: member.uid,
          memberName: member.name,
        );
        if (mounted) {
          showStickerSnackbar(context, message: '${member.name} telah dikeluarkan');
        }
      } catch (e) {
        if (mounted) {
          showStickerSnackbar(context, message: 'Gagal mengeluarkan anggota');
        }
      }
    }
  }

  Future<void> _handleLeaveGroup() async {
    final confirmed = await GroupImportantDialog.showConfirmLeaveGroup(
      context,
    );

    if (confirmed == true) {
      try {
        final groupService = ref.read(groupServiceProvider);
        await groupService.leaveGroup(widget.groupId);
        if (!mounted) return;
        ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
        ref.read(activeGroupIdProvider.notifier).state = null;
        showStickerSnackbar(context, message: 'Kamu telah keluar dari grup');
        try {
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
          context.go('/');
        } catch (_) {
          context.go('/');
        }
      } catch (e) {
        if (mounted) {
          showStickerSnackbar(context, message: 'Gagal keluar dari grup');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final groupService = ref.watch(groupServiceProvider);
    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid;

    return StreamBuilder<GroupModel?>(
      stream: groupService.watchGroup(widget.groupId),
      builder: (context, groupSnapshot) {
        final group = groupSnapshot.data;
        final groupName = group?.name ?? 'Grup Bersama';
        final groupCode = group?.code ?? '......';
        final isOwner = group == null || authService.isCurrentUser(group.ownerUid);

        // Inisialisasi status ruang tunggu hanya saat pertama kali layar dibuka
        if (!_initialCheckDone && group != null) {
          _initialCheckDone = true;
          // Anggota hanya dianggap "sedang menunggu di ruang tunggu" jika saat layar dibuka sesi BELUM aktif.
          // Jika saat dibuka sesi sudah aktif (misal user datang dari tombol Kelola di roda), JANGAN pernah auto-navigasi!
          _wasInWaitingRoom = (group.activeSession == null);
        }

        // Auto-Navigasi untuk Anggota HANYA jika awalnya sedang menunggu di ruang tunggu,
        // lalu pemilik grup baru saja memulai sesi (transisi dari null ke activeSession)
        if (!isOwner &&
            _wasInWaitingRoom &&
            group.activeSession != null &&
            !_hasAutoNavigatedToWheel) {
          _hasAutoNavigatedToWheel = true;
          _wasInWaitingRoom = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(appScopeProvider.notifier).state = AppScope.grup;
            ref.read(activeGroupIdProvider.notifier).state = widget.groupId;
            SoundService.instance.play(Sfx.winLolos);
            showStickerSnackbar(context, message: '🎉 Sesi dimulai! Membuka roda jajan...');
            context.go('/roda');
          });
        }

        return Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            backgroundColor: t.bg,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: CustomPaint(
                size: const Size(22, 22),
                painter: CustomBackArrowPainter(color: t.ink),
              ),
              onPressed: () {
                final isCurrentMember = isOwner || (ref.read(activeGroupIdProvider) == widget.groupId);
                if (isCurrentMember) {
                  ref.read(appScopeProvider.notifier).state = AppScope.grup;
                  ref.read(activeGroupIdProvider.notifier).state = widget.groupId;
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/roda');
                  }
                } else {
                  ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
                  ref.read(activeGroupIdProvider.notifier).state = null;
                  final rootCtx = rootNavigatorKey.currentContext ?? context;
                  try {
                    Navigator.of(rootCtx, rootNavigator: true).popUntil((route) => route.isFirst);
                    GoRouter.of(rootCtx).go('/');
                  } catch (_) {
                    context.go('/');
                  }
                }
              },
            ),
            title: Text(
              groupName,
              style: t.titleMedium.copyWith(color: t.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: CustomPaint(
                  size: const Size(20, 20),
                  painter: CustomExitPainter(color: t.ink),
                ),
                tooltip: 'Keluar Grup',
                onPressed: _handleLeaveGroup,
              ),
            ],
          ),
          body: SafeArea(
            child: StreamBuilder<List<GroupMemberModel>>(
              stream: groupService.watchMembers(widget.groupId),
              builder: (context, membersSnapshot) {
                final members = membersSnapshot.data ?? [];

                // Deduplikasi anggota untuk tampilan agar tidak terjadi duplikasi UI
                final uniqueDisplayMembers = <GroupMemberModel>[];
                final seenNames = <String>{};
                final seenUids = <String>{};
                for (final m in members) {
                  final cleanName = m.name.toLowerCase().trim();
                  if (!seenUids.contains(m.uid) && (m.isOwner || !seenNames.contains(cleanName))) {
                    seenUids.add(m.uid);
                    if (!m.isOwner) seenNames.add(cleanName);
                    uniqueDisplayMembers.add(m);
                  }
                }
                final memberCount = uniqueDisplayMembers.length;

                // Keamanan: Jika user bukan pemilik dan bukan lagi anggota dalam daftar grup ini,
                // segera bersihkan akses grup dan kembalikan ke mode pribadi
                final isOwnerMember = isOwner || members.any((m) => m.role == 'owner' && authService.isCurrentUser(m.uid));
                final myName = authService.displayName?.toLowerCase().trim();
                final isCurrentUserMember = members.any((m) =>
                    authService.isCurrentUser(m.uid) ||
                    (myName != null && myName.isNotEmpty && m.name.toLowerCase().trim() == myName));
                if (myUid != null && !isOwnerMember && members.isNotEmpty && !isCurrentUserMember) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ref.read(groupServiceProvider).setActiveGroupId(null);
                    ref.read(activeGroupIdProvider.notifier).state = null;
                    ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
                    final rootCtx = rootNavigatorKey.currentContext ?? context;
                    try {
                      Navigator.of(rootCtx, rootNavigator: true).popUntil((route) => route.isFirst);
                      GoRouter.of(rootCtx).go('/');
                    } catch (_) {
                      try {
                        context.go('/');
                      } catch (_) {}
                    }
                    GroupImportantDialog.showKickedFromGroup(
                      rootCtx,
                      groupName: groupName,
                    );
                  });
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Kartu Kode Undangan Besar
                            _buildInviteCodeCard(
                              t: t,
                              group: group,
                              groupName: groupName,
                              code: groupCode,
                              isOwner: isOwner,
                            ),
                            const SizedBox(height: 20),

                            // Header Anggota
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Anggota Grup',
                                          style: t.titleMedium.copyWith(fontSize: 18),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: t.secondary,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: t.ink, width: 1.8),
                                        ),
                                        child: Text(
                                          '$memberCount / 10',
                                          style: t.buttonSmall.copyWith(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOwner && group != null)
                                  GestureDetector(
                                    onTap: _isRegenerating
                                        ? null
                                        : () {
                                            SoundService.instance.play(Sfx.uiTap);
                                            _handleRegenerateCode(group);
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: t.bg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: t.ink, width: 1.8),
                                      ),
                                      child: Row(
                                        children: [
                                          CustomPaint(
                                            size: const Size(12, 12),
                                            painter: CustomSyncArrowsPainter(color: t.ink),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ganti Kode',
                                            style: t.buttonSmall.copyWith(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Daftar Anggota Aktif
                            ...uniqueDisplayMembers.map((member) => _buildMemberTile(
                                  t: t,
                                  member: member,
                                  isCurrentUser: authService.isCurrentUser(member.uid) ||
                                      (myName != null && myName.isNotEmpty && member.name.toLowerCase().trim() == myName),
                                  canKick: isOwner && !authService.isCurrentUser(member.uid) && !member.isOwner,
                                )),

                            // Slot Putus-putus untuk sisa kuota (maks 10)
                            if (memberCount < 10)
                              const DashedMemberSlot(
                                label: 'Menunggu teman bergabung...',
                              ),
                            const SizedBox(height: 16),

                            // Kartu Pilihan Nominal Roda
                            if (group != null)
                              _buildWheelSlotsCard(
                                t: t,
                                group: group,
                                isOwner: isOwner,
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Tombol Bawah: Mulai Pakai Grup / Masuk ke Roda Sesi
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.bg,
                        border: Border(
                          top: BorderSide(color: t.ink, width: t.subtleBorderWidth),
                        ),
                      ),
                      child: isOwner
                          ? StickerButton(
                              text: group?.activeSession != null
                                  ? 'Kembali ke Roda Sesi'
                                  : 'Mulai Pakai Grup',
                              backgroundColor: t.success,
                              height: 52,
                              borderRadius: 16,
                              onPressed: () async {
                                if (group?.activeSession == null) {
                                  await groupService.notifySessionStarted(widget.groupId);
                                }
                                if (!context.mounted) return;
                                ref.read(appScopeProvider.notifier).state = AppScope.grup;
                                ref.read(activeGroupIdProvider.notifier).state = widget.groupId;
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  context.go('/roda');
                                }
                              },
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (group.activeSession == null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: t.secondary.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.ink, width: 2),
                                    ),
                                    child: Row(
                                      children: [
                                        CustomPaint(
                                          size: const Size(16, 16),
                                          painter: CustomClockPainter(color: t.ink),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Menunggu Pemilik Memulai Sesi... Kamu otomatis dialihkan saat sesi dimulai.',
                                            style: t.bodySmall.copyWith(
                                              fontSize: 12,
                                              fontWeight: t.weightBold,
                                              color: t.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: t.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.ink, width: 2),
                                    ),
                                    child: Row(
                                      children: [
                                        CustomPaint(
                                          size: const Size(16, 16),
                                          painter: CustomFlagPainter(color: t.ink),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Sesi jajan grup sedang aktif bersama anggota.',
                                            style: t.bodySmall.copyWith(
                                              fontSize: 12,
                                              fontWeight: t.weightBold,
                                              color: t.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                StickerButton(
                                  text: group.activeSession != null
                                      ? 'Kembali ke Roda Sesi'
                                      : 'Masuk ke Roda Sesi',
                                  backgroundColor: t.secondary,
                                  height: 52,
                                  borderRadius: 16,
                                  onPressed: () {
                                    ref.read(appScopeProvider.notifier).state = AppScope.grup;
                                    ref.read(activeGroupIdProvider.notifier).state = widget.groupId;
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    } else {
                                      context.go('/roda');
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                StickerButton(
                                  text: 'Keluar dari Grup',
                                  backgroundColor: t.surface,
                                  textColor: t.danger,
                                  borderColor: t.danger,
                                  height: 48,
                                  borderRadius: 16,
                                  onPressed: _handleLeaveGroup,
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWheelSlotsCard({
    required PutarTheme t,
    required GroupModel group,
    required bool isOwner,
  }) {
    final slots = group.effectiveSlots;
    final isFixed = group.budgetMode == 'fixed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Kartu Menu: Budget & Permainan (Layar 53/54)
        GestureDetector(
          onTap: () {
            SoundService.instance.play(Sfx.uiTap);
            context.push('/group/budget-settings/${group.id}');
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(20),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CustomPaint(
                          size: const Size(18, 18),
                          painter: CustomGearPainter(color: t.ink),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Budget & Permainan',
                          style: t.titleMedium.copyWith(
                            fontSize: 16,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isFixed ? t.success : t.secondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.ink, width: 1.8),
                      ),
                      child: Text(
                        isFixed ? 'Angka Tetap' : 'Dari Permainan',
                        style: t.buttonSmall.copyWith(
                          fontSize: 11,
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isFixed
                      ? 'Budget tetap ${RupiahFormatter.format(group.fixedBudget)} per date (tanpa putar roda).'
                      : 'Budget date diundi dari putaran roda (${group.spinPolicy == 'all' ? 'Semua anggota boleh putar' : 'Hanya pemilik'}).',
                  style: t.bodySmall.copyWith(
                    fontSize: 12,
                    color: t.ink.withValues(alpha: 0.75),
                  ),
                ),
                if (!isFixed) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(slots.length, (idx) {
                      final color = t.getWheelColor(idx);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.ink, width: 1.5),
                        ),
                        child: Text(
                          RupiahFormatter.formatCompact(slots[idx]),
                          style: t.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isOwner ? 'Atur Budget & Permainan →' : 'Lihat Pengaturan →',
                      style: t.buttonSmall.copyWith(
                        fontSize: 12,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Kartu Menu: Notifikasi Grup (Layar 44)
        GestureDetector(
          onTap: () {
            SoundService.instance.play(Sfx.uiTap);
            context.push('/group/notifications');
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(20),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.info,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.ink, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(20, 20),
                    painter: CustomBellIconPainter(
                      color: t.ink,
                      strokeWidth: 2.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifikasi Grup',
                        style: t.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atur banner & nada notifikasi aktivitas',
                        style: t.bodySmall.copyWith(
                          fontSize: 11,
                          color: t.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                CustomPaint(
                  size: const Size(14, 14),
                  painter: CustomChevronRightPainter(color: t.ink, strokeWidth: 2.2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeCard({
    required PutarTheme t,
    required GroupModel? group,
    required String groupName,
    required String code,
    required bool isOwner,
  }) {
    return StickerCard(
      backgroundColor: t.surface,
      borderColor: t.ink,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            'Kode Undangan Grup',
            style: t.bodySmall.copyWith(
              fontWeight: t.weightBold,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // 6 Kotak Kode Read-Only
          InviteCodeBoxes(
            code: code,
            isReadOnly: true,
          ),
          const SizedBox(height: 16),

          // Tombol Salin & Bagikan
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    _copyCode(code);
                  },
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.ink, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: t.miniShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(16, 16),
                              painter: CustomCopyPainter(color: t.ink),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Salin Kode',
                              style: TextStyle(
                                fontFamily: t.fontFamily,
                                fontSize: 13,
                                fontWeight: t.weightExtraBold,
                                color: t.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    _shareCode(code, groupName);
                  },
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.info,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.ink, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: t.miniShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(16, 16),
                              painter: CustomSharePainter(color: t.ink),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bagikan',
                              style: TextStyle(
                                fontFamily: t.fontFamily,
                                fontSize: 13,
                                fontWeight: t.weightExtraBold,
                                color: t.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile({
    required PutarTheme t,
    required GroupMemberModel member,
    required bool isCurrentUser,
    required bool canKick,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.ink, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.miniShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          MemberAvatar(
            name: member.name,
            colorIndex: member.colorIndex,
            isOwner: member.isOwner,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: t.bodyLargeBold.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(Kamu)',
                        style: t.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: t.weightBold,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  member.isOwner ? 'Pemilik Grup' : 'Anggota',
                  style: t.bodySmall.copyWith(
                    fontSize: 11,
                    color: member.isOwner ? t.accentOrange : t.textSecondary,
                    fontWeight: member.isOwner ? t.weightExtraBold : t.weightMedium,
                  ),
                ),
              ],
            ),
          ),
          if (canKick)
            GestureDetector(
              onTap: () {
                SoundService.instance.play(Sfx.uiTap);
                _handleRemoveMember(member);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.danger, width: 1.5),
                ),
                child: Text(
                  'Keluarkan',
                  style: t.buttonSmall.copyWith(
                    fontSize: 10,
                    color: t.danger,
                  ),
                ),
              ),
            )
          else if (isCurrentUser && !member.isOwner)
            GestureDetector(
              onTap: () {
                SoundService.instance.play(Sfx.uiTap);
                _handleLeaveGroup();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.danger, width: 1.5),
                ),
                child: Text(
                  'Keluar',
                  style: t.buttonSmall.copyWith(
                    fontSize: 11,
                    fontWeight: t.weightExtraBold,
                    color: t.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

