import 'dart:convert';
import 'dart:io';

import 'package:warpgate_cli/src/output.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/util/format.dart';

class Prompter {
  new(this.output, {this.assumeYes = false});

  final Output output;
  final bool assumeYes;
  bool hostKeyRejected = false;

  bool get interactive => stdin.hasTerminal && stderr.hasTerminal;

  String? _readLine() => stdin.readLineSync(encoding: utf8);

  bool confirm(String question) {
    if (assumeYes) return true;
    if (!interactive) return false;
    stderr.write('$question [y/N] ');
    final answer = _readLine()?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }

  String? ask(String question) {
    if (!interactive) return null;
    stderr.write('$question ');
    return _readLine();
  }

  String? secret(String label) {
    if (!interactive) return null;
    stderr.write('$label: ');
    final echo = stdin.echoMode;
    try {
      stdin.echoMode = false;
      return _readLine();
    } finally {
      stdin.echoMode = echo;
      stderr.writeln();
    }
  }

  void attach(InteractionBroker broker) {
    broker.attach();
    broker.requests.listen(_answer);
  }

  void _answer(InteractionRequest<Object?> request) {
    switch (request) {
      case HostKeyRequest():
        final verdict = _hostKey(request);
        if (verdict == HostKeyVerdict.reject) hostKeyRejected = true;
        request.respond(verdict);
      case SecretRequest():
        if (output.json || !interactive) {
          request.dismiss();
        } else {
          stderr.writeln(request.message);
          request.respond(secret(request.fieldLabel));
        }
      case ConflictRequest():
        request.respond(_conflict(request));
      case ApprovalRequest():
        request.respond(
          confirm('${request.action} on ${request.target}: ${request.detail}?'),
        );
    }
  }

  HostKeyVerdict _hostKey(HostKeyRequest request) {
    if (request.changed) {
      output.raw(
        '${output.red('warning:')} the host key of ${request.endpoint} changed.\n'
        'Saved: ${request.previousFingerprint}\n'
        'Now:   ${request.fingerprint}\n',
      );
      if (!interactive || assumeYes) return HostKeyVerdict.reject;
      final answer = ask('Type "trust" to replace the saved key:');
      return answer?.trim() == 'trust'
          ? HostKeyVerdict.trustAndSave
          : HostKeyVerdict.reject;
    }
    if (!interactive) return HostKeyVerdict.reject;
    output.raw(
      'New host ${request.endpoint}\n${request.keyType} ${request.fingerprint}\n',
    );
    final answer = ask('Trust this key? [y/N/once]')?.trim().toLowerCase();
    return switch (answer) {
      'y' || 'yes' => HostKeyVerdict.trustAndSave,
      'once' => HostKeyVerdict.trustOnce,
      _ => HostKeyVerdict.reject,
    };
  }

  ConflictAnswer _conflict(ConflictRequest request) {
    if (!interactive) {
      return (resolution: ConflictResolution.overwrite, applyToAll: true);
    }
    stderr.writeln(
      '${request.path} exists on ${request.targetLabel}: '
      '${Format.bytes(request.existingSize)} there, ${Format.bytes(request.incomingSize)} incoming.',
    );
    final answer = ask(
      '[o]verwrite, [s]kip, [r]ename, r[e]sume. Capital letter applies to all:',
    )?.trim();
    final letter = answer == null || answer.isEmpty ? 's' : answer[0];
    final resolution = switch (letter.toLowerCase()) {
      'o' => ConflictResolution.overwrite,
      'r' => ConflictResolution.rename,
      'e' => ConflictResolution.resume,
      _ => ConflictResolution.skip,
    };
    return (
      resolution: resolution,
      applyToAll: letter != letter.toLowerCase(),
    );
  }
}
