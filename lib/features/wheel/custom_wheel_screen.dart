import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/games/game_engine.dart';
import '../../core/group/services/group_service.dart';
import '../../core/painters/sticker_icons.dart';
import '../../core/theme/putar_theme.dart';
import '../../core/utils/rupiah_formatter.dart';
import '../../core/utils/sound_service.dart';
import '../../core/widgets/in_app_toast.dart';
import '../../core/widgets/sticker_button.dart';
import '../../data/database_provider.dart';
import '../../data/game_pool_repository.dart';
import 'wheel_painter.dart';

/// Layar 07: Isi Roda / Editor Pool yang dipakai ulang untuk Roda, Kapsul, & Amplop
/// Sesuai design/source/Editor.dc.html
class CustomWheelScreen extends ConsumerStatefulWidget {
  final GameType gameType;
  final String? groupId;

  const CustomWheelScreen({
    super.key,
    this.gameType = GameType.wheel,
    this.groupId,
  });

  @override
  ConsumerState<CustomWheelScreen> createState() => _CustomWheelScreenState();
}

typedef PoolEditorScreen = CustomWheelScreen;

class _CustomWheelScreenState extends ConsumerState<CustomWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _previewSpinController;
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<int> _slots = [];

  @override
  void initState() {
    super.initState();
    // Roda mini 130dp berputar pelan 14 detik secara kontinu
    _previewSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _loadInitialPool();
  }

  Future<void> _loadInitialPool() async {
    if (widget.groupId != null) {
      final groupService = ref.read(groupServiceProvider);
      final group = groupService.getLocalGroup(widget.groupId!);
      if (group != null && mounted) {
        setState(() {
          _slots = List.from(group.effectiveSlots);
        });
        return;
      }
    }

    final repo = ref.read(gamePoolRepositoryProvider);
    final db = ref.read(databaseProvider);
    final pool = await repo.getPool(widget.gameType, db);
    if (mounted) {
      setState(() {
        _slots = List.from(pool);
      });
    }
  }

  @override
  void dispose() {
    _previewSpinController.dispose();
    _amountController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addSlot() {
    final maxSlots = widget.gameType == GameType.envelope ? 16 : 12;
    if (_slots.length >= maxSlots) {
      InAppToast.show(context, message: 'Maksimal $maxSlots nominal!');
      return;
    }

    final amount = RupiahFormatter.parse(_amountController.text);
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
      _amountController.clear();
    });
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.lightImpact();
  }

  void _removeSlot(int index) {
    final minSlots = widget.gameType == GameType.envelope ? 3 : 2;
    if (_slots.length <= minSlots) {
      InAppToast.show(context, message: 'Minimal $minSlots nominal!');
      return;
    }

    setState(() {
      _slots.removeAt(index);
    });
    SoundService.instance.play(Sfx.uiTap);
    HapticFeedback.selectionClick();
  }

  Future<void> _savePool() async {
    final minSlots = widget.gameType == GameType.envelope ? 3 : 2;
    final maxSlots = widget.gameType == GameType.envelope ? 16 : 12;

    if (_slots.length < minSlots || _slots.length > maxSlots) {
      InAppToast.show(context, message: 'Nominal harus antara $minSlots dan $maxSlots!');
      return;
    }

    SoundService.instance.play(Sfx.uiTap);

    if (widget.groupId != null) {
      final groupService = ref.read(groupServiceProvider);
      await groupService.updateGroupSlots(widget.groupId!, _slots);
      if (mounted) {
        InAppToast.show(context, message: 'Nominal roda grup berhasil disimpan!');
        context.pop();
      }
      return;
    }

    final repo = ref.read(gamePoolRepositoryProvider);
    final db = ref.read(databaseProvider);
    await repo.savePool(widget.gameType, _slots, db);

    if (mounted) {
      InAppToast.show(context, message: 'Pilihan nominal berhasil disimpan!');
      context.pop();
    }
  }

  String get _screenTitle {
    if (widget.groupId != null) {
      return 'Atur Roda Grup';
    }
    switch (widget.gameType) {
      case GameType.wheel:
        return 'Isi roda sendiri';
      case GameType.capsule:
        return 'Isi kapsul sendiri';
      case GameType.envelope:
        return 'Isi amplop sendiri';
      default:
        return 'Atur nominal pool';
    }
  }

  String get _nominalSectionTitle {
    if (widget.groupId != null) {
      return 'Nominal Roda Grup';
    }
    switch (widget.gameType) {
      case GameType.wheel:
        return 'Nominal di roda';
      case GameType.capsule:
        return 'Nominal di kapsul';
      case GameType.envelope:
        return 'Nominal di amplop';
      default:
        return 'Daftar nominal';
    }
  }

  String get _saveButtonText {
    if (widget.groupId != null) {
      return 'Simpan Roda Grup';
    }
    switch (widget.gameType) {
      case GameType.wheel:
        return 'Simpan roda';
      case GameType.capsule:
        return 'Simpan kapsul';
      case GameType.envelope:
        return 'Simpan amplop';
      default:
        return 'Simpan';
    }
  }

  Widget _buildNominalChip(PutarTheme t, int index, int amount, double chipWidth) {
    final slotColor = t.getWheelColor(index);

    return Semantics(
      button: true,
      label: 'Hapus nominal ${RupiahFormatter.formatCompact(amount)}',
      child: GestureDetector(
        onTap: () => _removeSlot(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: chipWidth,
          height: 48,
          decoration: BoxDecoration(
            color: slotColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: t.ink,
              width: t.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: t.ink,
                offset: t.smallShadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  RupiahFormatter.formatCompact(amount),
                  style: t.bodyLargeBold.copyWith(
                    fontSize: 16,
                    fontWeight: t.weightExtraBold,
                    color: t.ink,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CustomPaint(
                    painter: CustomCloseIconPainter(
                      color: t.ink,
                      strokeWidth: 2.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final double chipWidth =
        ((screenWidth - 40 - (10 * 2)) / 3).floorToDouble().clamp(90.0, 130.0);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Tombol Kembali + Judul
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Kembali',
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.uiTap);
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/');
                        }
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: t.ink,
                            width: t.borderWidth,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.ink,
                              offset: t.smallShadowOffset,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CustomPaint(
                            painter: CustomBackIconPainter(
                              color: t.ink,
                              strokeWidth: 3.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _screenTitle,
                      style: t.titleLarge.copyWith(
                        fontSize: 23,
                        fontWeight: t.weightExtraBold,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mini Preview Berputar 14s
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: t.ink,
                            offset: t.standardShadowOffset,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _previewSpinController,
                        builder: (context, child) {
                          final angle = _previewSpinController.value * 360.0;
                          return RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(130, 130),
                              painter: WheelPainter(
                                slots: _slots,
                                rotationAngleDegrees: angle,
                                cachedTextPainters: const {},
                                isMiniPreview: true,
                                theme: t,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Indikator jumlah nominal
                    Text(
                      '${_slots.length} dari maks. ${widget.gameType == GameType.envelope ? 16 : 12} pilihan nominal',
                      style: t.bodySmall.copyWith(
                        fontSize: 13,
                        fontWeight: t.weightBold,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bagian "Nominal di roda"
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _nominalSectionTitle,
                        style: t.titleMedium.copyWith(
                          fontSize: 18,
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Grid Chip rounded rectangle 3 kolom sewarna irisannya
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: List.generate(_slots.length, (index) {
                          return _buildNominalChip(t, index, _slots[index], chipWidth);
                        }),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Bagian "Tambah nominal"
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tambah nominal',
                        style: t.titleMedium.copyWith(
                          fontSize: 18,
                          fontWeight: t.weightExtraBold,
                          color: t.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Input kolom "Rp" + tombol Tambah
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(t.smallCardRadius),
                              border: Border.all(
                                color: t.ink,
                                width: t.borderWidth,
                              ),
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
                                Text(
                                  'Rp ',
                                  style: t.titleMedium.copyWith(
                                    color: t.danger,
                                    fontWeight: t.weightExtraBold,
                                    fontSize: 18,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _amountController,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: const [
                                      ThousandsSeparatorInputFormatter(),
                                    ],
                                    style: t.titleMedium.copyWith(
                                      color: t.ink,
                                      fontWeight: t.weightBold,
                                      fontSize: 17,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '75.000',
                                      hintStyle: TextStyle(
                                        color: t.textSecondary
                                            .withValues(alpha: 0.6),
                                        fontWeight: t.weightBold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    onSubmitted: (_) => _addSlot(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        StickerButton(
                          height: 56,
                          width: 100,
                          borderRadius: t.smallCardRadius,
                          borderWidth: t.borderWidth,
                          shadowOffset: t.smallShadowOffset,
                          text: 'Tambah',
                          backgroundColor: t.secondary,
                          textColor: t.ink,
                          onPressed: _addSlot,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Tombol Simpan di bagian bawah
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: StickerButton.large(
                text: _saveButtonText,
                backgroundColor: t.danger,
                textColor: t.ink,
                onPressed: _savePool,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

