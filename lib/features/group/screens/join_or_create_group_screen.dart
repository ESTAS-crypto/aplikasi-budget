import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/sticker_card.dart';
import '../../../core/widgets/sticker_snackbar.dart';
import '../../../core/group/models/invite_code_model.dart';
import '../../../core/group/services/group_auth_service.dart';
import '../../../core/group/services/group_service.dart';
import '../../../core/group/painters/group_icons_painter.dart';
import '../../../core/group/widgets/invite_code_boxes.dart';
import '../../../core/group/widgets/member_avatar.dart';
import '../../../core/group/widgets/scope_switcher.dart';
import '../../../core/utils/sound_service.dart';

/// Layar 16: Buat atau Gabung Grup
class JoinOrCreateGroupScreen extends ConsumerStatefulWidget {
  const JoinOrCreateGroupScreen({super.key});

  @override
  ConsumerState<JoinOrCreateGroupScreen> createState() => _JoinOrCreateGroupScreenState();
}

class _JoinOrCreateGroupScreenState extends ConsumerState<JoinOrCreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _inviteCode = '';
  int _selectedColorIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final authService = ref.read(groupAuthServiceProvider);
    final savedName = authService.displayName;
    if (savedName != null && savedName.isNotEmpty) {
      _nameController.text = savedName;
    }
    _selectedColorIndex = authService.colorIndex;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePasteCode() async {
    SoundService.instance.play(Sfx.uiTap);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';
      if (raw.isEmpty) {
        if (mounted) {
          showStickerSnackbar(context, message: 'Papan klip (clipboard) masih kosong');
        }
        return;
      }
      final normalized = InviteCodeGenerator.normalize(raw);
      if (normalized.isEmpty) {
        if (mounted) {
          showStickerSnackbar(context, message: 'Tidak ditemukan kode yang cocok di clipboard');
        }
        return;
      }
      final code = normalized.length > 6 ? normalized.substring(0, 6) : normalized;
      setState(() {
        _inviteCode = code;
      });
      HapticFeedback.lightImpact();
      if (mounted) {
        showStickerSnackbar(context, message: 'Kode berhasil ditempel: $code');
      }
    } catch (_) {
      if (mounted) {
        showStickerSnackbar(context, message: 'Gagal menempel kode dari clipboard');
      }
    }
  }

  Future<void> _handleCreateGroup() async {
    final groupName = _groupNameController.text.trim();
    final myName = _nameController.text.trim();

    if (!GroupAuthService.isValidDisplayName(myName)) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      _nameFocusNode.requestFocus();
      showStickerSnackbar(context, message: 'Isi nama tampilan kamu di bagian atas terlebih dahulu!');
      return;
    }

    if (groupName.isEmpty) {
      showStickerSnackbar(context, message: 'Masukkan nama grup terlebih dahulu');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groupService = ref.read(groupServiceProvider);
      final gid = await groupService.createGroup(
        groupName: groupName,
        creatorName: myName,
        colorIndex: _selectedColorIndex,
      );

      ref.read(activeGroupIdProvider.notifier).state = gid;
      ref.read(appScopeProvider.notifier).state = AppScope.grup;

      SoundService.instance.play(Sfx.winLolos);

      if (mounted) {
        showStickerSnackbar(context, message: '🎉 Grup "$groupName" berhasil dibuat!');
        context.pushReplacement('/group/invite/$gid');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        showStickerSnackbar(context, message: _errorMessage ?? 'Gagal membuat grup');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoinGroup() async {
    final myName = _nameController.text.trim();
    if (!GroupAuthService.isValidDisplayName(myName)) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      _nameFocusNode.requestFocus();
      showStickerSnackbar(context, message: 'Isi nama tampilan kamu di bagian atas terlebih dahulu!');
      return;
    }

    if (_inviteCode.length != 6) {
      showStickerSnackbar(context, message: 'Masukkan 6 karakter kode undangan');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groupService = ref.read(groupServiceProvider);
      final gid = await groupService.joinGroupByCode(
        rawCode: _inviteCode,
        memberName: myName,
        colorIndex: _selectedColorIndex,
      );

      ref.read(activeGroupIdProvider.notifier).state = gid;
      ref.read(appScopeProvider.notifier).state = AppScope.grup;

      SoundService.instance.play(Sfx.winLolos);

      if (mounted) {
        showStickerSnackbar(context, message: '🎉 Berhasil bergabung ke grup!');
        context.pushReplacement('/group/invite/$gid');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        showStickerSnackbar(context, message: _errorMessage ?? 'Gagal bergabung ke grup');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const CustomPaint(
            size: Size(22, 22),
            painter: CustomBackArrowPainter(color: AppColors.ink),
          ),
          onPressed: () {
            SoundService.instance.play(Sfx.uiTap);
            context.pop();
          },
        ),
        title: Text(
          'Grup Bersama',
          style: AppTypography.titleMedium.copyWith(color: AppColors.ink),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kartu Profil Anggota
              _buildProfileCard(),
              const SizedBox(height: 16),

              // Kartu 1: Buat Grup Baru
              _buildCreateGroupCard(),
              const SizedBox(height: 20),

              // Pemisah ATAU Neo-Brutalist
              _buildOrDivider(),
              const SizedBox(height: 20),

              // Kartu 2: Gabung Grup dengan Kode
              _buildJoinGroupCard(),
              const SizedBox(height: 16),

              // Catatan Koneksi Internet
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ink, width: 2.0),
                ),
                child: Row(
                  children: [
                    const CustomPaint(
                      size: Size(18, 18),
                      painter: CustomInfoCirclePainter(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Membuat atau bergabung ke grup membutuhkan koneksi internet untuk menyinkronkan data.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
              MemberAvatar(
                name: _nameController.text.isEmpty ? 'A' : _nameController.text,
                colorIndex: _selectedColorIndex,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama Tampilan Kamu',
                      style: AppTypography.bodyLargeBold.copyWith(fontSize: 14),
                    ),
                    Text(
                      'Terlihat oleh anggota grup lain',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            maxLength: 20,
            onChanged: (val) {
              setState(() {});
              if (val.trim().isNotEmpty) {
                ref.read(groupAuthServiceProvider).setDisplayName(val.trim());
              }
            },
            decoration: InputDecoration(
              hintText: 'Nama kamu (1-20 karakter)',
              counterText: '',
              filled: true,
              fillColor: AppColors.cream,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 2.5),
              ),
            ),
            style: AppTypography.bodyLargeBold.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'Pilih Warna Avatar:',
            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (index) {
                final isSelected = _selectedColorIndex == index;
                return GestureDetector(
                  onTap: () {
                    SoundService.instance.play(Sfx.uiTap);
                    setState(() {
                      _selectedColorIndex = index;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.getWheelColor(index),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: isSelected ? 2.8 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: AppColors.ink,
                                offset: Offset(1, 2),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                            child: CustomPaint(
                              size: Size(13, 13),
                              painter: CustomCheckPainter(color: AppColors.ink, strokeWidth: 2.2),
                            ),
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupCard() {
    return StickerCard(
      backgroundColor: AppColors.surface,
      borderColor: AppColors.ink,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.matahari,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: Text(
                  'BARU',
                  style: AppTypography.buttonSmall.copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buat Grup Baru',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _groupNameController,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: 'Contoh: Ngedate Seru / Makan Enak',
              counterText: '',
              filled: true,
              fillColor: AppColors.cream,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.ink, width: 2.5),
              ),
            ),
            style: AppTypography.bodyLargeBold.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 14),
          StickerButton(
            text: _isLoading ? 'Membuat...' : 'Buat Grup',
            backgroundColor: AppColors.matahari,
            onPressed: _isLoading ? null : _handleCreateGroup,
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: AppColors.ink,
            thickness: 2,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Text(
            'ATAU',
            style: AppTypography.buttonSmall.copyWith(fontSize: 11),
          ),
        ),
        const Expanded(
          child: Divider(
            color: AppColors.ink,
            thickness: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildJoinGroupCard() {
    final canJoin = _inviteCode.length == 6 && !_isLoading;

    return StickerCard(
      backgroundColor: AppColors.surface,
      borderColor: AppColors.ink,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gabung Grup Teman',
                      style: AppTypography.titleMedium.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ketik atau tempel 6 karakter kode:',
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _handlePasteCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.matahari,
                    borderRadius: BorderRadius.circular(8),
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
                      const CustomPaint(
                        size: Size(13, 13),
                        painter: CustomPastePainter(color: AppColors.ink),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Tempel',
                        style: AppTypography.buttonSmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InviteCodeBoxes(
            code: _inviteCode,
            onChanged: (val) {
              setState(() {
                _inviteCode = val;
              });
            },
          ),
          const SizedBox(height: 16),
          StickerButton(
            text: _isLoading ? 'Memeriksa...' : 'Gabung Grup',
            backgroundColor: AppColors.mint,
            onPressed: canJoin ? _handleJoinGroup : null,
          ),
        ],
      ),
    );
  }
}

