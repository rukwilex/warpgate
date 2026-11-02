import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';

enum _Sticky { none, ctrl, alt }

class MobileKeyRow extends StatefulWidget {
  const new({required this.session, required this.onPaste, super.key});

  final TerminalSession session;
  final VoidCallback onPaste;

  @override
  State<MobileKeyRow> createState() => _MobileKeyRowState();
}

class _MobileKeyRowState extends State<MobileKeyRow> {
  _Sticky _sticky = _Sticky.none;

  static String ctrlOf(String data) {
    if (data.isEmpty) return data;
    final code = data.toUpperCase().codeUnitAt(0);
    if (code >= 0x40 && code <= 0x5F) {
      return String.fromCharCode(code - 0x40) + data.substring(1);
    }
    if (data[0] == ' ') return '\x00${data.substring(1)}';
    return data;
  }

  void _toggle(_Sticky value) {
    final next = _sticky == value ? _Sticky.none : value;
    setState(() => _sticky = next);
    widget.session.inputModifier = switch (next) {
      _Sticky.none => null,
      _Sticky.ctrl => (data) {
        _reset();
        return ctrlOf(data);
      },
      _Sticky.alt => (data) {
        _reset();
        return '\x1b$data';
      },
    };
  }

  void _reset() {
    if (mounted) setState(() => _sticky = _Sticky.none);
  }

  void _send(String sequence) {
    final modifier = widget.session.inputModifier;
    widget.session.inputModifier = null;
    final data = modifier == null ? sequence : modifier(sequence);
    widget.session.send(data);
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final keys =
        <(String label, String semantic, VoidCallback action, bool active)>[
          ('Esc', 'Escape', () => _send('\x1b'), false),
          ('Tab', 'Tab', () => _send('\t'), false),
          (
            'Ctrl',
            'Control, sticky',
            () => _toggle(_Sticky.ctrl),
            _sticky == _Sticky.ctrl,
          ),
          (
            'Alt',
            'Alt, sticky',
            () => _toggle(_Sticky.alt),
            _sticky == _Sticky.alt,
          ),
          ('←', 'Left arrow', () => _send('\x1b[D'), false),
          ('↑', 'Up arrow', () => _send('\x1b[A'), false),
          ('↓', 'Down arrow', () => _send('\x1b[B'), false),
          ('→', 'Right arrow', () => _send('\x1b[C'), false),
          ('|', 'Pipe', () => _send('|'), false),
          ('~', 'Tilde', () => _send('~'), false),
          ('/', 'Slash', () => _send('/'), false),
          ('-', 'Dash', () => _send('-'), false),
        ];
    return Container(
      height: context.sizes.keyRow + context.space.sm,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.space.xs,
          vertical: context.space.xs,
        ),
        children: [
          for (final (label, semantic, action, active) in keys)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.space.hair),
              child: WgPressable(
                semanticLabel: semantic,
                toggled: label == 'Ctrl' || label == 'Alt' ? active : null,
                onPressed: action,
                builder: (context, state) => Container(
                  constraints: BoxConstraints(
                    minWidth: context.sizes.touchTarget,
                    minHeight: context.sizes.touchTarget,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: context.space.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? colors.accentWash
                        : (state.pressed ? colors.pressed : colors.raised),
                    borderRadius: context.radii.smAll,
                    border: Border.all(
                      color: active ? colors.accent : colors.hairline,
                    ),
                  ),
                  child: Text(
                    label,
                    style: context.type.mono.copyWith(
                      color: active ? colors.accentInk : colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.space.hair),
            child: WgIconButton(
              icon: WgIcons.paste,
              label: 'Paste',
              onPressed: widget.onPaste,
            ),
          ),
        ],
      ),
    );
  }
}
