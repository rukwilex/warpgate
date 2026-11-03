import 'dart:io';

import 'package:warpgate_cli/warpgate_cli.dart';

Future<void> main(List<String> arguments) async {
  final code = await runCli(arguments);
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
