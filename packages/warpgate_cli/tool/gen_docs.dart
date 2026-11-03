import 'dart:io';

import 'package:warpgate_cli/warpgate_cli.dart';

void main() {
  File('../../docs/CLI.md').writeAsStringSync(DocsGenerator.render());
  stdout.writeln('Wrote docs/CLI.md');
}
