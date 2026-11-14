import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/putar_theme.dart';
import '../../utils/sound_service.dart';
import '../painters/group_icons_painter.dart';
import '../services/group_service.dart';

/// Tombol lonceng notifikasi/aktivitas grup beserta badge angka belum dibaca.
class GroupActivityBellButton extends ConsumerWidget {
  final int? unreadCountOverride;
  final VoidCallback? onTap;

  const GroupActivityBellButton({
    super.key,
    this.unreadCountOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.putarTheme;
    final int unreadCount =
        unreadCountOverride ?? ref.watch(unreadActivityCountProvider);
    final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';

    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Aktivitas grup, $unreadCount baru'
          : 'Aktivitas grup',
      child: GestureDetector(
        onTap: onTap ??
            () {
              SoundService.instance.play(Sfx.uiTap);
              context.push('/group/activity');
            },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.ink, width: t.subtleBorderWidth),
            boxShadow: [
              BoxShadow(
                color: t.ink,
                offset: t.miniShadowOffset,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(
                    painter: CustomBellPainter(
                      color: t.ink,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.danger,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: t.ink, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        badgeText,
                        style: t.buttonSmall.copyWith(
                          fontSize: 11,
                          color: t.surface,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
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

