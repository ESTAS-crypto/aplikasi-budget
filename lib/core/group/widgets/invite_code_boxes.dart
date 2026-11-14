import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/putar_theme.dart';
import '../models/invite_code_model.dart';

/// Komponen Neo-Brutalist 6 Kotak Kode Undangan
/// Mendukung mode input interaktif (dengan kursor berkedip) dan mode tampilan read-only
class InviteCodeBoxes extends StatefulWidget {
  final String code;
  final ValueChanged<String>? onChanged;
  final bool isReadOnly;
  final bool autoFocus;

  const InviteCodeBoxes({
    super.key,
    required this.code,
    this.onChanged,
    this.isReadOnly = false,
    this.autoFocus = false,
  });

  @override
  State<InviteCodeBoxes> createState() => _InviteCodeBoxesState();
}

class _InviteCodeBoxesState extends State<InviteCodeBoxes> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _cursorVisible = true;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.code);
    _focusNode = FocusNode();

    if (!widget.isReadOnly) {
      _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted && _focusNode.hasFocus) {
          setState(() {
            _cursorVisible = !_cursorVisible;
          });
        }
      });

      if (widget.autoFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant InviteCodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != _controller.text) {
      _controller.text = widget.code;
    }
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChange(String val) {
    final sanitized = InviteCodeGenerator.normalize(val);
    if (sanitized.length <= 6) {
      if (sanitized != val) {
        _controller.value = TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
        );
      }
      widget.onChanged?.call(sanitized);
    } else {
      // Potong ke 6 karakter jika paste teks terlalu panjang
      final trimmed = sanitized.substring(0, 6);
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
      widget.onChanged?.call(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    final currentCode = widget.code.toUpperCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Hitung ukuran kotak responsif (maks 52px, muat di 320dp)
        final totalSpacing = 5 * 8.0;
        final availableWidth = constraints.maxWidth - totalSpacing;
        final boxSize = (availableWidth / 6).clamp(38.0, 52.0);

        return Semantics(
          label: widget.isReadOnly
              ? 'Kode undangan grup: ${currentCode.split('').join(' ')}'
              : 'Kotak kode undangan 6 karakter, terisi ${currentCode.length} dari 6 huruf',
          textField: !widget.isReadOnly,
          child: GestureDetector(
            onTap: widget.isReadOnly
                ? null
                : () {
                    _focusNode.requestFocus();
                  },
            onLongPress: widget.isReadOnly
                ? null
                : () async {
                    try {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text?.trim() ?? '';
                      if (text.isNotEmpty) {
                        _onTextChange(text);
                        HapticFeedback.lightImpact();
                      }
                    } catch (_) {}
                  },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hidden TextField untuk menerima input keyboard sistem & clipboard paste
                if (!widget.isReadOnly)
                  Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLength: 6,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.text,
                        onChanged: _onTextChange,
                      ),
                    ),
                  ),

                // Visual 6 kotak neo-brutalist dengan FittedBox anti-overflow
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isFilled = index < currentCode.length;
                        final isCurrentActive =
                            !widget.isReadOnly && _focusNode.hasFocus && index == currentCode.length;
                        final char = isFilled ? currentCode[index] : '';

                        return Container(
                          width: boxSize,
                          height: boxSize * 1.15,
                          margin: EdgeInsets.only(right: index < 5 ? 8.0 : 0.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isFilled
                                ? t.surface
                                : (isCurrentActive ? t.secondary.withValues(alpha: 0.35) : t.surface),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.ink,
                              width: isCurrentActive ? 3.0 : 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: t.ink,
                                offset: isCurrentActive ? const Offset(2, 3) : t.miniShadowOffset,
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: isFilled
                              ? Text(
                                  char,
                                  style: t.displayMedium.copyWith(
                                    fontSize: boxSize * 0.55,
                                    color: t.ink,
                                    fontWeight: t.weightExtraBold,
                                  ),
                                )
                              : (isCurrentActive && _cursorVisible
                                  ? Container(
                                      width: 2.5,
                                      height: boxSize * 0.5,
                                      color: t.ink,
                                    )
                                  : const SizedBox.shrink()),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

