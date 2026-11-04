import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../themes/app_colors.dart';

/// Six (or [length]) digit boxes that fill in as the person types, pastes or has
/// the code filled from an SMS. The boxes are only the picture: one invisible
/// text field sits over them and does the real work, so paste, delete and the
/// system's one-time-code suggestion behave like an ordinary field. The parent
/// owns [controller] (to read or clear the code).
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool hasError;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void didUpdateWidget(OtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    // Switching the field off (an expired code) drops its focus and the
    // keyboard; when it comes back — a new code was sent — take them back. After
    // the frame, because the text field itself is only unlocked by this build.
    if (!oldWidget.enabled && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final current = text.length.clamp(0, widget.length - 1);

    return Semantics(
      textField: true,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Box(
                    digit: i < text.length ? text[i] : '',
                    active: widget.enabled && _focus.hasFocus && i == current,
                    error: widget.hasError,
                    enabled: widget.enabled,
                  ),
                ),
              ],
            ],
          ),
          // Keep a real editable control over the boxes so Android can attach
          // its IME reliably. An Opacity(opacity: 0) wrapper can put the
          // RenderEditable on an off-screen compositing layer; on Android that
          // has caused taps not to reopen the keyboard and cursor fragments to
          // appear elsewhere on the page. The editable remains in the normal
          // layer here, while every visual part of it is transparent.
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: true,
              showCursor: false,
              cursorColor: Colors.transparent,
              enableInteractiveSelection: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1,
                height: 1,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.digit,
    required this.active,
    required this.error,
    required this.enabled,
  });

  final String digit;
  final bool active;
  final bool error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Color border = error
        ? colors.error
        : active
        ? AppColors.brandBlue
        : AppColors.chipBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: digit.isNotEmpty ? Colors.white : const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: active || error ? 1.5 : 1),
      ),
      child: Text(
        digit,
        style: TextStyle(
          color: enabled ? colors.onSurface : AppColors.slate400,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
