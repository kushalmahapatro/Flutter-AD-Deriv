import 'package:cli/app_command_runner.dart';

Future<int?> main(List<String> arguments) async {
  return AppCommandRunner('cli', 'CLI tool for managing files.').run(arguments);
}
