import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';
import '../../utils/rupiah_formatter.dart';
import '../../utils/sound_service.dart';
import '../painters/group_icons_painter.dart';

/// Modal Dialog Penting Neo-Brutalist sesuai Notif3.dc.html
/// - Animasi sc: scale(0.8) -> scale(1.04) -> scale(1.0) dengan cubic-bezier(.2,1.3,.3,1)
/// - Animasi wg: ikon badge bergoyang -9deg -> +9deg -> -6deg -> 0deg
/// - Exit: scale(1.0 -> 0.96) dan fade out
class GroupImportantDialog {
  GroupImportantDialog._();

  static Future<T?> _show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    Duration duration = const Duration(milliseconds: 360),
    Color? barrierColor,
  }) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dialog Penting',
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
      useRootNavigator: true,
      transitionDuration:
          disableAnimations ? const Duration(milliseconds: 100) : duration,
      pageBuilder: (ctx, anim, secondaryAnim) => builder(ctx),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        if (disableAnimations) {
          return FadeTransition(opacity: anim, child: child);
        }
        final isReverse = anim.status == AnimationStatus.reverse;
        final double scale;
        final double opacity;

        if (isReverse) {
          // Exit: scale(1.0 -> 0.96), opacity(1.0 -> 0.0)
          // Sesuai CSS @keyframes sc: 96%,100%{transform:scale(.96);opacity:0}
          scale = Tween<double>(begin: 0.96, end: 1.0).evaluate(anim);
          opacity = anim.value.clamp(0.0, 1.0);
        } else {
          // Entrance: scale(0.8) -> scale(1.04) -> scale(1.0)
          // Sesuai CSS @keyframes sc: cubic-bezier(.2,1.3,.3,1)
          scale = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween<double>(begin: 0.8, end: 1.04)
                  .chain(CurveTween(curve: const Cubic(0.2, 1.3, 0.3, 1.0))),
              weight: 70,
            ),
            TweenSequenceItem(
              tween: Tween<double>(begin: 1.04, end: 1.0)
                  .chain(CurveTween(curve: Curves.easeOut)),
              weight: 30,
            ),
          ]).evaluate(anim);

          opacity = Tween<double>(begin: 0.0, end: 1.0).evaluate(
            CurvedAnimation(
              parent: anim,
              curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
            ),
          );
        }

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
    );
  }

  /// 1. Dialog Dikeluarkan dari Grup (Saat aplikasi dibuka / realtime)
  static Future<void> showKickedFromGroup(
    BuildContext context, {
    required String groupName,
    VoidCallback? onConfirm,
  }) async {
    SoundService.instance.play(Sfx.notifWarning);
    final t = context.putarTheme;
    await _show<void>(
      context,
      barrierDismissible: false,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.danger,
        badgeIcon: CustomUserMinusPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Kamu dikeluarkan dari grup',
        message:
            'Pemilik mengeluarkanmu dari $groupName. Catatan pribadimu tetap aman di HP ini.',
        actions: [
          _DialogButton(
            label: 'Mengerti',
            backgroundColor: t.secondary,
            onTap: () {
              Navigator.of(ctx).pop();
              onConfirm?.call();
            },
          ),
        ],
      ),
    );
  }

  /// 2. Dialog Grup Sudah Dihapus oleh Pemilik
  static Future<void> showGroupDeleted(
    BuildContext context, {
    required String groupName,
    VoidCallback? onConfirm,
  }) async {
    SoundService.instance.play(Sfx.notifWarning);
    final t = context.putarTheme;
    await _show<void>(
      context,
      barrierDismissible: false,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.danger,
        badgeIcon: CustomTrashPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Grup sudah dihapus',
        message:
            'Pemilik menghapus $groupName. Catatan grup tidak bisa dibuka lagi.',
        actions: [
          _DialogButton(
            label: 'Mengerti',
            backgroundColor: t.secondary,
            onTap: () {
              Navigator.of(ctx).pop();
              onConfirm?.call();
            },
          ),
        ],
      ),
    );
  }

  /// 3. Dialog Gagal Sinkron (Perubahan Belum Terkirim)
  static Future<bool?> showSyncFailed(
    BuildContext context, {
    required int unSyncedCount,
    required Future<void> Function() onRetry,
  }) async {
    SoundService.instance.play(Sfx.notifWarning);
    final t = context.putarTheme;
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.danger,
        badgeIcon: CustomCloudOfflinePainter(color: t.ink, strokeWidth: 2.6),
        title: '$unSyncedCount perubahan belum terkirim',
        message:
            'Tersimpan aman di HP ini. Coba kirim lagi, atau biarkan dan kami coba otomatis saat sinyal bagus.',
        actions: [
          _DialogButton(
            label: 'Nanti saja',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Coba lagi',
            backgroundColor: t.danger,
            onTap: () async {
              Navigator.of(ctx).pop(true);
              await onRetry();
            },
          ),
        ],
      ),
    );
  }

  /// 4. Dialog Konfirmasi Pemilik Mengeluarkan Anggota
  static Future<bool?> showConfirmKickMember(
    BuildContext context, {
    required String memberName,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final t = context.putarTheme;
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.secondary,
        badgeIcon: CustomUserMinusPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Keluarkan $memberName?',
        message:
            '$memberName tidak bisa lagi melihat catatan grup. Catatan yang sudah ia buat tetap ada.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Keluarkan',
            backgroundColor: t.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// 5. Dialog Konfirmasi Anggota Keluar Sendiri dari Grup
  static Future<bool?> showConfirmLeaveGroup(
    BuildContext context,
  ) async {
    SoundService.instance.play(Sfx.uiTap);
    final t = context.putarTheme;
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.danger,
        badgeIcon: CustomExitPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Keluar dari Grup?',
        message:
            'Kamu tidak akan lagi melihat aktivitas dan catatan bersama di grup ini.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Keluar',
            backgroundColor: t.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// 6. Dialog Konfirmasi Pemilik Mengganti Kode Undangan
  static Future<bool?> showConfirmRegenerateCode(
    BuildContext context, {
    required String oldCode,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final t = context.putarTheme;
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.secondary,
        badgeIcon: CustomSyncArrowsPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Ganti Kode Undangan?',
        message:
            'Kode lama ($oldCode) akan langsung tidak berlaku. Teman yang belum bergabung harus memakai kode baru.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Ganti Kode',
            backgroundColor: t.secondary,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// 7. Dialog Konfirmasi Hapus Catatan Pengeluaran Grup
  static Future<bool?> showConfirmDeleteNote(
    BuildContext context, {
    required String title,
    required String formattedAmount,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final t = context.putarTheme;
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.danger,
        badgeIcon: CustomTrashPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Hapus Catatan?',
        message:
            'Catatan "$title" sebesar $formattedAmount akan dihapus dari catatan grup.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Hapus',
            backgroundColor: t.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// 8. Dialog Konfirmasi Menyelesaikan Sesi Date Grup (Layar 67 - Hgrup3.dc.html)
  static Future<bool?> showConfirmEndGroupSession(
    BuildContext context, {
    required String groupName,
    int? budget,
    int? totalSpent,
    int? itemCount,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final t = context.putarTheme;
    final resolvedBudget = budget ?? 0;
    final resolvedSpent = totalSpent ?? 0;
    final hasBudgetPreview = resolvedBudget > 0;
    final isLolos = resolvedSpent <= resolvedBudget;
    final diff = (resolvedBudget - resolvedSpent).abs();
    final outcomePreview = hasBudgetPreview
        ? (isLolos
            ? ': Lolos, hemat ${RupiahFormatter.format(diff)}'
            : ': Lewat ${RupiahFormatter.format(diff)}')
        : '';

    return _show<bool>(
      context,
      barrierDismissible: true,
      duration: const Duration(milliseconds: 450),
      barrierColor: t.ink.withValues(alpha: 0.5),
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.success,
        badgeIcon: CustomFlagPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Selesaikan date ini?',
        extraContent: (budget != null || totalSpent != null || itemCount != null)
            ? Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (budget != null)
                      _SummaryMiniChip(
                        label: 'Budget ${RupiahFormatter.format(budget)}',
                        backgroundColor: t.surface,
                      ),
                    if (totalSpent != null)
                      _SummaryMiniChip(
                        label: 'Terpakai ${RupiahFormatter.format(totalSpent)}',
                        backgroundColor: t.secondary,
                      ),
                    if (itemCount != null)
                      _SummaryMiniChip(
                        label: '$itemCount catatan',
                        backgroundColor: t.surface,
                      ),
                  ],
                ),
              )
            : null,
        message:
            'Catatan date ini akan dibekukan dan semua anggota langsung melihat hasilnya$outcomePreview. Catatan yang dibuat offline sebelum sekarang tetap dihitung bila tersinkron dalam 24 jam.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Selesaikan',
            backgroundColor: t.success,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// Dialog Konfirmasi Pemilik Memutar Ulang / Mengganti Budget Sesi (F1)
  static Future<bool?> showConfirmRerunBudget(
    BuildContext context, {
    required String startedByName,
    required int budget,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final t = context.putarTheme;
    final name = startedByName.trim().isNotEmpty ? startedByName.trim() : 'anggota';
    final formattedBudget = 'Rp${budget.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.secondary,
        badgeIcon: CustomClockPainter(color: t.ink, strokeWidth: 2.6),
        title: 'Ulangi Budget?',
        message: 'Hasil $name $formattedBudget akan diganti.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Ulangi budget',
            backgroundColor: t.danger,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// Dialog Konfirmasi Persetujuan Hasil Permainan Grup saat Catatan Grup sudah memiliki budget aktif
  static Future<bool?> showConfirmAcceptGameBudget(
    BuildContext context, {
    required int budget,
    int? currentBudget,
    String gameName = 'Permainan',
  }) async {
    SoundService.instance.play(Sfx.winLolos);
    final t = context.putarTheme;
    String fmt(int v) =>
        'Rp${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    final formattedBudget = fmt(budget);
    final hasExisting = currentBudget != null && currentBudget > 0;
    final title = hasExisting
        ? 'Ganti Budget ke $formattedBudget?'
        : 'Setuju Budget $formattedBudget?';
    final message = hasExisting
        ? 'Catatan grup saat ini sudah memiliki budget ${fmt(currentBudget)}. Setuju menggantinya dengan hasil $gameName sebesar $formattedBudget? Jika tidak, catatan grup sebelumnya tetap dipertahankan.'
        : '$gameName menghasilkan $formattedBudget. Setuju memasang budget ini di Catatan Grup? Jika tidak, catatan grup tetap 0.';
    return _show<bool>(
      context,
      barrierDismissible: false,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: t.secondary,
        badgeIcon: CustomCheckPainter(color: t.ink, strokeWidth: 2.8),
        title: title,
        message: message,
        actions: [
          _DialogButton(
            label: 'Tidak',
            backgroundColor: t.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Setuju',
            backgroundColor: t.success,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// Dialog Konfirmasi Persetujuan Hasil Putaran Roda Grup
  static Future<bool?> showConfirmAcceptWheelBudget(
    BuildContext context, {
    required int budget,
    int? currentBudget,
  }) {
    return showConfirmAcceptGameBudget(
      context,
      budget: budget,
      currentBudget: currentBudget,
      gameName: 'Roda Putar',
    );
  }
}

class _BaseImportantDialog extends StatelessWidget {
  final Color badgeColor;
  final CustomPainter badgeIcon;
  final String title;
  final Widget? extraContent;
  final String message;
  final List<Widget> actions;

  const _BaseImportantDialog({
    required this.badgeColor,
    required this.badgeIcon,
    required this.title,
    this.extraContent,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.ink, width: t.borderWidth),
          boxShadow: [
            BoxShadow(
              color: t.ink,
              offset: t.heroShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _WiggleBadge(
                    badgeColor: badgeColor,
                    badgeIcon: badgeIcon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: t.titleMedium.copyWith(
                        fontSize: 18,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ?extraContent,
              Text(
                message,
                style: t.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: t.weightMedium,
                  color: t.ink,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: actions
                    .map((act) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: act,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMiniChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const _SummaryMiniChip({
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(t.chipRadius),
        border: Border.all(color: t.ink, width: 2),
      ),
      child: Text(
        label,
        style: t.bodySmall.copyWith(
          fontSize: 11,
          fontWeight: t.weightExtraBold,
          color: t.ink,
        ),
      ),
    );
  }
}

/// Ikon Bulat dengan Animasi Goyang (Wiggle wg) sesuai Notif3.dc.html
/// @keyframes wg: 0% -> 13% (-9deg) -> 16% (9deg) -> 19% (-6deg) -> 22% (0deg)
class _WiggleBadge extends StatefulWidget {
  final Color badgeColor;
  final CustomPainter badgeIcon;

  const _WiggleBadge({
    required this.badgeColor,
    required this.badgeIcon,
  });

  @override
  State<_WiggleBadge> createState() => _WiggleBadgeState();
}

class _WiggleBadgeState extends State<_WiggleBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    const deg2rad = math.pi / 180.0;
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -9.0 * deg2rad)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -9.0 * deg2rad, end: 9.0 * deg2rad)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 9.0 * deg2rad, end: -6.0 * deg2rad)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -6.0 * deg2rad, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    // Wiggle pertama kali segera setelah dialog muncul
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });

    // Ulangi goyang setiap 4 detik saat dialog masih terbuka
    _repeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: widget.badgeColor,
          shape: BoxShape.circle,
          border: Border.all(color: t.ink, width: t.borderWidth),
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: const Size(19, 19),
          painter: widget.badgeIcon,
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        onTap();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.ink, width: t.borderWidth),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: t.buttonSmall.copyWith(
            fontSize: 13,
            fontWeight: t.weightExtraBold,
            color: t.ink,
          ),
        ),
      ),
    );
  }
}


