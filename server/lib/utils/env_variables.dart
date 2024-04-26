import 'dart:io';

class EnvVariables {
  const EnvVariables._();

  static final String _host = Platform.environment['HOSTNAME'] ?? '';
  static final String _port = Platform.environment['PORT'] ?? '8080';

  static String get host => _host;
  static int get port => int.parse(_port);
  static String get url => Uri.http('$_host:$_port').toString();
}
