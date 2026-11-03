import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate/features/sftp/presentation/path_bar.dart';
import 'package:warpgate/features/terminal/data/terminal_session.dart';

void main() {
  test('OSC 7 with BEL or ST gives the last folder', () {
    expect(
      FolderTracking.parseOsc7('x\x1b]7;file://host/home/me\x07y'),
      '/home/me',
    );
    expect(
      FolderTracking.parseOsc7(
        '\x1b]7;file://h/a\x1b\\ text \x1b]7;file://h/srv/my%20site\x1b\\',
      ),
      '/srv/my site',
    );
    expect(FolderTracking.parseOsc7('plain output'), isNull);
  });

  test('lsof output gives the cwd line', () {
    expect(
      FolderTracking.parseLsof('p123\nfcwd\nn/Users/me/src\n'),
      '/Users/me/src',
    );
  });

  test('proc script looks for the pane variable', () {
    final script = FolderTracking.procScript('abc');
    expect(script, contains("'LC_WARPGATE_PANE=abc'"));
    expect(script, contains('readlink /proc/'));
  });

  test('install script appends the hook once', () {
    final script = FolderTracking.installScript(FolderShell.zsh);
    expect(script, contains(r'$HOME/.zshrc'));
    expect(script, contains('grep -q __wg_osc7'));
    expect(FolderShell.parse('bash'), FolderShell.bash);
    expect(FolderShell.parse('tcsh'), isNull);
  });

  group('path completion', () {
    const folders = ['src', 'srv', 'Spool', 'bin'];

    test('splits the folder from the typed name', () {
      expect(PathCompletion.split('/var/lo', p.posix), ('/var', 'lo'));
      expect(PathCompletion.split('/va', p.posix), ('/', 'va'));
      expect(PathCompletion.split('docs', p.posix), ('', 'docs'));
    });

    test('a single match completes with a trailing slash', () {
      expect(PathCompletion.complete('/x/bi', folders, p.posix), '/x/bin/');
    });

    test('several matches complete to the shared prefix', () {
      expect(PathCompletion.complete('/x/s', folders, p.posix), '/x/sr');
      expect(PathCompletion.complete('/x/sr', folders, p.posix), isNull);
    });

    test('matching falls back to case-insensitive', () {
      expect(PathCompletion.matches(folders, 'sp'), ['Spool']);
      expect(PathCompletion.matches(folders, 'sr'), ['src', 'srv']);
    });
  });
}
