import 'dart:io';

import 'package:cli/src/commands/check_command.dart';

Future<void> main(List<String> arguments) async {
  // Deliberately minimal contract for now: `fluttercheck check [path]`
  // only. The other commands sketched in the project doc (analyze,
  // fix, verify) aren't created yet — their exact contract hasn't
  // been decided (see the project doc's section on the CLI).
  if (arguments.isEmpty || arguments.first != 'check') {
    stderr.writeln('Usage: fluttercheck check [path]');
    exit(64); // EX_USAGE
  }

  final path = arguments.length > 1 ? arguments[1] : Directory.current.path;
  final exitCode = await CheckCommand().run(path);
  exit(exitCode);
}
