import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/painters/mochi_painter.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/sticker_snackbar.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/wheel_math.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/group/models/group_model.dart';
import '../../../core/group/models/group_member_model.dart';
import '../../../core/group/models/live_play_model.dart';
import '../../../core/group/services/clock_sync_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_game_service.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/group/widgets/member_avatar.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../../../core/widgets/in_app_toast.dart';
import '../../navigation/app_router.dart';
import '../../wheel/wheel_painter.dart';
import 'group_date_result_screen.dart';

/// Layar 18: Roda Bersama Grup
/// Menampilkan roda grup, kartu putaran terakhir, sisa budget realtime, avatar online, dan lonceng notifikasi aktivitas
class GroupWheelView extends ConsumerStatefulWidget {
  const GroupWheelView({super.key});

  @override
  ConsumerState<GroupWheelView> createState() => _GroupWheelViewState();
}

class _GroupWheelViewState extends ConsumerState<GroupWheelView>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  double _currentRotationAngle = 0.0;
  double _lastAngleForHaptic = 0.0;
  bool _isSpinning = false;
  bool _isSpectatorMode = false;
  bool _isFunSpin = false;
  String? _spectatorActorName;
  int? _spectatorBudget;
  String? _spectatorSessionId;
  String? _currentSpinSessionId;
  GroupSessionModel? _localLiveSession;

  Timer? _presenceTimer;

  List<int> _currentSlots = GroupModel.defaultSlots;
  late Map<int, TextPainter> _textPaintersCache;
  PutarTheme _cacheTheme = PutarTheme.pasarMalam;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = context.putarTheme;
    if (_cacheTheme != t) {
      for (final tp in _textPaintersCache.values) {
        tp.dispose();
      }
      _cacheTheme = t;
      _textPaintersCache = WheelPainter.buildTextCache(
        _currentSlots,
        theme: _cacheTheme,
      );
    }
  }

  void _syncSlotsIfNeeded(List<int> newSlots) {
    if (!listEquals(_currentSlots, newSlots)) {
      for (final tp in _textPaintersCache.values) {
        tp.dispose();
      }
      _currentSlots = List.from(newSlots);
      _textPaintersCache = WheelPainter.buildTextCache(
        _currentSlots,
        theme: _cacheTheme,
      );
    }
  }

  // Pan gesture tracking
  double _panStartAngle = 0.0;
  double _panCurrentAngle = 0.0;

  String? _lastSessionId;

  @override
  void initState() {
    super.initState();
    _textPaintersCache = WheelPainter.buildTextCache(_currentSlots);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: const Cubic(0.12, 0.7, 0.1, 1.0),
    );

    _spinController.addListener(_onSpinTick);
    _spinController.addStatusListener(_onSpinStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportPresence();
    });
    _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _reportPresence();
    });
  }

  void _reportPresence() {
    final activeGid = ref.read(groupServiceProvider).getActiveGroupId();
    if (activeGid != null) {
      ref.read(groupServiceProvider).updatePresence(activeGid);
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _spinController.removeListener(_onSpinTick);
    _spinController.removeStatusListener(_onSpinStatus);
    _spinController.dispose();
    for (final tp in _textPaintersCache.values) {
      tp.dispose();
    }
    super.dispose();
  }

  void _onSpinTick() {
    final newAngle = _spinAnimation.value;
    final crossed = WheelMath.hasCrossedSliceBoundary(
      previousAngle: _lastAngleForHaptic,
      currentAngle: newAngle,
      totalSlots: _currentSlots.length,
    );
    if (crossed) {
      _lastAngleForHaptic = newAngle;
      SoundService.instance.play(Sfx.wheelTick1);
      HapticFeedback.selectionClick();
    }

    setState(() {
      _currentRotationAngle = newAngle;
    });
  }

  Future<void> _onSpinStatus(AnimationStatus status) async {
    if (status == AnimationStatus.completed) {
      SoundService.instance.play(Sfx.wheelLand);
      HapticFeedback.heavyImpact();

      final wasSpectator = _isSpectatorMode;
      final authService = ref.read(groupAuthServiceProvider);
      final actorName = _spectatorActorName ??
          (wasSpectator ? 'Pemilik Grup' : (authService.displayName ?? 'Kamu'));

      final winningIndex = WheelMath.getSliceIndexAtRotation(
        rotationDegrees: _currentRotationAngle,
        totalSlots: _currentSlots.length,
      );
      final won = (wasSpectator && _spectatorBudget != null)
          ? _spectatorBudget!
          : _currentSlots[winningIndex];

      if (_isFunSpin) {
        setState(() {
          _isSpinning = false;
          _isFunSpin = false;
        });
        if (mounted) {
          showStickerSnackbar(
            context,
            message: '🎯 Roda mendarat di ${RupiahFormatter.format(won)}! (Mode Angka Tetap tetap aktif)',
          );
        }
        return;
      }

      final effectiveSessionId = wasSpectator
          ? (_spectatorSessionId ?? 'sess_${DateTime.now().millisecondsSinceEpoch}')
          : (_currentSpinSessionId ?? 'sess_${DateTime.now().millisecondsSinceEpoch}');

      setState(() {
        _isSpinning = false;
        _isSpectatorMode = false;
        _spectatorActorName = null;
        _spectatorBudget = null;
        _spectatorSessionId = null;
      });

      final formattedBudget = RupiahFormatter.format(won);

      if (wasSpectator) {
        if (mounted) {
          showStickerSnackbar(
            context,
            message: '$actorName memutar roda: $formattedBudget',
          );
        }
        return;
      }

      if (!mounted) return;
      final groupService = ref.read(groupServiceProvider);
      final activeGid =
          ref.read(activeGroupIdProvider) ?? groupService.getActiveGroupId();
      final activeGroup = ref.read(activeGroupStreamProvider).valueOrNull ??
          (activeGid != null ? groupService.getLocalGroup(activeGid) : null);

      final existingSession = activeGid != null
          ? groupService.getEffectiveActiveSession(activeGid, activeGroup)
          : activeGroup?.activeSession;

      // Jika catatan grup sebelumnya masih ada (budget > 0), tanyakan persetujuan terlebih dahulu.
      // Jika catatan grup masih kosong, langsung pasang hasil putaran ke catatan grup.
      if (existingSession != null && existingSession.budget > 0) {
        final accepted = await GroupImportantDialog.showConfirmAcceptGameBudget(
          context,
          budget: won,
          currentBudget: existingSession.budget,
          gameName: 'Roda Putar',
        );

        if (accepted != true) {
          if (mounted) {
            showStickerSnackbar(
              context,
              message:
                  'Budget $formattedBudget dibatalkan. Catatan grup tetap ${RupiahFormatter.format(existingSession.budget)}.',
            );
          }
          return;
        }
      }

      // Segera tandai sesi putaran ini agar listener global tidak memicu notifikasi tertunda/duplikat
      groupService.markSpinAsShown(effectiveSessionId);

      // Segera update kartu sesi lokal agar langsung menampilkan hasil putaran tanpa delay (0ms)
      final liveSession = GroupSessionModel(
        sessionId: effectiveSessionId,
        gid: activeGid ?? '',
        budget: won,
        game: 'wheel',
        startedByUid: authService.currentUid ?? '',
        startedByName: actorName,
        startedAt: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _localLiveSession = liveSession;
        });
      }

      // 0ms LOCAL-FIRST: Bersihkan penanda sesi berakhir, lalu simpan ke local group agar tab Catatan
      // langsung menampilkan budget aktif seketika tanpa delay atau tertimpa polling!
      if (activeGid != null) {
        await groupService.clearEndedSessionMarker(activeGid);
        final localGroup = groupService.getLocalGroup(activeGid) ?? activeGroup;
        if (localGroup != null) {
          final updated = localGroup.copyWith(activeSession: liveSession);
          await groupService.saveLocalGroup(updated);
          groupService.notifyGroupChanged(activeGid, updated);
        }
      }

      // UPDATE 2D: Klaim sesi dan tulis event dalam satu transaksi sebelum konfirmasi dipasang
      bool claimedSuccessfully = true;
      final targetGroup = activeGroup ??
          (activeGid != null ? groupService.getLocalGroup(activeGid) : null);
      if (targetGroup != null) {
        try {
          final gameService = ref.read(groupGameServiceProvider);
          final claimResult = await gameService.claimSessionAndWriteResult(
            gid: targetGroup.id,
            game: 'wheel',
            amount: won,
            customSessionId: effectiveSessionId,
            detail: {
              'slot_index': winningIndex,
              'amount': won,
            },
          );
          if (!claimResult.success) {
            claimedSuccessfully = false;
            if (mounted) {
              InAppToast.show(
                context,
                message: claimResult.message,
              );
            }
          }
        } catch (_) {}
      }

      if (claimedSuccessfully && mounted) {
        showStickerSnackbar(
          context,
          message: 'Budget grup dipasang: $formattedBudget! Klik "Catat Belanja" untuk mulai.',
        );
      }
    }
  }

  void _showPlayBlockedFeedback(PlayPermissionResult perm) {
    SoundService.instance.play(Sfx.notifWarning);
    HapticFeedback.lightImpact();
    InAppToast.show(
      context,
      message: perm.message.isNotEmpty
          ? perm.message
          : 'Hanya pemilik yang bisa memutar',
    );
  }

  void _showNonOwnerBlockedFeedback(String? ownerName, {bool isFixed = false}) {
    SoundService.instance.play(Sfx.notifWarning);
    HapticFeedback.lightImpact();
    InAppToast.show(
      context,
      message: 'Hanya pemilik yang bisa memutar',
    );
  }

  void _spinWheel({
    required bool canSpin,
    required String ownerName,
    bool isFunSpin = false,
    PlayPermissionResult? playPerm,
  }) {
    if (!canSpin) {
      _showPlayBlockedFeedback(playPerm ??
          const PlayPermissionResult(
            allowed: false,
            deniedReason: PlayDenied.notOwner,
            message: 'Hanya pemilik yang bisa memutar',
          ));
      return;
    }

    if (_isSpinning) return;

    // F2: Validasi satu putaran pada satu waktu (jika ada siaran yang sedang berjalan)
    final activeGid = ref.read(groupServiceProvider).getActiveGroupId();
    if (activeGid != null) {
      final currentLive = ref.read(groupServiceProvider).getLocalLivePlay(activeGid);
      final clockSync = ref.read(clockSyncServiceProvider);
      if (currentLive != null && !currentLive.isCompleted(clockSync.serverNowMs)) {
        InAppToast.show(
          context,
          message: 'Putaran sedang berlangsung, mohon tunggu sebentar',
        );
        return;
      }
    }

    setState(() {
      _isSpinning = true;
      _isFunSpin = isFunSpin;
      _isSpectatorMode = false;
      _spectatorActorName = null;
    });

    final secureRandom = math.Random.secure();
    final totalSlots = _currentSlots.length;
    final segAngle = 360.0 / totalSlots;
    final randomTurns = 5 + secureRandom.nextInt(3);
    final winningIndex = secureRandom.nextInt(totalSlots);
    final wonAmount = _currentSlots[winningIndex];

    // Presisi 100%: Jarum lancip berhenti tepat tegak lurus di tengah irisan nominal yang menang
    final targetNormalizedAngle = ((360.0 - (winningIndex * segAngle + segAngle / 2.0)) % 360.0 + 360.0) % 360.0;

    final startNormalized = (_currentRotationAngle % 360.0 + 360.0) % 360.0;
    double forwardDelta = targetNormalizedAngle - startNormalized;
    while (forwardDelta <= 0) {
      forwardDelta += 360.0;
    }
    final targetAngle = _currentRotationAngle + (randomTurns * 360.0) + forwardDelta;

    _lastAngleForHaptic = _currentRotationAngle;

    final clockSync = ref.read(clockSyncServiceProvider);
    final serverNowMs = clockSync.serverNowMs;
    // Nol delay: Siaran dikirim seketika, animasi langsung berjalan lancar dan responsif
    final startAtMs = serverNowMs;
    const durationMs = 3800;
    final spinSessionId = 'sess_${serverNowMs}_${secureRandom.nextInt(9999)}';
    _currentSpinSessionId = spinSessionId;

    if (!isFunSpin && activeGid != null) {
      final authService = ref.read(groupAuthServiceProvider);
      final livePlay = LivePlayModel(
        spinId: spinSessionId,
        game: 'wheel',
        startAtMs: startAtMs,
        durationMs: durationMs,
        laps: randomTurns,
        resultIndex: winningIndex,
        finalAngle: targetAngle,
        amount: wonAmount,
        startedByUid: authService.currentUid ?? '',
        startedByName: authService.displayName ?? 'Pemilik',
        seed: secureRandom.nextInt(1000000),
        params: {
          'slots': _currentSlots,
        },
      );

      // Siarkan ke groups/{gid}/live/current dan Supabase Realtime
      ref.read(groupServiceProvider).broadcastLivePlay(activeGid, livePlay);
    }

    _spinController.duration = const Duration(milliseconds: durationMs);
    _spinAnimation = Tween<double>(
      begin: _currentRotationAngle,
      end: targetAngle,
    ).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: const Cubic(0.12, 0.7, 0.1, 1.0),
      ),
    );

    // Animasi putaran langsung dimulai seketika (0ms delay)
    SoundService.instance.play(Sfx.wheelSpin);
    HapticFeedback.mediumImpact();
    _spinController.forward(from: 0.0);
  }

  void _onPanStart(DragStartDetails details, Offset wheelCenter, {required bool canSpin, required String ownerName}) {
    if (!canSpin) {
      _showNonOwnerBlockedFeedback(ownerName);
      return;
    }
    if (_isSpinning) return;
    final touchPos = details.localPosition;
    _panStartAngle = math.atan2(touchPos.dy - wheelCenter.dy, touchPos.dx - wheelCenter.dx) * (180 / math.pi);
    _panCurrentAngle = _currentRotationAngle;
  }

  void _onPanUpdate(DragUpdateDetails details, Offset wheelCenter, {required bool canSpin}) {
    if (!canSpin || _isSpinning) return;
    final touchPos = details.localPosition;
    final currentTouchAngle = math.atan2(touchPos.dy - wheelCenter.dy, touchPos.dx - wheelCenter.dx) * (180 / math.pi);
    final delta = currentTouchAngle - _panStartAngle;
    final newAngle = _panCurrentAngle + delta;

    final crossed = WheelMath.hasCrossedSliceBoundary(
      previousAngle: _lastAngleForHaptic,
      currentAngle: newAngle,
      totalSlots: _currentSlots.length,
    );
    if (crossed) {
      _lastAngleForHaptic = newAngle;
      SoundService.instance.play(Sfx.wheelTick1);
      HapticFeedback.selectionClick();
    }

    setState(() {
      _currentRotationAngle = newAngle;
    });
  }

  void _onPanEnd(DragEndDetails details, {required bool canSpin}) {
    if (!canSpin || _isSpinning) return;
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;

    if (speed > 400) {
      _spinWheel(canSpin: true, ownerName: '');
    } else {
      SoundService.instance.play(Sfx.wheelLand);
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24 && now.day == dt.day) {
      return '${difference.inHours} jam lalu';
    } else {
      return 'Kemarin';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final activeGroupId = ref.watch(activeGroupIdProvider);
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final notesAsync = ref.watch(activeGroupNotesStreamProvider);
    final unreadCount = ref.watch(unreadActivityCountProvider);

    final streamedGroup = activeGroupAsync.valueOrNull;
    final localGroup = (activeGroupId != null && activeGroupId.isNotEmpty)
        ? ref.read(groupServiceProvider).getLocalGroup(activeGroupId)
        : null;
    final resolvedSession = (activeGroupId != null && activeGroupId.isNotEmpty)
        ? ref.read(groupServiceProvider).resolveEffectiveSession(
              activeGroupId,
              streamedGroup?.activeSession,
              localGroup?.activeSession,
            )
        : (streamedGroup?.activeSession ?? localGroup?.activeSession);
    final rawGroup = (streamedGroup != null || localGroup != null)
        ? (streamedGroup ?? localGroup)!.copyWith(
            activeSession: resolvedSession,
            clearActiveSession: resolvedSession == null,
          )
        : null;

    if (rawGroup == null) {
      if (activeGroupId != null && activeGroupId.isNotEmpty) {
        return Scaffold(
          backgroundColor: t.bg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(color: t.ink, strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Menghubungkan ke grup...',
                  style: t.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return _buildNoGroupScaffold(t);
    }
    final group = rawGroup;
    _syncSlotsIfNeeded(group.getWheelPool());

    final members = membersAsync.valueOrNull ?? [];
    final notes = notesAsync.valueOrNull ?? [];

    final authService = ref.watch(groupAuthServiceProvider);
    final myUid = authService.currentUid ?? '';
    // Aturan F1: isOwner = group.ownerUid == uid. Tidak ada sumber lain.
    final isOwner = group.ownerUid == myUid;
    final playPerm = evaluateCanPlay(group: group, session: group.activeSession, uid: myUid);
    final canSpin = playPerm.allowed;
    final isLocked = group.isSessionLocked;
    final hasBudget = group.activeSession != null &&
        group.activeSession!.sessionId.isNotEmpty &&
        group.activeSession!.budget > 0;
    final isFixed = group.budgetMode == 'fixed';

    // Keamanan: Jika user bukan pemilik dan bukan lagi anggota dalam daftar grup ini,
    // langsung bersihkan akses grup dan tampilkan antarmuka tanpa grup.
    final myName = authService.displayName?.toLowerCase().trim();
    final isCurrentUserMember = members.any((m) =>
        authService.isCurrentUser(m.uid) ||
        (myName != null && myName.isNotEmpty && m.name.toLowerCase().trim() == myName));
    if (myUid.isNotEmpty && !isOwner && members.isNotEmpty && !isCurrentUserMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(groupServiceProvider).setActiveGroupId(null);
        ref.read(activeGroupIdProvider.notifier).state = null;
        ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
        final rootCtx = rootNavigatorKey.currentContext ?? context;
        try {
          Navigator.of(rootCtx, rootNavigator: true).popUntil((route) => route.isFirst);
          GoRouter.of(rootCtx).go('/');
        } catch (_) {}
        GroupImportantDialog.showKickedFromGroup(
          rootCtx,
          groupName: group.name,
        );
      });
      return _buildNoGroupScaffold(t);
    }

    final ownerMember = members.firstWhere(
      (m) => m.isOwner,
      orElse: () => GroupMemberModel(
        uid: group.ownerUid,
        name: 'Pemilik Grup',
        colorIndex: 0,
        role: 'owner',
        joinedAt: group.createdAt,
        lastReadAt: group.createdAt,
      ),
    );
    final ownerName = ownerMember.name;

    // Gunakan sesi live lokal yang baru saja selesai berputar (0ms) jika ada, atau sinkronkan dengan database
    if (_localLiveSession != null &&
        (group.activeSession?.sessionId == _localLiveSession!.sessionId ||
            ref.read(groupServiceProvider).isSessionEnded(group.id, _localLiveSession))) {
      _localLiveSession = null;
    }
    final session = _localLiveSession ?? group.activeSession;
    if (session != null) {
      final winningIndex = _currentSlots.indexOf(session.budget);
      final double targetAngle;
      if (winningIndex != -1) {
        final segAngle = 360.0 / _currentSlots.length;
        targetAngle = ((360.0 - (winningIndex * segAngle + segAngle / 2.0)) % 360.0 + 360.0) % 360.0;
      } else {
        targetAngle = 0.0;
      }

      if (_lastSessionId == null) {
        // Pengguna baru membuka halaman atau kembali dari tab lain (misal: 'Catatan'):
        // Langsung arahkan jarum roda tepat ke nominal budget sesi aktif
        _lastSessionId = session.sessionId;
        if (!_isSpinning) {
          _currentRotationAngle = targetAngle;
        }
      } else if (_lastSessionId != session.sessionId) {
        _lastSessionId = session.sessionId;
        if (session.startedByUid != myUid && !_isSpinning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _currentRotationAngle = targetAngle;
            });
          });
        }
      }
    } else {
      _lastSessionId = null;
    }

    // Hitung sisa budget grup
    final activeNotes = notes.where((n) => !n.deleted).toList();
    final remainingBudget = session != null
        ? GroupModel.calculateRemainingBudget(
            sessionBudget: session.budget,
            sessionId: session.sessionId,
            notes: activeNotes,
          )
        : 0;

    final progress = (session != null && session.budget > 0)
        ? (remainingBudget / session.budget).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header: Tombol Kembali + Judul + Tombol Lonceng Aktivitas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Kembali ke Pilihan Permainan',
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        ref.read(appScopeProvider.notifier).state = AppScope.grup;
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.ink, width: 2.8),
                          boxShadow: [
                            BoxShadow(
                              color: t.ink,
                              offset: t.miniShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: CustomPaint(
                          size: const Size(18, 18),
                          painter: CustomBackIconPainter(
                            color: t.ink,
                            strokeWidth: 2.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Putar Jajan',
                      style: t.displayMedium.copyWith(
                        fontSize: 22,
                        color: t.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Lonceng Aktivitas dengan Badge Belum Dibaca
                  Semantics(
                    button: true,
                    label: 'Aktivitas grup, $unreadCount baru',
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
                              shape: BoxShape.circle,
                              border: Border.all(color: t.ink, width: 2.8),
                              boxShadow: [
                                BoxShadow(
                                  color: t.ink,
                                  offset: t.smallShadowOffset,
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(20, 20),
                              painter: CustomBellPainter(color: t.ink, strokeWidth: 2.8),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                height: 20,
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(
                                  color: t.danger,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: t.ink, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$unreadCount',
                                  style: t.buttonSmall.copyWith(
                                    fontSize: 11,
                                    color: t.surface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. ScopeSwitcher (Pribadi vs Grup)
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ScopeSwitcher(
                    currentScope: AppScope.grup,
                    onScopeChanged: (newScope) {
                      ref.read(appScopeProvider.notifier).state = newScope;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Presence Bar (Avatar Anggota & "N anggota online")
              _buildPresenceBar(t, members, group.id),
              const SizedBox(height: 12),
              if (t.wheelDecor == PutarWheelDecor.ears)
                const SizedBox(height: 18),

              // 4. Roda Putar Interaktif
              _buildInteractiveWheel(
                t,
                canSpin: canSpin && !isLocked,
                isOwner: isOwner,
                ownerName: ownerName,
                isFixed: isFixed,
                fixedBudget: group.fixedBudget,
                group: group,
                sessionActive: session != null,
              ),
              const SizedBox(height: 16),

              // 5. Kartu Putaran Terakhir
              _buildLastSpinCard(t, group, session),
              const SizedBox(height: 14),

              // 6. Bar Sisa Budget Grup
              if (session != null) ...[
                _buildBudgetSummaryBar(
                  t,
                  remainingBudget: remainingBudget,
                  sessionBudget: session.budget,
                  progress: progress,
                ),
                const SizedBox(height: 16),
              ],

              // 7. Tombol Putar Roda / Mulai Date & Pengaturan Neo-Brutalist
              if (isFixed) ...[
                // Mode Angka Tetap
                if (canSpin) ...[
                  if (session == null) ...[
                    StickerButton.large(
                      text: 'MULAI DATE (${RupiahFormatter.formatCompact(group.fixedBudget)})',
                      backgroundColor: t.danger,
                      textColor: t.ink,
                      onPressed: () async {
                        SoundService.instance.play(Sfx.wheelLand);
                        HapticFeedback.heavyImpact();
                        await ref.read(groupServiceProvider).startFixedSession(
                              gid: group.id,
                              fixedBudget: group.fixedBudget,
                            );
                        if (context.mounted) {
                          showStickerSnackbar(
                            context,
                            message: 'Date baru dimulai dengan budget ${RupiahFormatter.format(group.fixedBudget)}!',
                          );
                        }
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: StickerButton.large(
                            text: 'MULAI DATE BARU',
                            backgroundColor: t.surface,
                            textColor: t.ink,
                            borderColor: t.ink,
                            onPressed: () async {
                              SoundService.instance.play(Sfx.wheelLand);
                              HapticFeedback.heavyImpact();
                              await ref.read(groupServiceProvider).startFixedSession(
                                    gid: group.id,
                                    fixedBudget: group.fixedBudget,
                                  );
                              if (context.mounted) {
                                showStickerSnackbar(
                                  context,
                                  message: 'Date baru dimulai dengan budget ${RupiahFormatter.format(group.fixedBudget)}!',
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StickerButton.large(
                            text: 'CATAT JAJAN',
                            backgroundColor: t.danger,
                            textColor: t.ink,
                            onPressed: () {
                              SoundService.instance.play(Sfx.uiTap);
                              ref.read(appScopeProvider.notifier).state = AppScope.grup;
                              ref.read(activeGroupIdProvider.notifier).state = group.id;
                              context.go('/catatan?openAdd=true');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  StickerButton.large(
                    text: 'MENUNGGU PEMILIK MEMULAI DATE',
                    backgroundColor: t.surface,
                    textColor: t.ink,
                    borderColor: t.ink,
                    onPressed: () => _showNonOwnerBlockedFeedback(ownerName, isFixed: true),
                  ),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    context.push('/group/budget-settings/${group.id}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.ink, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: t.ink,
                          offset: const Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(16, 16),
                          painter: CustomGearPainter(color: t.ink),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pengaturan Budget Grup',
                            style: t.buttonSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.accentMint,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: t.ink, width: 1.5),
                          ),
                          child: Text(
                            'Angka Tetap',
                            style: t.buttonSmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (isOwner && hasBudget) ...[
                // Aturan F1: Pemilik SELALU boleh memutar atau mengulang, kapan pun.
                // Saat sesi sudah punya budget, tombol pemilik berbunyi "Ulangi budget" dan meminta konfirmasi.
                StickerButton.large(
                  text: _isSpinning ? 'MEMUTAR...' : 'ULANGI BUDGET',
                  backgroundColor: t.danger,
                  textColor: t.ink,
                  onPressed: _isSpinning
                      ? null
                      : () async {
                          final session = group.activeSession;
                          final startedByName = session?.startedByName ?? 'anggota';
                          final currentBudget = session?.budget ?? 0;
                          final confirm = await GroupImportantDialog.showConfirmRerunBudget(
                            context,
                            startedByName: startedByName,
                            budget: currentBudget,
                          );
                          if (confirm == true) {
                            _spinWheel(canSpin: true, ownerName: ownerName);
                          }
                        },
                ),
                const SizedBox(height: 10),
                StickerButton.large(
                  text: 'AKHIRI DATE GRUP',
                  backgroundColor: t.secondary,
                  textColor: t.ink,
                  borderColor: t.ink,
                  onPressed: () => _confirmEndSession(group),
                ),
              ] else if (canSpin) ...[
                // Mode Dari Permainan (bisa memutar roda)
                StickerButton.large(
                  text: _isSpinning ? 'MEMUTAR...' : 'PUTAR RODA',
                  backgroundColor: t.danger,
                  textColor: t.ink,
                  onPressed: _isSpinning ? null : () => _spinWheel(canSpin: true, ownerName: ownerName),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _isSpinning
                      ? null
                      : () {
                          SoundService.instance.play(Sfx.uiTap);
                          context.push('/group/budget-settings/${group.id}');
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.ink, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: t.ink,
                          offset: const Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(16, 16),
                          painter: CustomGearPainter(color: t.ink),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Atur Nominal Roda Grup',
                            style: t.buttonSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.secondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: t.ink, width: 1.5),
                          ),
                          child: Text(
                            '${group.getWheelPool().length} Pilihan',
                            style: t.buttonSmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (playPerm.deniedReason == PlayDenied.sessionLocked) ...[
                // Anggota: Sesi Terkunci (Date berjalan)
                StickerButton.large(
                  text: 'Date berjalan · permainan terkunci',
                  backgroundColor: t.surface,
                  textColor: t.ink,
                  borderColor: t.ink,
                  onPressed: () {
                    InAppToast.show(
                      context,
                      message: playPerm.message,
                    );
                  },
                ),
              ] else ...[
                // Anggota: Bukan Pemilik (playPolicy == 'owner')
                StickerButton.large(
                  text: 'Hanya pemilik yang bisa memutar',
                  backgroundColor: t.surface,
                  textColor: t.ink,
                  borderColor: t.ink,
                  onPressed: () {
                    InAppToast.show(
                      context,
                      message: 'Hanya pemilik yang bisa memutar',
                    );
                  },
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    context.push('/group/budget-settings/${group.id}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.ink, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: t.ink,
                          offset: const Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(16, 16),
                          painter: CustomGearPainter(color: t.ink),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Lihat Pengaturan Budget',
                            style: t.buttonSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (session != null) ...[
                const SizedBox(height: 12),
                StickerButton.large(
                  text: '+ CATAT BELANJA / JAJAN',
                  backgroundColor: t.accentMint,
                  textColor: t.ink,
                  onPressed: () {
                    ref.read(appScopeProvider.notifier).state = AppScope.grup;
                    context.go('/catatan');
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
      final sessionBeforeEnd = group.activeSession;
      if (mounted) {
        setState(() {
          _localLiveSession = null;
          _lastSessionId = null;
        });
      }
      if (summary.sessionId.isNotEmpty) {
        await groupService.markResultAsShown(group.id, summary.sessionId);
      }
      final frozen =
          await ref.read(groupGameServiceProvider).endSession(gid: group.id);
      if (mounted) {
        final budget = frozen?.budget ?? sessionBeforeEnd?.budget ?? 0;
        final totalSpent = frozen?.totalSpent ?? summary.totalSpent;
        final uri = buildGroupDateResultUri(
          groupName: group.name,
          budget: budget,
          totalSpent: totalSpent,
          itemCount: summary.itemCount,
          groupId: group.id,
          sessionId: frozen?.sessionId ?? summary.sessionId,
          budgetByName: frozen?.budgetByName ?? sessionBeforeEnd?.budgetByName,
          budgetGame: frozen?.game ?? sessionBeforeEnd?.game,
          endedByName: frozen?.endedByName,
          endedByUid: frozen?.endedByUid,
          sessionDate: frozen?.startedAt ?? sessionBeforeEnd?.startedAt,
          endedAt: frozen?.endedAt,
        );
        context.push(uri.toString());
      }
    }
  }

  Widget _buildPresenceBar(
    PutarTheme t,
    List<GroupMemberModel> members,
    String activeGid,
  ) {
    final now = DateTime.now();
    // Hitung anggota yang aktif (lastSeenAt < 15 menit atau jika null fallback ke member)
    final seen = <String>{};
    final onlineMembers = <GroupMemberModel>[];
    for (final m in members) {
      final cleanName = m.name.toLowerCase().trim();
      final isOnline = m.lastSeenAt == null || now.difference(m.lastSeenAt!).inMinutes < 15;
      if (isOnline && (m.isOwner || !seen.contains(cleanName))) {
        if (!m.isOwner) seen.add(cleanName);
        onlineMembers.add(m);
      }
    }

    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        context.push('/group/invite/$activeGid');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.ink, width: 2),
          boxShadow: [
            BoxShadow(
              color: t.ink,
              offset: t.miniShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            if (onlineMembers.isNotEmpty)
              SizedBox(
                height: 30,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < onlineMembers.length.clamp(0, 3); i++)
                      Align(
                        widthFactor: 0.72,
                        child: MemberAvatar(
                          name: onlineMembers[i].name,
                          colorIndex: onlineMembers[i].colorIndex,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${onlineMembers.length} anggota online',
                style: t.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.ink, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: CustomGearPainter(color: t.ink),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Kelola',
                    style: t.buttonSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFixedWheelInteraction(
    BuildContext context, {
    required bool isOwner,
    required GroupModel group,
    required String ownerName,
    required int fixedBudget,
    required bool sessionActive,
  }) {
    final t = context.putarTheme;
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.ink, width: t.borderWidth),
            boxShadow: [
              BoxShadow(
                color: t.ink,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.ink, width: 2),
                    ),
                    child: Text(
                      'Mode Angka Tetap',
                      style: t.buttonSmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
              const SizedBox(height: 14),
              Text(
                'Budget Date: ${RupiahFormatter.format(fixedBudget)}',
                style: t.titleMedium.copyWith(fontSize: 18, color: t.ink),
              ),
              const SizedBox(height: 8),
              Text(
                sessionActive
                    ? 'Date sedang aktif dengan budget tetap ${RupiahFormatter.format(fixedBudget)}. Roda ini tidak mengubah budget yang sudah ditentukan.'
                    : 'Pada Mode Angka Tetap, nominal budget date bernilai pasti ${RupiahFormatter.format(fixedBudget)} per sesi tanpa perlu diundi dari putaran roda.',
                style: t.bodyMedium.copyWith(fontSize: 13, color: t.ink),
              ),
              const SizedBox(height: 18),
              if (isOwner) ...[
                StickerButton.large(
                  text: 'UBAH KE MODE PUTAR RODA',
                  backgroundColor: t.danger,
                  textColor: t.ink,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(groupServiceProvider).updateGroupBudgetSettings(
                          gid: group.id,
                          budgetMode: 'game',
                          fixedBudget: group.fixedBudget,
                          spinPolicy: group.spinPolicy,
                          wheelSlots: group.wheelSlots,
                        );
                    if (context.mounted) {
                      showStickerSnackbar(
                        context,
                        message: 'Beralih ke Mode Dari Permainan! Sekarang kamu bisa putar roda.',
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
              StickerButton.large(
                text: 'PUTAR RODA ISENG (SERU-SERUAN)',
                backgroundColor: t.accentMint,
                textColor: t.ink,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _spinWheel(
                    canSpin: true,
                    ownerName: ownerName,
                    isFunSpin: true,
                  );
                },
              ),
              const SizedBox(height: 10),
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

  Widget _buildInteractiveWheel(
    PutarTheme t, {
    required bool canSpin,
    required bool isOwner,
    required String ownerName,
    required bool isFixed,
    required int fixedBudget,
    required GroupModel group,
    required bool sessionActive,
  }) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(230.0, constraints.maxWidth - 20);
          final wheelCenter = Offset(size / 2, size / 2);

          return Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (isFixed) {
                    _handleFixedWheelInteraction(
                      context,
                      isOwner: isOwner,
                      group: group,
                      ownerName: ownerName,
                      fixedBudget: fixedBudget,
                      sessionActive: sessionActive,
                    );
                  }
                },
                onPanStart: (d) {
                  if (isFixed) {
                    _handleFixedWheelInteraction(
                      context,
                      isOwner: isOwner,
                      group: group,
                      ownerName: ownerName,
                      fixedBudget: fixedBudget,
                      sessionActive: sessionActive,
                    );
                    return;
                  }
                  _onPanStart(d, wheelCenter, canSpin: canSpin, ownerName: ownerName);
                },
                onPanUpdate: (d) {
                  if (isFixed) return;
                  _onPanUpdate(d, wheelCenter, canSpin: canSpin);
                },
                onPanEnd: (d) {
                  if (isFixed) return;
                  _onPanEnd(d, canSpin: canSpin);
                },
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: WheelPainter(
                      slots: _currentSlots,
                      rotationAngleDegrees: _currentRotationAngle,
                      cachedTextPainters: _textPaintersCache,
                      pointerFlickAngleDegrees: WheelMath.calculatePointerFlickAngle(
                        currentAngle: _currentRotationAngle,
                        totalSlots: _currentSlots.length,
                      ),
                      theme: t,
                      paintHubMascot: t.mascot == null,
                      mochiExpression: _isSpinning
                          ? MochiExpression.wow
                          : MochiExpression.normal,
                    ),
                  ),
                ),
              ),
              if (t.mascot == PutarMascotKind.mochi)
                MochiWidget(
                  size: 52.0 * (size / 300.0),
                  expression: _isSpinning
                      ? MochiExpression.wow
                      : MochiExpression.normal,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLastSpinCard(
    PutarTheme t,
    GroupModel group,
    GroupSessionModel? session,
  ) {
    final isFixed = group.budgetMode == 'fixed';
    if (session == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.smallCardRadius),
          border: Border.all(color: t.ink, width: t.subtleBorderWidth),
          boxShadow: [
            BoxShadow(
              color: t.ink,
              offset: t.smallShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isFixed ? t.accentMint : t.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: t.ink, width: 2),
              ),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(18, 18),
                painter: CustomSyncArrowsPainter(color: t.ink, strokeWidth: 2.2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFixed ? 'Belum ada date yang dimulai' : 'Belum ada putaran sesi',
                    style: t.bodyLargeBold.copyWith(fontSize: 14),
                  ),
                  Text(
                    isFixed
                        ? 'Mulai date untuk mengaktifkan batas jajan bersama!'
                        : 'Putar roda untuk menentukan batas jajan bersama!',
                    style: t.bodySmall.copyWith(
                      color: t.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        context.go('/catatan');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.smallCardRadius),
          border: Border.all(color: t.ink, width: t.subtleBorderWidth),
          boxShadow: [
            BoxShadow(
              color: t.ink,
              offset: t.smallShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            MemberAvatar(
              name: session.startedByName,
              colorIndex: 0,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFixed ? '${session.startedByName} memulai date' : '${session.startedByName} memutar roda',
                    style: t.bodyLargeBold.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_formatRelativeTime(session.startedAt)} · Buka catatan belanja →',
                    style: t.bodySmall.copyWith(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 95),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  RupiahFormatter.format(session.budget),
                  style: t.titleLarge.copyWith(
                    fontSize: 17,
                    color: t.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSummaryBar(
    PutarTheme t, {
    required int remainingBudget,
    required int sessionBudget,
    required double progress,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        context.go('/catatan');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sisa budget grup',
                  style: t.buttonSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${RupiahFormatter.format(remainingBudget)} / ${RupiahFormatter.format(sessionBudget)}',
                      style: t.buttonSmall.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress Bar
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.ink, width: t.subtleBorderWidth),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: progress > 0.35 ? t.accentMint : t.danger,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoGroupScaffold(PutarTheme t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top Bar: Tombol Kembali & ScopeSwitcher
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Kembali ke Pilihan Permainan',
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        ref.read(appScopeProvider.notifier).state = AppScope.grup;
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.ink, width: 2.8),
                          boxShadow: [
                            BoxShadow(
                              color: t.ink,
                              offset: t.miniShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: CustomPaint(
                          size: const Size(18, 18),
                          painter: CustomBackIconPainter(
                            color: t.ink,
                            strokeWidth: 2.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ScopeSwitcher(
                          currentScope: AppScope.grup,
                          onScopeChanged: (newScope) {
                            ref.read(appScopeProvider.notifier).state = newScope;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: t.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.ink, width: t.borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: t.ink,
                      offset: t.smallShadowOffset,
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: CustomPaint(
                  size: const Size(36, 36),
                  painter: CustomCrownPainter(color: t.ink, strokeWidth: 2.8),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum Bergabung Grup',
                style: t.titleMedium.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Buat grup atau gabung dengan kode undangan untuk memutar roda bersama teman-temanmu.',
                style: t.bodyMedium.copyWith(
                  color: t.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              StickerButton.large(
                text: 'BUAT ATAU GABUNG GRUP',
                backgroundColor: t.secondary,
                onPressed: () => context.push('/group/join-or-create'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

