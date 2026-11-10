import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/group/models/group_model.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/painters/sticker_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
    final groupService = ref.watch(groupServiceProvider);
    final groupStream = groupService.watchGroup(widget.groupId);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink),
          onPressed: () {
            SoundService.instance.play(Sfx.uiTap);
            context.pop();
          },
        ),
        title: Text(
          'Budget & Permainan',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<GroupModel?>(
        stream: groupStream,
        builder: (context, snapshot) {
          final group = snapshot.data ?? groupService.getLocalGroup(widget.groupId);
          if (group == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.ink));
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
                      _buildModeSelector(isOwner: isOwner),
                      const SizedBox(height: 18),

                      // 2. Konten Spesifik per Mode
                      if (_budgetMode == 'game')
                        _buildGameModeSection(isOwner: isOwner)
                      else
                        _buildFixedModeSection(isOwner: isOwner),

                      // 3. Section Permainan Lainnya (Segera Hadir / Maintenance)
                      _buildUpcomingGamesSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Bar Aksi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.ink, width: 2.5),
                  ),
                ),
                child: isOwner
                    ? StickerButton(
                        text: _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan',
                        backgroundColor: AppColors.mint,
                        height: 52,
                        borderRadius: 16,
                        onPressed: _isSaving ? null : _handleSave,
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.ink, width: 2),
                        ),
                        child: Text(
                          'Hanya pemilik grup yang dapat mengubah pengaturan budget.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
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
  Widget _buildModeSelector({required bool isOwner}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
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
          color: isSelected ? AppColors.matahari : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.ink, width: 2) : null,
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(1.5, 1.5),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.bodyLargeBold.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }

  /// 2A. Mode "Dari Permainan" (Layar 53)
  Widget _buildGameModeSection({required bool isOwner}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keterangan Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.langit,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Row(
            children: [
              const CustomPaint(
                size: Size(16, 16),
                painter: CustomGearPainter(color: AppColors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget tiap sesi ditentukan dari hasil putaran roda jajan.',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siapa boleh memutar roda?',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tentukan anggota mana yang memiliki hak memutar roda sesi.',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),

              // Pilihan 1: Hanya Pemilik
              _buildPolicyOption(
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(3, 3),
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
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ink, width: 1.8),
                    ),
                    child: Text(
                      '${_slots.length} dari maks. 12',
                      style: AppTypography.buttonSmall.copyWith(fontSize: 11),
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
                  final color = AppColors.getWheelColor(index);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          RupiahFormatter.formatCompact(amount),
                          style: AppTypography.buttonSmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeSlot(index),
                            child: const CustomPaint(
                              size: Size(12, 12),
                              painter: CustomCrossPainter(color: AppColors.ink, strokeWidth: 2.2),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink, width: 2),
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
                            hintStyle: AppTypography.bodyMedium.copyWith(
                              color: AppColors.ink.withValues(alpha: 0.4),
                            ),
                          ),
                          style: AppTypography.bodyLargeBold.copyWith(
                            color: AppColors.ink,
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
                          color: AppColors.matahari,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Tambah',
                          style: AppTypography.buttonSmall.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
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
          color: isSelected ? AppColors.cream : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.ink,
            width: isSelected ? 2.5 : 1.8,
          ),
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
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.tomat : AppColors.surface,
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
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
                    style: AppTypography.bodyLargeBold.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.ink.withValues(alpha: 0.7),
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
  Widget _buildFixedModeSection({required bool isOwner}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keterangan Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Row(
            children: [
              const CustomPaint(
                size: Size(16, 16),
                painter: CustomCheckIconPainter(color: AppColors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget date langsung ditentukan nominal tetap tanpa harus memutar roda.',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nominal Budget per Date',
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),

              // Kolom Nominal Besar Berformat Rupiah
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ink, width: 2.5),
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
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      )
                    : Text(
                        RupiahFormatter.format(_fixedBudget),
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(height: 14),

              if (isOwner) ...[
                // Chip Pilih Cepat
                Text(
                  'Pilih Cepat',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
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
                          color: isSel ? AppColors.matahari : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.ink, width: 2),
                          boxShadow: isSel
                              ? const [
                                  BoxShadow(
                                    color: AppColors.ink,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          RupiahFormatter.formatCompact(amount),
                          style: AppTypography.buttonSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
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
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDeltaChip('+10rb', 10000),
                    _buildDeltaChip('+50rb', 50000),
                    _buildDeltaChip('+100rb', 100000),
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
            color: AppColors.permen.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomPaint(
                size: Size(18, 18),
                painter: CustomInfoCirclePainter(color: AppColors.ink, strokeWidth: 2.2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Berlaku untuk date berikutnya; date yang sedang berjalan tidak berubah.',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeltaChip(String label, int delta) {
    return GestureDetector(
      onTap: () => _addFixedBudget(delta),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink, width: 1.8),
        ),
        child: Text(
          label,
          style: AppTypography.buttonSmall.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingGamesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
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
                  color: AppColors.matahari,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: const Icon(Icons.construction_rounded, size: 18, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Permainan Lainnya',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Dalam tahap pengembangan untuk multiplayer grup',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildUpcomingGameRow(emoji: '🎲', title: 'Kocok Dadu Bersama', subtitle: 'Multiplayer roll dadu live bersama teman'),
          const SizedBox(height: 8),
          _buildUpcomingGameRow(emoji: '🔮', title: 'Gacha Kapsul Grup', subtitle: 'Tarik tuas gacha bersama anggota'),
          const SizedBox(height: 8),
          _buildUpcomingGameRow(emoji: '✉️', title: 'Pilih Amplop Misteri', subtitle: 'Tiap anggota memilih amplop kejutan'),
          const SizedBox(height: 8),
          _buildUpcomingGameRow(emoji: '🪙', title: 'Lempar Koin Grup', subtitle: 'Tebak koin bareng melipatgandakan budget'),
        ],
      ),
    );
  }

  Widget _buildUpcomingGameRow({required String emoji, required String title, required String subtitle}) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.uiTap);
        InAppToast.show(
          context,
          message: 'Mode $title sedang disiapkan untuk pembaruan berikutnya!',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ink, width: 1.8),
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
                    style: AppTypography.buttonSmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.matahari,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink, width: 1.2),
              ),
              child: Text(
                'SEGERA HADIR',
                style: AppTypography.chipLabel.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

