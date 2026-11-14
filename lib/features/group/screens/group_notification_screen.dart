import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/services/group_notification_settings_service.dart';
import '../../../core/group/widgets/setting_toggle.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../features/notifications/notification_service.dart';

/// Layar 44: Pengaturan Notifikasi Grup (Grup7.dc.html)
class GroupNotificationScreen extends ConsumerWidget {
  const GroupNotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.putarTheme;
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final group = activeGroupAsync.valueOrNull;
    final gid = group?.id ?? ref.read(groupServiceProvider).getActiveGroupId() ?? 'default_group';
    final groupName = group?.name ?? 'Date Jumat';

    final settings = ref.watch(groupNotificationSettingsProvider(gid));
    final notifier = ref.read(groupNotificationSettingsProvider(gid).notifier);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Tombol Kembali 46x46 + Judul 23px + Nama Grup
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Kembali',
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/group/activity');
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
                        child: CustomPaint(
                          size: const Size(20, 20),
                          painter: CustomBackIconPainter(
                            color: t.ink,
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifikasi grup',
                          style: t.displayMedium.copyWith(
                            fontSize: 23,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          groupName,
                          style: t.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: t.weightSemiBold,
                            color: t.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KARTU 1: Bisukan Grup
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bisukan grup',
                                style: t.titleMedium.copyWith(
                                  fontSize: 17,
                                  fontWeight: t.weightExtraBold,
                                  color: t.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Matikan semua notifikasi grup ini sementara',
                                style: t.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: t.weightMedium,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SettingToggle(
                          value: settings.isCurrentlyMuted,
                          label: 'Bisukan grup',
                          onChanged: (val) {
                            notifier.setMuted(val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Bisukan selama',
                      style: t.buttonSmall.copyWith(
                        fontSize: 12,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDurationChip(
                          t: t,
                          label: '1 jam',
                          isSelected: settings.isCurrentlyMuted && settings.muteDuration == '1_jam',
                          onTap: () => notifier.setMuteDuration('1_jam'),
                        ),
                        _buildDurationChip(
                          t: t,
                          label: '8 jam',
                          isSelected: settings.isCurrentlyMuted && settings.muteDuration == '8_jam',
                          onTap: () => notifier.setMuteDuration('8_jam'),
                        ),
                        _buildDurationChip(
                          t: t,
                          label: 'Sampai kunyalakan',
                          isSelected: settings.isCurrentlyMuted && settings.muteDuration == 'sampai_kunyalakan',
                          onTap: () => notifier.setMuteDuration('sampai_kunyalakan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // KARTU 2: Jenis Notifikasi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Jenis notifikasi',
                      style: t.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 1. Catatan Pengeluaran
                    _buildSwitchRow(
                      t: t,
                      title: 'Catatan pengeluaran',
                      subtitle: 'Saat anggota lain mencatat jajan',
                      value: settings.notifyExpenses,
                      onChanged: (val) => notifier.toggleExpenses(val),
                      showDivider: true,
                    ),

                    // 2. Hasil Putaran Roda
                    _buildSwitchRow(
                      t: t,
                      title: 'Hasil putaran roda',
                      subtitle: 'Saat anggota lain memutar roda',
                      value: settings.notifySpin,
                      onChanged: (val) => notifier.toggleSpin(val),
                      showDivider: true,
                    ),

                    // 3. Peringatan Budget
                    _buildSwitchRow(
                      t: t,
                      title: 'Peringatan budget',
                      subtitle: 'Saat sisa tinggal 20% atau budget terlewati',
                      value: settings.notifyWarning80,
                      onChanged: (val) => notifier.toggleWarning80(val),
                      showDivider: true,
                    ),

                    // 4. Hasil Date Selesai
                    _buildSwitchRow(
                      t: t,
                      title: 'Hasil date selesai',
                      subtitle: 'Saat date grup selesai: Lolos atau Lewat',
                      value: settings.notifyDateComplete,
                      onChanged: (val) => notifier.toggleDateComplete(val),
                      showDivider: true,
                    ),

                    // 5. Anggota Masuk atau Keluar
                    _buildSwitchRow(
                      t: t,
                      title: 'Anggota masuk atau keluar',
                      subtitle: 'Saat ada yang bergabung atau pergi',
                      value: settings.notifyMembers,
                      onChanged: (val) => notifier.toggleMembers(val),
                      showDivider: false,
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Selalu tampil: dikeluarkan dari grup, grup dihapus, gagal sinkron.',
                      style: t.bodySmall.copyWith(
                        fontSize: 11.5,
                        fontWeight: t.weightSemiBold,
                        color: t.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // KARTU 3: Suara dan Getar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suara dan getar',
                      style: t.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diatur di pengaturan Android untuk channel "Aktivitas grup". Jika dimatikan di sana, sakelar di atas tidak berpengaruh.',
                      style: t.bodySmall.copyWith(
                        fontSize: 12,
                        fontWeight: t.weightMedium,
                        color: t.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        SoundService.instance.play(Sfx.uiTap);
                        final granted = await NotificationService.instance.requestNotificationPermission(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: t.surface,
                              content: Text(
                                granted
                                    ? 'Notifikasi channel "Aktivitas grup" aktif.'
                                    : 'Silakan aktifkan notifikasi di Pengaturan Android > Aplikasi > Putar Jajan.',
                                style: TextStyle(color: t.ink, fontWeight: t.weightBold),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.accentPurple,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: t.ink, width: t.borderWidth),
                        ),
                        child: Text(
                          'Buka pengaturan Android',
                          style: t.buttonSmall.copyWith(
                            fontSize: 13,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Footer Keterangan
              Text(
                'Aktivitas dalam 1 menit digabung jadi satu notifikasi. Kamu tidak menerima notifikasi untuk aksimu sendiri.',
                style: t.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: t.weightMedium,
                  color: t.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip({
    required PutarTheme t,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? t.secondary : t.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: t.ink, width: t.borderWidth),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: t.miniShadowOffset,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
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

  Widget _buildSwitchRow({
    required PutarTheme t,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: t.weightBold,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: t.bodySmall.copyWith(
                        fontSize: 12,
                        fontWeight: t.weightMedium,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SettingToggle(
                value: value,
                label: title,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            height: 1.5,
            color: t.ink.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}
