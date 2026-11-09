
import 'package:warpgate_core/features/keys/data/key_codec.dart';

enum FolderHookResult { installed, unsupported, failed }

enum FolderShell {
  bash('~/.bashrc'),
  zsh('~/.zshrc'),
  fish('~/.config/fish/conf.d/warpgate.fish');

  new(this.rcFile);

  final String rcFile;

  static FolderShell? parse(String name) =>
      values.where((shell) => shell.name == name).firstOrNull;

  String get hook => switch (this) {
    FolderShell.bash => r'__wg_osc7() { printf "\033]7;file://%s%s\033\\" "${HOSTNAME:-$(hostname)}" "$PWD"; }; [[ "$PROMPT_COMMAND" == *__wg_osc7* ]] || PROMPT_COMMAND="__wg_osc7${PROMPT_COMMAND:+;$PROMPT_COMMAND}"',
    FolderShell.zsh => r'__wg_osc7() { printf "\033]7;file://%s%s\033\\" "$HOST" "$PWD"; }; autoload -Uz add-zsh-hook && add-zsh-hook precmd __wg_osc7',
    FolderShell.fish => r'function __wg_osc7 --on-event fish_prompt; printf "\e]7;file://%s%s\e\\" (hostname) $PWD; end',
  };
}

abstract final class FolderTracking {
  static const paneVariable = 'LC_WARPGATE_PANE';

  static final _osc7 = RegExp(
    r'\x1b\]7;file://[^/\x07\x1b]*(/[^\x07\x1b]*)(?:\x07|\x1b\\)',
  );

  static String? parseOsc7(String data) {
    final matches = _osc7.allMatches(data);
    if (matches.isEmpty) return null;
    final raw = matches.last.group(1)!;
    try {
      return Uri.decodeComponent(raw);
    } on Object {
      return raw;
    }
  }

  static String? parseLsof(String output) {
    for (final line in output.split('\n')) {
      if (line.startsWith('n/')) return line.substring(1);
    }
    return null;
  }

  static String procScript(String paneId) {
    final needle = KeyCodec.shellQuote('$paneVariable=$paneId');
    const find = '/proc/[0-9]*/environ 2>/dev/null | cut -d/ -f3); ';
    const pick =
        r'for p in $ids; do pp=$(cut -d" " -f4 /proc/$p/stat 2>/dev/null); '
        r'case " $ids " in *" $pp "*) ;; *) readlink /proc/$p/cwd; exit 0;; esac; done';
    return '${r'ids=$(grep -lzx '}$needle $find$pick';
  }

  static String installScript(FolderShell shell) {
    final rc = shell.rcFile.replaceFirst('~', r'$HOME');
    final line = KeyCodec.shellQuote(shell.hook);
    return 'mkdir -p "\$(dirname "$rc")" && touch "$rc" && '
        '(grep -q __wg_osc7 "$rc" || printf "\\n%s\\n" $line >> "$rc")';
  }
}
