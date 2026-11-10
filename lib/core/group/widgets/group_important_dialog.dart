import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
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
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dialog Penting',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      useRootNavigator: true,
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, anim, secondaryAnim) => builder(ctx),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
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
    await _show<void>(
      context,
      barrierDismissible: false,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.tomat,
        badgeIcon: const CustomUserMinusPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Kamu dikeluarkan dari grup',
        message:
            'Pemilik mengeluarkanmu dari $groupName. Catatan pribadimu tetap aman di HP ini.',
        actions: [
          _DialogButton(
            label: 'Mengerti',
            backgroundColor: AppColors.matahari,
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
    await _show<void>(
      context,
      barrierDismissible: false,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.tomat,
        badgeIcon: const CustomTrashPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Grup sudah dihapus',
        message:
            'Pemilik menghapus $groupName. Catatan grup tidak bisa dibuka lagi.',
        actions: [
          _DialogButton(
            label: 'Mengerti',
            backgroundColor: AppColors.matahari,
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
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.tomat,
        badgeIcon: const CustomCloudOfflinePainter(color: AppColors.ink, strokeWidth: 2.6),
        title: '$unSyncedCount perubahan belum terkirim',
        message:
            'Tersimpan aman di HP ini. Coba kirim lagi, atau biarkan dan kami coba otomatis saat sinyal bagus.',
        actions: [
          _DialogButton(
            label: 'Nanti saja',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Coba lagi',
            backgroundColor: AppColors.tomat,
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
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.matahari,
        badgeIcon: const CustomUserMinusPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Keluarkan $memberName?',
        message:
            '$memberName tidak bisa lagi melihat catatan grup. Catatan yang sudah ia buat tetap ada.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Keluarkan',
            backgroundColor: AppColors.tomat,
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
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.tomat,
        badgeIcon: const CustomExitPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Keluar dari Grup?',
        message:
            'Kamu tidak akan lagi melihat aktivitas dan catatan bersama di grup ini.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Keluar',
            backgroundColor: AppColors.tomat,
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
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.matahari,
        badgeIcon: const CustomSyncArrowsPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Ganti Kode Undangan?',
        message:
            'Kode lama ($oldCode) akan langsung tidak berlaku. Teman yang belum bergabung harus memakai kode baru.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Ganti Kode',
            backgroundColor: AppColors.matahari,
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
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.tomat,
        badgeIcon: const CustomTrashPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Hapus Catatan?',
        message:
            'Catatan "$title" sebesar $formattedAmount akan dihapus dari catatan grup.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Hapus',
            backgroundColor: AppColors.tomat,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  /// 8. Dialog Konfirmasi Mengakhiri Sesi Date Grup (Membuka kembali permainan)
  static Future<bool?> showConfirmEndGroupSession(
    BuildContext context, {
    required String groupName,
    int? budget,
  }) async {
    SoundService.instance.play(Sfx.uiTap);
    final budgetText = budget != null && budget > 0
        ? ' (Budget: Rp${budget.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')})'
        : '';
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.matahari,
        badgeIcon: const CustomClockPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Akhiri Date Grup?',
        message:
            'Sesi date grup$budgetText akan diselesaikan. Semua anggota bisa kembali bermain atau memutar roda date.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Akhiri Date',
            backgroundColor: AppColors.matahari,
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
    final name = startedByName.trim().isNotEmpty ? startedByName.trim() : 'anggota';
    final formattedBudget = 'Rp${budget.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    return _show<bool>(
      context,
      barrierDismissible: true,
      builder: (ctx) => _BaseImportantDialog(
        badgeColor: AppColors.matahari,
        badgeIcon: const CustomClockPainter(color: AppColors.ink, strokeWidth: 2.6),
        title: 'Ulangi Budget?',
        message: 'Hasil $name $formattedBudget akan diganti.',
        actions: [
          _DialogButton(
            label: 'Batal',
            backgroundColor: AppColors.surface,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          _DialogButton(
            label: 'Ulangi budget',
            backgroundColor: AppColors.tomat,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }
}

class _BaseImportantDialog extends StatelessWidget {
  final Color badgeColor;
  final CustomPainter badgeIcon;
  final String title;
  final String message;
  final List<Widget> actions;

  const _BaseImportantDialog({
    required this.badgeColor,
    required this.badgeIcon,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.ink, width: 3.0),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
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
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
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
          border: Border.all(color: AppColors.ink, width: 3.0),
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
          border: Border.all(color: AppColors.ink, width: 3.0),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.buttonSmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}


