import 'dart:io';

import 'package:logging/logging.dart';

typedef LogOutput = void Function(String line);

/// Configures global logging for adb_utils.
///
/// Call once in app startup to receive structured logs.
void configureAdbUtilsLogging({
  Level level = Level.INFO,
  bool includeTimestamp = true,
  LogOutput output = _defaultLogOutput,
}) {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    final timePrefix = includeTimestamp
        ? '${record.time.toIso8601String()} '
        : '';
    final errorPart = record.error == null ? '' : ' | error=${record.error}';
    final stackPart = record.stackTrace == null ? '' : '\n${record.stackTrace}';
    output(
      '$timePrefix[${record.level.name}] ${record.loggerName}: ${record.message}$errorPart$stackPart',
    );
  });
}

String truncateForLog(String value, {int maxChars = 2000}) {
  if (value.length <= maxChars) {
    return value;
  }
  return '${value.substring(0, maxChars)}... [truncated ${value.length - maxChars} chars]';
}

void _defaultLogOutput(String line) {
  stderr.writeln(line);
}
