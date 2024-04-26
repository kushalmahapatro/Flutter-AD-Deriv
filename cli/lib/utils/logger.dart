import 'dart:async';
import 'dart:io';

enum LoggerLevel { normal, verbose }

class Logger {
  Logger();

  LoggerLevel level = LoggerLevel.normal;

  void error(String message) {
    stderr.writeln(message.red);
  }

  void log(String message, {bool emphasis = false}) {
    if (emphasis) {
      stdout.writeln(message.emphasized);
    } else {
      stdout.writeln(message);
    }
  }

  void verbose(String message) {
    if (level == LoggerLevel.verbose) {
      stdout.writeln(message);
    }
  }

  Progress progress({
    required String description,
    String? suffixMessage,
    int? total,
    String onDoneMessage = '',
    String beforeStartMessage = '',
  }) {
    return Progress(
      description: description,
      suffixMessage: suffixMessage,
      total: total,
      onDoneMessage: onDoneMessage,
      beforeStartMessage: beforeStartMessage,
    );
  }
}

class Progress {
  final String description;
  final String? suffixMessage;
  final int? total;
  final String onDoneMessage;
  final String beforeStartMessage;

  Progress({
    this.description = '',
    this.suffixMessage,
    this.total,
    this.onDoneMessage = '',
    this.beforeStartMessage = '',
  }) {
    _start();
  }

  int _completed = 0;
  double _percentage = 0;
  Timer? _timer;
  String _additionalMessage = '';

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), _timerCallback);
    Future.delayed(
      const Duration(milliseconds: 100),
      () => update(_percentage),
    );
  }

  void _timerCallback(timer) {
    if (_percentage == 100) {
      cancel();
    } else {
      _printProgress();
    }
  }

  void _start() {
    _printInitialMessage();
    _printProgress();
    _startTimer();
  }

  void update(
    double percentage, {
    int? completed,
    String additionalMessage = '',
  }) {
    if (!(_timer?.isActive ?? false)) {
      return;
    }

    _percentage = percentage;
    _completed = completed ?? 0;
    _additionalMessage = additionalMessage;
    _printProgress();

    if (_percentage == 100) {
      cancel();
    }
  }

  void cancel() {
    _timer?.cancel();
  }

  void _printInitialMessage() {
    stdout.writeln('');
    if (beforeStartMessage.isNotEmpty && _percentage == 0) {
      stdout.writeln(beforeStartMessage.emphasized);
    }
  }

  void _printProgress() {
    final String prefix = '$description [';
    final String time = _formattedTime(_timer?.tick ?? 0);
    final String remaining = _completed > 0 ? _completed.toString() : '---';
    final String total = this.total != null ? this.total.toString() : '---';
    final String additionalMessage =
        _additionalMessage.isNotEmpty ? '| $_additionalMessage ' : '';
    final String suffix =
        '] ${_percentage.toStringAsFixed(2)}% | $time | $remaining/$total ${suffixMessage ?? ""} $additionalMessage';
    int terminalColumn = 100;
    try {
      terminalColumn = stdout.terminalColumns;
    } catch (e) {
      terminalColumn = 100;
    }

    final int barLength = terminalColumn - prefix.length - suffix.length;
    final int progress = ((_percentage.floor() / 100) * barLength).round();
    String progressIndicator = ('#' * progress).red;
    String progressRemaining = ' ' * (barLength - progress);
    if (_percentage == 100) progressIndicator = ('#' * progress).green;
    final String progressBar = '$progressIndicator$progressRemaining';
    stdout.write("\r");
    stdout.write('$prefix$progressBar$suffix');

    if (_percentage == 100 && onDoneMessage.isNotEmpty) {
      stdout.writeln('\n$onDoneMessage'.emphasized);
    }
  }

  String _formattedTime(int time) {
    final int hour = (time / 3600).floor();
    final int minute = ((time / 3600 - hour) * 60).floor();
    final int second = ((((time / 3600 - hour) * 60) - minute) * 60).floor();

    final String setTime = [
      hour.toString().padLeft(2, "0"),
      minute.toString().padLeft(2, "0"),
      second.toString().padLeft(2, '0'),
    ].join(':');
    return setTime;
  }
}

extension StringExtensions on String {
  String get _bold => '\u001b[1m';
  String get _none => '\u001b[0m';
  String get _green => '\u001b[32m';
  String get _blue => '\u001b[34m';
  String get _red => '\u001b[31m';

  String get emphasized => '$_bold$this$_none';
  String get green => '$_green$this$_none';
  String get blue => '$_blue$this$_none';
  String get red => '$_red$this$_none';
}
