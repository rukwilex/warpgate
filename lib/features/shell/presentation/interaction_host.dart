import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warpgate/core/interaction/interaction_broker.dart';
import 'package:warpgate/core/routing/routes.dart';
import 'package:warpgate/core/util/format.dart';
import 'package:warpgate/design_system/design_system.dart';

class InteractionHost extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<InteractionHost> createState() => _InteractionHostState();
}

class _InteractionHostState extends ConsumerState<InteractionHost> {
  late final InteractionBroker _broker = ref.read(interactionBrokerProvider);
  final Queue<InteractionRequest<Object?>> _queue = Queue();
  StreamSubscription<InteractionRequest<Object?>>? _subscription;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _broker.attach();
    _subscription = _broker.requests.listen((request) {
      _queue.add(request);
      unawaited(_drain());
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _broker.detach();
    super.dispose();
  }

  Future<void> _drain() async {
    if (_showing) return;
    _showing = true;
    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();
      if (request.isAnswered) continue;
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) {
        request.dismiss();
        continue;
      }
      await _present(context, request);
      if (!request.isAnswered) request.dismiss();
    }
    _showing = false;
  }

  Future<void> _present(
    BuildContext context,
    InteractionRequest<Object?> request,
  ) => switch (request) {
    HostKeyRequest() => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HostKeyDialog(request: request),
    ),
    SecretRequest() => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SecretDialog(request: request),
    ),
    ConflictRequest() => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConflictDialog(request: request),
    ),
    ApprovalRequest() => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApprovalDialog(request: request),
    ),
  };

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Fact extends StatelessWidget {
  const new(this.label, this.value, {this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(bottom: space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.type.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          SizedBox(height: space.hair),
          SelectableText(value, style: context.type.mono.copyWith(color: tone)),
        ],
      ),
    );
  }
}

class HostKeyDialog extends StatelessWidget {
  const new({required this.request, super.key});

  final HostKeyRequest request;

  void _answer(BuildContext context, HostKeyVerdict verdict) {
    request.respond(verdict);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final changed = request.changed;
    return WgDialog(
      title: changed
          ? 'Host key changed for ${request.hostLabel}'
          : 'New host: ${request.hostLabel}',
      actions: [
        WgButton.ghost(
          label: 'Disconnect',
          onPressed: () => _answer(context, HostKeyVerdict.reject),
        ),
        WgButton(
          label: 'Trust once',
          onPressed: () => _answer(context, HostKeyVerdict.trustOnce),
        ),
        if (changed)
          WgButton.danger(
            label: 'Replace saved key',
            onPressed: () => _answer(context, HostKeyVerdict.trustAndSave),
          )
        else
          WgButton.primary(
            label: 'Trust and save',
            autofocus: true,
            onPressed: () => _answer(context, HostKeyVerdict.trustAndSave),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (changed) ...[
            const WgInlineMessage(
              tone: WgTone.negative,
              title: 'This does not match the key you saved before',
              message:
                  'The server may have been reinstalled, or someone may be intercepting the connection. '
                  'Confirm the new fingerprint with the server owner before you trust it.',
            ),
            SizedBox(height: context.space.lg),
          ] else ...[
            Text(
              'Warpgate has not connected to this server before. Compare the fingerprint with the one the server shows '
              'by running ssh-keygen -lf on its host key.',
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: context.space.lg),
          ],
          _Fact('Server', request.endpoint),
          _Fact('Key type', request.keyType),
          if (changed)
            _Fact(
              'Saved fingerprint',
              request.previousFingerprint!,
              tone: colors.textMuted,
            ),
          _Fact(
            changed ? 'New fingerprint' : 'Fingerprint',
            request.fingerprint,
            tone: changed ? colors.negative : null,
          ),
        ],
      ),
    );
  }
}

class SecretDialog extends StatefulWidget {
  const new({required this.request, super.key});

  final SecretRequest request;

  @override
  State<SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<SecretDialog> {
  final _controller = TextEditingController();
  bool _remember = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.request
      ..remember = _remember
      ..respond(_controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return WgDialog(
      title: request.title,
      actions: [
        WgButton.ghost(
          label: 'Cancel',
          onPressed: () {
            request.respond(null);
            Navigator.of(context).pop();
          },
        ),
        WgButton.primary(label: 'Continue', onPressed: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.message,
            style: context.type.mono.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: context.space.lg),
          WgTextField(
            controller: _controller,
            label: request.fieldLabel,
            obscure: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            autofillHints: const [AutofillHints.password],
          ),
          if (request.allowRemember)
            Padding(
              padding: EdgeInsets.only(top: context.space.sm),
              child: WgCheckRow(
                value: _remember,
                label: 'Save in secure storage',
                onChanged: (value) => setState(() => _remember = value),
              ),
            ),
        ],
      ),
    );
  }
}

class ConflictDialog extends StatefulWidget {
  const new({required this.request, super.key});

  final ConflictRequest request;

  @override
  State<ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<ConflictDialog> {
  bool _all = false;

  void _answer(ConflictResolution resolution) {
    widget.request.respond((resolution: resolution, applyToAll: _all));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final canResume =
        request.existingSize < request.incomingSize && request.existingSize > 0;
    return WgDialog(
      title: 'Replace ${request.path.split('/').last}?',
      actions: [
        WgButton.ghost(
          label: 'Skip',
          onPressed: () => _answer(ConflictResolution.skip),
        ),
        WgButton(
          label: 'Keep both',
          onPressed: () => _answer(ConflictResolution.rename),
        ),
        if (canResume)
          WgButton(
            label: 'Resume',
            onPressed: () => _answer(ConflictResolution.resume),
          ),
        WgButton.primary(
          label: 'Replace',
          onPressed: () => _answer(ConflictResolution.overwrite),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A file with this name already exists on ${request.targetLabel}.',
            style: context.type.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: context.space.lg),
          _Fact('Path', request.path),
          _Fact('Existing', Format.bytes(request.existingSize)),
          _Fact('Incoming', Format.bytes(request.incomingSize)),
          WgCheckRow(
            value: _all,
            label: 'Do this for every conflict in this transfer',
            onChanged: (value) => setState(() => _all = value),
          ),
        ],
      ),
    );
  }
}

class ApprovalDialog extends StatelessWidget {
  const new({required this.request, super.key});

  final ApprovalRequest request;

  void _answer(BuildContext context, {required bool approved}) {
    request.respond(approved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WgDialog(
      title: '${request.source} wants to ${request.action.toLowerCase()}',
      wide: true,
      actions: [
        WgButton.ghost(
          label: 'Deny',
          onPressed: () => _answer(context, approved: false),
        ),
        WgButton.primary(
          label: 'Allow',
          autofocus: true,
          onPressed: () => _answer(context, approved: true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fact('On', request.target),
          Text(
            'Exactly this',
            style: context.type.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          SizedBox(height: context.space.hair),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.space.md),
            decoration: BoxDecoration(
              color: context.colors.canvasDeep,
              borderRadius: context.radii.mdAll,
              border: Border.all(color: context.colors.hairline),
            ),
            child: SelectableText(request.detail, style: context.type.mono),
          ),
          SizedBox(height: context.space.md),
          Text(
            'You can turn off these prompts in Settings → Integrations.',
            style: context.type.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
