import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_notification_settings_service.dart';
import '../../../core/group/widgets/setting_toggle.dart';
import '../../../core/group/widgets/in_app_banner.dart';
import '../../../core/group/widgets/group_important_dialog.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../notifications/notification_service.dart';
import '../widgets/bookmark_tab_bar.dart';
import '../widgets/theme_preview_painters.dart';

/// Halaman Pengaturan Terpadu (Aplikasi & Grup) sesuai Setelan1.dc.html
/// Memadukan pengaturan aplikasi dan grup dengan navigasi penanda buku (bookmark tabs)
/// dan animasi transisi in/out yang halus.
class SettingsScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const SettingsScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final PageController _pageController;
  late int _selectedTab;

  bool _fridayReminderEnabled = true;
  bool _isNotificationPermissionGranted = true;
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
    _pageController = PageController(initialPage: _selectedTab);
    _loadInitialSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminder = prefs.getBool('pj_friday_reminder_enabled') ?? true;
      final perm = await NotificationService.instance.areNotificationsEnabled();

      if (mounted) {
        setState(() {
          _fridayReminderEnabled = reminder;
          _isNotificationPermissionGranted = perm;
        });
      }
    } catch (_) {}
  }

  Future<void> _setFridayReminderEnabled(bool enabled) async {
    setState(() => _fridayReminderEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pj_friday_reminder_enabled', enabled);
      if (enabled) {
        await NotificationService.instance.scheduleWeeklyFridayReminder();
        if (mounted) {
          InAppBanner.show(
            context,
            title: '⏰ Pengingat Aktif',
            subtitle: 'Pengingat Jumat malam pukul 18.00 berhasil diaktifkan.',
            category: InAppBannerCategory.sessionEnd,
          );
        }
      } else {
        await NotificationService.instance.cancelWeeklyFridayReminder();
        if (mounted) {
          InAppBanner.show(
            context,
            title: '🔕 Pengingat Dimatikan',
            subtitle: 'Pengingat kencan Jumat malam telah dinonaktifkan.',
            category: InAppBannerCategory.budgetWarning80,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _requestNotificationPermission() async {
    SoundService.instance.play(Sfx.uiTap);
    final granted = await NotificationService.instance.requestNotificationPermission(context);
    if (mounted) {
      setState(() => _isNotificationPermissionGranted = granted);
      if (granted) {
        InAppBanner.show(
          context,
          title: '🔔 Izin Notifikasi Diberikan',
          subtitle: 'Notifikasi sistem telah aktif untuk memantau budget dan grup.',
          category: InAppBannerCategory.memberJoin,
        );
      }
    }
  }

  void _showEditNameDialog() {
    SoundService.instance.play(Sfx.uiTap);
    final authService = ref.read(groupAuthServiceProvider);
    final currentName = authService.displayName ?? 'Kamu';
    final controller = TextEditingController(text: currentName);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.ink, width: 3.2),
        ),
        title: Text(
          'Ubah Nama Tampilan',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nama ini akan terlihat oleh anggota grup dan pada catatan jajan kamu.',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                color: const Color(0xFF5B4B7A),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                maxLength: 15,
                autofocus: true,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                  hintText: 'Masukkan nama kamu...',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.instance.play(Sfx.uiTap);
              Navigator.pop(ctx);
            },
            child: Text(
              'Batal',
              style: AppTypography.buttonSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.matahari,
              foregroundColor: AppColors.ink,
              elevation: 0,
              side: const BorderSide(color: AppColors.ink, width: 2.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              SoundService.instance.play(Sfx.uiTap);
              Navigator.pop(ctx);

              await authService.setDisplayName(newName);
              await ref.read(groupServiceProvider).updateMyMemberName(newName);

              if (mounted) {
                setState(() {});
                InAppBanner.show(
                  context,
                  title: '✨ Nama Diperbarui',
                  subtitle: 'Nama tampilan berhasil diubah menjadi "$newName".',
                  category: InAppBannerCategory.memberJoin,
                );
              }
            },
            child: Text(
              'Simpan',
              style: AppTypography.buttonSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLeaveGroup() async {
    final activeGroup = ref.read(activeGroupStreamProvider).valueOrNull;
    final gid = activeGroup?.id ?? ref.read(groupServiceProvider).getActiveGroupId();
    if (gid == null) return;

    final confirmed = await GroupImportantDialog.showConfirmLeaveGroup(context);
    if (confirmed == true && mounted) {
      final groupService = ref.read(groupServiceProvider);
      await groupService.leaveGroup(gid);
      ref.read(appScopeProvider.notifier).state = AppScope.pribadi;
      ref.read(activeGroupIdProvider.notifier).state = null;

      if (mounted) {
        InAppBanner.show(
          context,
          title: '👋 Keluar dari Grup',
          subtitle: 'Kamu telah keluar dari grup dan kembali ke mode pribadi.',
          category: InAppBannerCategory.memberLeave,
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header: Tombol Kembali + Judul Pengaturan
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
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
                          context.go('/');
                        }
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3.0),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const CustomPaint(
                          size: Size(20, 20),
                          painter: CustomBackIconPainter(strokeWidth: 3.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pengaturan',
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Bookmark Tab Bar (Penanda Buku)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: BookmarkTabBar(
                selectedIndex: _selectedTab,
                onTabSelected: (index) {
                  setState(() => _selectedTab = index);
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ),

            // 3. Konten Halaman (PageView dengan transisi animasi halus)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _selectedTab = index);
                },
                children: [
                  _buildAplikasiTab(context),
                  _buildGrupTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: PENGATURAN APLIKASI (Sesuai Setelan1.dc.html)
  // =========================================================================
  Widget _buildAplikasiTab(BuildContext context) {
    final soundSettings = ref.watch(soundSettingsProvider);
    final soundNotifier = ref.read(soundSettingsProvider.notifier);
    final authService = ref.watch(groupAuthServiceProvider);
    final displayName = authService.displayName ?? 'Kamu';

    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final groupName = activeGroupAsync.valueOrNull?.name ?? 'Date Jumat';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KARTU 1: TEMA
          _buildNeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tema',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.matahari,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.ink, width: 2.0),
                          ),
                          child: Text(
                            'Dipakai: Pasar Malam',
                            style: AppTypography.buttonSmall.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Opsi 1: Pasar Malam (Aktif)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          SoundService.instance.play(Sfx.uiTap);
                          InAppBanner.show(
                            context,
                            title: '🎪 Tema Utama',
                            subtitle: 'Tema Pasar Malam sedang aktif sebagai tema utama aplikasi.',
                            category: InAppBannerCategory.sessionEnd,
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.ink, width: 3.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.ink,
                                    offset: Offset(3, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(
                                    height: 56,
                                    child: Center(
                                      child: SizedBox(
                                        width: 54,
                                        height: 54,
                                        child: CustomPaint(
                                          painter: PasarMalamWheelPainter(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pasar Malam',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Checkmark Badge Pojok Kanan Atas
                            Positioned(
                              top: -8,
                              right: -6,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.tomat,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.ink, width: 2.5),
                                ),
                                alignment: Alignment.center,
                                child: const CustomPaint(
                                  size: Size(13, 13),
                                  painter: CustomCheckIconPainter(
                                    color: Colors.white,
                                    strokeWidth: 3.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Opsi 2: Kucing Manis (Dalam Pengembangan / Maintenance)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          SoundService.instance.play(Sfx.notifWarning);
                          InAppBanner.show(
                            context,
                            title: '🚧 Sedang Dikembangkan',
                            subtitle: 'Tema Kucing Manis sedang dalam tahap pengembangan! Nantikan segera ya~',
                            category: InAppBannerCategory.budgetWarning80,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.ink, width: 2.5),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(
                                height: 56,
                                child: Center(
                                  child: SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: CustomPaint(
                                      painter: KucingManisPainter(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Kucing Manis',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Lihat Semua Tema Action
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.notifWarning);
                    InAppBanner.show(
                      context,
                      title: '🎨 Galeri Tema',
                      subtitle: 'Fitur katalog tema kustom sedang disiapkan untuk update berikutnya!',
                      category: InAppBannerCategory.budgetWarning80,
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lihat semua tema',
                          style: AppTypography.buttonSmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CustomPaint(
                            painter: CustomForwardIconPainter(
                              color: AppColors.ink,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KARTU 2: SUARA DAN GETAR (100% Berfungsi Nyata)
          _buildNeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Suara dan getar',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),

                // Toggle Suara
                _buildSettingRow(
                  title: 'Suara',
                  subtitle: 'Efek suara permainan dan notifikasi',
                  trailing: SettingToggle(
                    value: soundSettings.soundEnabled,
                    label: 'Suara',
                    onChanged: (val) {
                      soundNotifier.setSoundEnabled(val);
                      if (val) {
                        SoundService.instance.play(Sfx.uiTap);
                      }
                    },
                  ),
                ),

                // Toggle Getar
                _buildSettingRow(
                  title: 'Getar',
                  subtitle: 'Getaran ringan saat putar dan pindah irisan',
                  trailing: SettingToggle(
                    value: soundSettings.vibrationEnabled,
                    label: 'Getar',
                    onChanged: (val) {
                      soundNotifier.setVibrationEnabled(val);
                      if (val) {
                        SoundService.instance.play(Sfx.uiTap, haptic: true);
                      }
                    },
                  ),
                ),

                // Slider Volume Efek
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Volume efek',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 12,
                            activeTrackColor: AppColors.matahari,
                            inactiveTrackColor: AppColors.cream,
                            thumbColor: Colors.white,
                            overlayColor: AppColors.matahari.withValues(alpha: 0.2),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                              elevation: 2,
                            ),
                            trackShape: const RoundedRectSliderTrackShape(),
                          ),
                          child: Slider(
                            value: soundSettings.volume,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            onChanged: soundSettings.soundEnabled
                                ? (val) {
                                    soundNotifier.setVolume(val);
                                  }
                                : null,
                            onChangeEnd: (val) {
                              SoundService.instance.play(Sfx.coinRecord);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KARTU 3: NOTIFIKASI
          _buildNeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Notifikasi',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),

                // Pengingat Jumat Malam
                _buildSettingRow(
                  title: 'Pengingat Jumat malam',
                  subtitle: 'Setiap Jumat pukul 18.00',
                  trailing: SettingToggle(
                    value: _fridayReminderEnabled,
                    label: 'Pengingat Jumat malam',
                    onChanged: (val) => _setFridayReminderEnabled(val),
                  ),
                ),

                // Notifikasi Grup (Akses cepat pindah ke Tab Grup)
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: _buildSettingRow(
                    title: 'Notifikasi grup',
                    subtitle: '$groupName · jenis dan bisukan',
                    trailing: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(
                        painter: CustomForwardIconPainter(
                          color: AppColors.ink,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Izin Notifikasi Sistem
                _buildSettingRow(
                  title: 'Izin notifikasi',
                  subtitle: 'Status notifikasi sistem Android',
                  trailing: GestureDetector(
                    onTap: _isNotificationPermissionGranted ? null : _requestNotificationPermission,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isNotificationPermissionGranted ? AppColors.mint : AppColors.tomat,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.ink, width: 2.0),
                      ),
                      child: Text(
                        _isNotificationPermissionGranted ? 'Aktif' : 'Nonaktif',
                        style: AppTypography.buttonSmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _isNotificationPermissionGranted ? AppColors.ink : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KARTU 4: NAMA TAMPILAN
          _buildNeoCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nama tampilan',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B4B7A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _showEditNameDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'Ubah',
                      style: AppTypography.buttonSmall.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Info Versi Aplikasi (Ketuk untuk Observabilitas Notifikasi)
          Center(
            child: GestureDetector(
              onTap: () {
                _debugTapCount++;
                if (_debugTapCount >= 3 || kDebugMode) {
                  _debugTapCount = 0;
                  context.push('/debug/notifications');
                }
              },
              child: Text(
                'Putar Jajan v1.0',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5B4B7A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: PENGATURAN GRUP (Notifikasi & Aksi Grup)
  // =========================================================================
  Widget _buildGrupTab(BuildContext context) {
    final activeGroupAsync = ref.watch(activeGroupStreamProvider);
    final group = activeGroupAsync.valueOrNull;
    final gid = group?.id ?? ref.read(groupServiceProvider).getActiveGroupId();
    final groupName = group?.name ?? 'Sesi Grup Jajan';

    final authService = ref.watch(groupAuthServiceProvider);

    final membersAsync = ref.watch(activeGroupMembersStreamProvider);
    final members = membersAsync.valueOrNull ?? [];

    final isOwner = (group != null && authService.isCurrentUser(group.ownerUid)) ||
        members.any((m) => m.role == 'owner' && authService.isCurrentUser(m.uid));

    if (gid == null) {
      // Keadaan saat pengguna belum bergabung ke grup mana pun
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildNeoCard(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.langit,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 2.5),
                    ),
                    child: const Center(
                      child: CustomPaint(
                        size: Size(26, 26),
                        painter: CustomShareIconPainter(color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum Bergabung ke Grup',
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gabung atau buat grup bersama teman untuk mengatur notifikasi aktivitas belanja dan putaran roda.',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5B4B7A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.uiTap);
                      context.push('/group/join-or-create');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.matahari,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.ink, width: 2.5),
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
                        'Gabung atau Buat Grup',
                        style: AppTypography.buttonSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Jika memiliki grup aktif
    final settings = ref.watch(groupNotificationSettingsProvider(gid));
    final notifier = ref.read(groupNotificationSettingsProvider(gid).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KARTU HEADER GRUP AKTIF
          _buildNeoCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grup Aktif',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B4B7A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        groupName,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner ? 'Peran: Pemilik Grup' : 'Peran: Anggota',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOwner ? AppColors.jeruk : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    context.push('/group/invite/$gid');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.matahari,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.ink, width: 2.2),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'Kelola',
                      style: AppTypography.buttonSmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KARTU PENGATURAN NOMINAL RODA (Khusus Pemilik Grup)
          if (isOwner && group != null) ...[
            _buildNeoCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nominal Roda Grup',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.effectiveSlots.length} pilihan nominal aktif di roda jajan',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF5B4B7A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.uiTap);
                      context.push('/custom-wheel?groupId=$gid');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.matahari,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.ink, width: 2.2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'Atur',
                        style: AppTypography.buttonSmall.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // KARTU 1: BISUKAN GRUP
          _buildNeoCard(
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
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Matikan semua notifikasi grup ini sementara',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF5B4B7A),
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
                if (settings.isCurrentlyMuted) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0x2222163A), height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Durasi bisukan',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDurationChip(
                        label: '1 Jam',
                        durationKey: '1_jam',
                        isSelected: settings.muteDuration == '1_jam',
                        onTap: () => notifier.setMuteDuration('1_jam'),
                      ),
                      const SizedBox(width: 8),
                      _buildDurationChip(
                        label: '8 Jam',
                        durationKey: '8_jam',
                        isSelected: settings.muteDuration == '8_jam',
                        onTap: () => notifier.setMuteDuration('8_jam'),
                      ),
                      const SizedBox(width: 8),
                      _buildDurationChip(
                        label: 'Sampai dinyalakan',
                        durationKey: 'sampai_kunyalakan',
                        isSelected: settings.muteDuration == 'sampai_kunyalakan',
                        onTap: () => notifier.setMuteDuration('sampai_kunyalakan'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // KARTU 2: JENIS NOTIFIKASI AKTIVITAS GRUP
          _buildNeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Jenis notifikasi grup',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSettingRow(
                  title: 'Jajan & pengeluaran baru',
                  subtitle: 'Saat anggota lain mencatat jajan',
                  trailing: SettingToggle(
                    value: settings.notifyExpenses,
                    label: 'Notifikasi jajan baru',
                    onChanged: (val) => notifier.setNotifyExpenses(val),
                  ),
                ),
                _buildSettingRow(
                  title: 'Putaran roda baru',
                  subtitle: 'Saat ada anggota yang memutar roda',
                  trailing: SettingToggle(
                    value: settings.notifySpin,
                    label: 'Notifikasi putaran roda',
                    onChanged: (val) => notifier.setNotifySpin(val),
                  ),
                ),
                _buildSettingRow(
                  title: 'Peringatan budget 80%',
                  subtitle: 'Peringatan saat pengeluaran grup mendekati batas',
                  trailing: SettingToggle(
                    value: settings.notifyWarning80,
                    label: 'Peringatan budget 80%',
                    onChanged: (val) => notifier.setNotifyWarning80(val),
                  ),
                ),
                _buildSettingRow(
                  title: 'Date selesai',
                  subtitle: 'Hasil akhir dan total jajan sesi grup',
                  trailing: SettingToggle(
                    value: settings.notifyDateComplete,
                    label: 'Notifikasi date selesai',
                    onChanged: (val) => notifier.setNotifyDateComplete(val),
                  ),
                ),
                _buildSettingRow(
                  title: 'Anggota masuk & keluar',
                  subtitle: 'Pemberitahuan saat anggota bergabung atau keluar',
                  trailing: SettingToggle(
                    value: settings.notifyMembers,
                    label: 'Notifikasi anggota',
                    onChanged: (val) => notifier.setNotifyMembers(val),
                  ),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // AKSI KELUAR GRUP (Bagi Anggota)
          if (!isOwner) ...[
            GestureDetector(
              onTap: _handleLeaveGroup,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.tomat, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Keluar dari Grup',
                  style: AppTypography.buttonSmall.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tomat,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildNeoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: child,
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String subtitle,
    required Widget trailing,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0x2222163A),
                  width: 1.5,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5B4B7A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDurationChip({
    required String label,
    required String durationKey,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService.instance.play(Sfx.uiTap);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.matahari : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.ink, width: 2.0),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTypography.buttonSmall.copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
