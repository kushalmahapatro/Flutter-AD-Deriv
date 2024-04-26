import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli/commands/update_command.dart';
import 'package:cli/utils/logger.dart';

const String version = '0.0.1';

class AppCommandRunner extends CommandRunner<int> {
  Logger logger = Logger();
  AppCommandRunner(super.executableName, super.description) {
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show additional command output.',
      )
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the tool version.',
      );
    addCommand(UpdateCommand(logger: logger));
  }

  @override
  void printUsage() => logger.log(usage);

  @override
  Future<int?> run(Iterable<String> args) async {
    try {
      final ArgResults results = argParser.parse(args);
      bool verbose = false;

      // Process the parsed arguments.
      if (results.wasParsed('help')) {
        printUsage();
        return 0;
      }
      if (results.wasParsed('version')) {
        print('cli version: $version');
        return 0;
      }

      if (results.wasParsed('verbose')) {
        verbose = true;
      }

      // Act on the arguments provided.
      print('Positional arguments: ${results.rest}');
      if (verbose) {
        logger.level = LoggerLevel.verbose;
        logger.verbose('Verbose output enabled.');
      }

      return await runCommand(results);
    } on FormatException catch (e) {
      // Print usage information if an invalid argument was provided.
      logger.error(e.message);
      printUsage();
    } on UsageException catch (error) {
      logger.error('$error');
      return 0;
    }

    return 0;
  }
}
