import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group/models/group_model.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/putar_theme.dart';
import '../../../core/utils/rupiah_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/widgets/in_app_toast.dart';
import '../../../core/widgets/sticker_button.dart';

/// Layar 53 & 54: Budget Grup (Mode Dari Permainan & Angka Tetap)
/// Sesuai Spesifikasi UPDATE 2 (Grup bersama, online/offline, dan sinkronisasi)
class GroupBudgetSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupBudgetSettingsScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<GroupBudgetSettingsScreen> createState() => _GroupBudgetSettingsScreenState();
}

class _GroupBudgetSettingsScreenState extends ConsumerState<GroupBudgetSettingsScreen> {
  late String _budgetMode; // 'game' | 'fixed'
  late String _spinPolicy; // 'owner' | 'all'
  late int _fixedBudget;
  late List<int> _slots;

  final TextEditingController _fixedBudgetController = TextEditingController();
  final TextEditingController _slotInputController = TextEditingController();
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _fixedBudgetController.dispose();
    _slotInputController.dispose();
    super.dispose();
  }

  void _initFromGroup(GroupModel group) {
    if (_isInitialized) return;
    _budgetMode = group.budgetMode;
    _spinPolicy = group.spinPolicy;
    _fixedBudget = group.fixedBudget;
    _slots = List.from(group.effectiveSlots);
    _fixedBudgetController.text = RupiahFormatter.format(_fixedBudget);
    _isInitialized = true;
  }

  void _addSlot() {
    if (_slots.length >= 12) {
      InAppToast.show(context, message: 'Maksimal 12 pilihan nominal!');
      return;
    }
    final amount = RupiahFormatter.parse(_slotInputController.text);
    if (amount < 1000) {
      InAppToast.show(context, message: 'Nominal minimal Rp1.000!');
      return;
    }
    if (amount > 10000000) {
      InAppToast.show(context, message: 'Nominal maksimal Rp10.000.000!');
      return;
    }

    setState(() {
      _slots.add(amount);
      _slotInputController.clear();
    });
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();
  }

  void _removeSlot(int index) {
    if (_slots.length <= 2) {
      InAppToast.show(context, message: 'Minimal harus ada 2 nominal di roda!');
      return;
    }
    setState(() {
      _slots.removeAt(index);
    });
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.selectionClick();
  }

  void _setFixedBudget(int amount) {
    final clamped = amount.clamp(10000, 10000000);
    setState(() {
      _fixedBudget = clamped;
      _fixedBudgetController.text = RupiahFormatter.format(clamped);
    });
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();
  }

  void _addFixedBudget(int delta) {
    _setFixedBudget(_fixedBudget + delta);
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    if (_budgetMode == 'game') {
      if (_slots.length < 2 || _slots.length > 12) {
        InAppToast.show(context, message: 'Pilihan nominal roda harus antara 2 hingga 12!');
        return;
      }
    } else {
      final parsed = RupiahFormatter.parse(_fixedBudgetController.text);
      if (parsed < 10000) {
        InAppToast.show(context, message: 'Nominal fixed budget minimal Rp10.000!');
        return;
      }
      _fixedBudget = parsed;
    }

    setState(() => _isSaving = true);
    SoundService.instance.play(Sfx.uiTap);

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateGroupBudgetSettings(
        gid: widget.groupId,
        budgetMode: _budgetMode,
        fixedBudget: _fixedBudget,
        spinPolicy: _spinPolicy,
        wheelSlots: _slots,
      );

      if (mounted) {
        InAppToast.show(context, message: 'Pengaturan budget grup berhasil disimpan!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        InAppToast.show(context, message: 'Gagal menyimpan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final groupService = ref.watch(groupServiceProvider);
    final groupStream = groupService.watchGroup(widget.groupId);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: CustomPaint(
            size: const Size(22, 22),
            painter: CustomBackIconPainter(
              color: t.ink,
              strokeWidth: 2.8,
            ),
          ),
          onPressed: () {
            SoundService.instance.play(Sfx.uiTap);
            context.pop();
          },
        ),
        title: Text(
          'Budget & Permainan',
          style: t.titleMedium.copyWith(
            fontSize: 20,
            fontWeight: t.weightExtraBold,
            color: t.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<GroupModel?>(
        stream: groupStream,
        builder: (context, snapshot) {
          final group = snapshot.data ?? groupService.getLocalGroup(widget.groupId);
          if (group == null) {
            return Center(child: CircularProgressIndicator(color: t.ink));
          }

          _initFromGroup(group);
          final myUid = groupService.authService.currentUid;
          final isOwner = group.ownerUid == myUid;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Selector Mode Budget: "Dari Permainan" vs "Angka Tetap"
                      _buildModeSelector(t: t, isOwner: isOwner),
                      const SizedBox(height: 18),

                      // 2. Konten Spesifik per Mode
                      if (_budgetMode == 'game')
                        _buildGameModeSection(t: t, isOwner: isOwner)
                      else
                        _buildFixedModeSection(t: t, isOwner: isOwner),

                      // 3. Section Permainan Lainnya (Segera Hadir / Maintenance)
                      _buildUpcomingGamesSection(t),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Bar Aksi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(
                    top: BorderSide(color: t.borderColor, width: t.subtleBorderWidth),
                  ),
                ),
                child: isOwner
                    ? StickerButton(
                        text: _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan',
                        backgroundColor: t.success,
                        height: 52,
                        borderRadius: 16,
                        onPressed: _isSaving ? null : _handleSave,
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.borderColor, width: 2),
                        ),
                        child: Text(
                          'Hanya pemilik grup yang dapat mengubah pengaturan budget.',
                          style: t.bodySmall.copyWith(
                            color: t.ink,
                            fontWeight: t.weightSemiBold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 1. Neo-Brutalist Mode Selector Segment
  Widget _buildModeSelector({
    required PutarTheme t,
    required bool isOwner,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: const Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              t: t,
              label: 'Dari Permainan',
              iconName: 'wheel',
              isSelected: _budgetMode == 'game',
              onTap: isOwner
                  ? () {
                      SoundService.instance.play(Sfx.uiTap);
                      setState(() => _budgetMode = 'game');
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModeTab(
              t: t,
              label: 'Angka Tetap',
              iconName: 'tag',
              isSelected: _budgetMode == 'fixed',
              onTap: isOwner
                  ? () {
                      SoundService.instance.play(Sfx.uiTap);
                      setState(() => _budgetMode = 'fixed');
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required PutarTheme t,
    required String label,
    required String iconName,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? t.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: t.borderColor, width: 2) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: const Offset(1.5, 1.5),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: t.bodyLargeBold.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? t.weightExtraBold : t.weightSemiBold,
            color: t.ink,
          ),
        ),
      ),
    );
  }

  /// 2A. Mode "Dari Permainan" (Layar 53)
  Widget _buildGameModeSection({
    required PutarTheme t,
    required bool isOwner,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keterangan Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.info,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.borderColor, width: 2),
          ),
          child: Row(
            children: [
              CustomPaint(
                size: const Size(16, 16),
                painter: CustomGearPainter(color: t.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget tiap sesi ditentukan dari hasil putaran roda jajan.',
                  style: t.bodySmall.copyWith(
                    fontWeight: t.weightBold,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kartu Kebijakan Siapa Boleh Memutar Roda (spinPolicy)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
            boxShadow: [
              BoxShadow(
                color: t.shadowColor,
                offset: t.smallShadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siapa boleh memutar roda?',
                style: t.titleMedium.copyWith(
                  fontSize: 16,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tentukan anggota mana yang memiliki hak memutar roda sesi.',
                style: t.bodySmall.copyWith(
                  fontSize: 12,
                  color: t.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),

              // Pilihan 1: Hanya Pemilik
              _buildPolicyOption(
                t: t,
                title: 'Hanya Pemilik Grup',
                subtitle: 'Hanya pemilik yang dapat memutar roda sesi.',
                isSelected: _spinPolicy == 'owner',
                isOwner: isOwner,
                onTap: () {
                  setState(() => _spinPolicy = 'owner');
                  SoundService.instance.play(Sfx.uiTap);
                },
              ),
              const SizedBox(height: 10),

              // Pilihan 2: Semua Anggota
              _buildPolicyOption(
                t: t,
                title: 'Semua Anggota',
                subtitle: 'Semua anggota grup yang online bebas memutar roda.',
                isSelected: _spinPolicy == 'all',
                isOwner: isOwner,
                onTap: () {
                  setState(() => _spinPolicy = 'all');
                  SoundService.instance.play(Sfx.uiTap);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kartu Editor Pilihan Nominal Roda
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
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
                  Text(
                    'Nominal Roda Grup',
                    style: t.titleMedium.copyWith(
                      fontSize: 16,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.borderColor, width: 1.8),
                    ),
                    child: Text(
                      '${_slots.length} dari maks. 12',
                      style: t.buttonSmall.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chip Nominal Roda Berwarna
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_slots.length, (index) {
                  final amount = _slots[index];
                  final color = t.getWheelColor(index);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowColor,
                          offset: t.miniShadowOffset,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          RupiahFormatter.formatCompact(amount),
                          style: t.buttonSmall.copyWith(
                            fontSize: 13,
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeSlot(index),
                            child: CustomPaint(
                              size: const Size(12, 12),
                              painter: CustomCrossPainter(color: t.ink, strokeWidth: 2.2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),

              if (isOwner) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.borderColor, width: 2),
                        ),
                        child: TextField(
                          controller: _slotInputController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            const ThousandsSeparatorInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Rp 75.000',
                            hintStyle: t.bodyMedium.copyWith(
                              color: t.ink.withValues(alpha: 0.4),
                            ),
                          ),
                          style: t.bodyLargeBold.copyWith(
                            color: t.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addSlot,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: t.secondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.borderColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: t.shadowColor,
                              offset: t.miniShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Tambah',
                          style: t.buttonSmall.copyWith(
                            color: t.ink,
                            fontWeight: t.weightExtraBold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyOption({
    required PutarTheme t,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isOwner,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isOwner ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? t.bg : t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: t.borderColor,
            width: isSelected ? t.subtleBorderWidth : 1.8,
          ),
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
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? t.primary : t.surface,
                border: Border.all(color: t.borderColor, width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.surface,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.bodyLargeBold.copyWith(
                      fontSize: 14,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: t.bodySmall.copyWith(
                      fontSize: 11,
                      color: t.ink.withValues(alpha: 0.7),
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

  /// 2B. Mode "Angka Tetap" (Layar 54)
  Widget _buildFixedModeSection({
    required PutarTheme t,
    required bool isOwner,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keterangan Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.success,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.borderColor, width: 2),
          ),
          child: Row(
            children: [
              CustomPaint(
                size: const Size(16, 16),
                painter: CustomCheckIconPainter(color: t.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget date langsung ditentukan nominal tetap tanpa harus memutar roda.',
                  style: t.bodySmall.copyWith(
                    fontWeight: t.weightBold,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kartu Input Nominal Besar
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
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
              Text(
                'Nominal Budget per Date',
                style: t.titleMedium.copyWith(
                  fontSize: 16,
                  fontWeight: t.weightExtraBold,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 12),

              // Kolom Nominal Besar Berformat Rupiah
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
                ),
                child: isOwner
                    ? TextField(
                        controller: _fixedBudgetController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          const ThousandsSeparatorInputFormatter(),
                        ],
                        onChanged: (val) {
                          final p = RupiahFormatter.parse(val);
                          setState(() => _fixedBudget = p);
                        },
                        style: t.displayMedium.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: t.ink,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      )
                    : Text(
                        RupiahFormatter.format(_fixedBudget),
                        style: t.displayMedium.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: t.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(height: 14),

              if (isOwner) ...[
                // Chip Pilih Cepat
                Text(
                  'Pilih Cepat',
                  style: t.bodySmall.copyWith(
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100000, 150000, 200000, 300000].map((amount) {
                    final isSel = _fixedBudget == amount;
                    return GestureDetector(
                      onTap: () => _setFixedBudget(amount),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? t.secondary : t.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.borderColor, width: 2),
                          boxShadow: isSel
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
                          RupiahFormatter.formatCompact(amount),
                          style: t.buttonSmall.copyWith(
                            fontWeight: t.weightExtraBold,
                            color: t.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Chip Tambah Cepat
                Text(
                  'Tambah Cepat',
                  style: t.bodySmall.copyWith(
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDeltaChip(t, '+10rb', 10000),
                    _buildDeltaChip(t, '+50rb', 50000),
                    _buildDeltaChip(t, '+100rb', 100000),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Catatan Wajib Sesuai Spesifikasi UPDATE 2
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.accentPink.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.borderColor, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomPaint(
                size: const Size(18, 18),
                painter: CustomInfoCirclePainter(color: t.ink, strokeWidth: 2.2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Berlaku untuk date berikutnya; date yang sedang berjalan tidak berubah.',
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
      ],
    );
  }

  Widget _buildDeltaChip(PutarTheme t, String label, int delta) {
    return GestureDetector(
      onTap: () => _addFixedBudget(delta),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.borderColor, width: 1.8),
        ),
        child: Text(
          label,
          style: t.buttonSmall.copyWith(
            fontWeight: t.weightExtraBold,
            color: t.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingGamesSection(PutarTheme t) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.borderColor, width: t.subtleBorderWidth),
        boxShadow: [
          BoxShadow(
            color: t.shadowColor,
            offset: t.smallShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: t.secondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.borderColor, width: 1.8),
                ),
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: CustomGamepadIconPainter(
                    color: t.ink,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Permainan Grup',
                      style: t.titleMedium.copyWith(
                        fontSize: 16,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      'Pilih dan mainkan mode permainan alternatif bersama anggota grup',
                      style: t.bodySmall.copyWith(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildUpcomingGameRow(
            t: t,
            emoji: '🎲',
            title: 'Kocok Dadu Bersama',
            subtitle: 'Multiplayer roll dadu live bersama teman',
            route: '/group/dice',
          ),
          const SizedBox(height: 8),
          _buildUpcomingGameRow(
            t: t,
            emoji: '🔮',
            title: 'Gacha Kapsul Grup',
            subtitle: 'Tarik tuas gacha bersama anggota',
            route: '/group/capsule',
          ),
          const SizedBox(height: 8),
          _buildUpcomingGameRow(
            t: t,
            emoji: '✉️',
            title: 'Pilih Amplop Misteri',
            subtitle: 'Tiap anggota memilih amplop kejutan',
            route: '/group/envelope',
          ),
          const SizedBox(height: 8),
          _buildUpcomingGameRow(
            t: t,
            emoji: '🪙',
            title: 'Lempar Koin Grup',
            subtitle: 'Tebak koin bareng melipatgandakan budget',
            route: '/group/coin',
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingGameRow({
    required PutarTheme t,
    required String emoji,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        HapticFeedback.lightImpact();
        context.push(route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.borderColor, width: 1.8),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.buttonSmall.copyWith(
                      fontSize: 13,
                      fontWeight: t.weightExtraBold,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: t.bodySmall.copyWith(
                      fontSize: 11,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: t.success,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: t.shadowColor,
                    offset: const Offset(1.5, 1.5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MAINKAN',
                    style: t.chipLabel.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: t.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  CustomPaint(
                    size: const Size(12, 12),
                    painter: CustomForwardIconPainter(
                      color: t.ink,
                      strokeWidth: 2.6,
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
}

