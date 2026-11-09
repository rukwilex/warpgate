import 'package:flutter/material.dart';
import 'package:warpgate/design_system/design_system.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';

class TerminalNoticeBanner extends StatelessWidget {
  const new({required this.session, super.key});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: session.notice,
    builder: (context, notice, _) => notice == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.all(context.space.sm),
            child: WgInlineMessage(
              tone: WgTone.caution,
              message: notice,
              action: WgIconButton(
                icon: WgIcons.close,
                label: 'Dismiss',
                compact: true,
                onPressed: () => session.notice.value = null,
              ),
            ),
          ),
  );
}
