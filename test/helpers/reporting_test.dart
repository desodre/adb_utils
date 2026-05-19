import 'dart:convert';
import 'dart:io';

import 'package:adb_utils/src/reporting/html_reporter.dart';
import 'package:adb_utils/src/reporting/test_result.dart';
import 'package:test/test.dart' as t;

export 'package:test/test.dart' hide test;

const String _reportDirPath = 'logs/test-report';
const String _resultsPath = 'logs/test-report/results.jsonl';
const String _sessionPath = 'logs/test-report/session.json';
const String _lockPath = 'logs/test-report/report.lock';
const String _suitesDirPath = 'logs/test-report/suites';

String _suiteName = 'test-suite';
bool _configured = false;

/// Enables automatic HTML report generation for tests executed via `dart test`.
///
/// Call once in each test file, usually at the beginning of `main()`.
void configureHtmlReporting({required String suiteName}) {
  _suiteName = suiteName;
  if (_configured) {
    return;
  }
  _configured = true;

  t.setUpAll(_initSessionIfNeeded);
  t.tearDownAll(() async {
    await _markSuiteDone(_suiteName);
    await _generateHtmlReport();
  });
}

/// Wrapper around `package:test`'s [t.test] that records pass/fail evidence.
void test(
  Object? description,
  dynamic Function() body, {
  String? testOn,
  t.Timeout? timeout,
  Object? skip,
  dynamic tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  t.test(
    description,
    () async {
      final stopwatch = Stopwatch()..start();
      try {
        final result = body();
        if (result is Future) {
          await result;
        }

        await _appendResult(
          _ReportRecord(
            nome: description?.toString() ?? 'Unnamed test',
            categoria: _suiteName,
            duracaoMs: stopwatch.elapsedMilliseconds,
            passou: true,
          ),
        );
      } catch (e, stack) {
        await _appendResult(
          _ReportRecord(
            nome: description?.toString() ?? 'Unnamed test',
            categoria: _suiteName,
            duracaoMs: stopwatch.elapsedMilliseconds,
            passou: false,
            mensagemErro: e.toString(),
            stackTrace: stack.toString(),
          ),
        );
        rethrow;
      } finally {
        stopwatch.stop();
      }
    },
    testOn: testOn,
    timeout: timeout,
    skip: skip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
  );
}

Future<void> _initSessionIfNeeded() async {
  final reportDir = Directory(_reportDirPath);
  await reportDir.create(recursive: true);
  await Directory(_suitesDirPath).create(recursive: true);

  final lockFile = File(_lockPath);
  final raf = await lockFile.open(mode: FileMode.append);
  try {
    await raf.lock(FileLock.exclusive);

    final sessionFile = File(_sessionPath);
    int? sessionPid;
    if (await sessionFile.exists()) {
      final raw = await sessionFile.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      sessionPid = decoded['pid'] as int?;
    }

    if (sessionPid != pid) {
      final resultsFile = File(_resultsPath);
      if (await resultsFile.exists()) {
        await resultsFile.delete();
      }

      final suitesDir = Directory(_suitesDirPath);
      if (await suitesDir.exists()) {
        await for (final entity in suitesDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      await sessionFile.writeAsString(jsonEncode({'pid': pid}));
    }
  } finally {
    await raf.unlock();
    await raf.close();
  }
}

Future<void> _markSuiteDone(String suiteName) async {
  final marker = File('$_suitesDirPath/$suiteName.done');
  await marker.parent.create(recursive: true);
  await marker.writeAsString(DateTime.now().toIso8601String());
}

Future<void> _appendResult(_ReportRecord record) async {
  final file = File(_resultsPath);
  await file.parent.create(recursive: true);

  final raf = await file.open(mode: FileMode.append);
  try {
    await raf.lock(FileLock.exclusive);
    await raf.writeString('${jsonEncode(record.toJson())}\n');
  } finally {
    await raf.unlock();
    await raf.close();
  }
}

Future<void> _generateHtmlReport() async {
  final file = File(_resultsPath);
  if (!await file.exists()) {
    return;
  }

  final lines = await file.readAsLines();
  final results = <TestResult>[];

  for (final line in lines) {
    if (line.trim().isEmpty) {
      continue;
    }
    final row = jsonDecode(line) as Map<String, dynamic>;
    results.add(
      TestResult(
        nome: row['nome'] as String,
        categoria: row['categoria'] as String,
        duracao: Duration(milliseconds: row['duracaoMs'] as int),
        passou: row['passou'] as bool,
        mensagemErro: row['mensagemErro'] as String?,
        stackTrace: row['stackTrace'] as String?,
      ),
    );
  }

  final reporter = HtmlReporter(outputPath: 'report.html');
  await reporter.writeReport(results);
}

class _ReportRecord {
  const _ReportRecord({
    required this.nome,
    required this.categoria,
    required this.duracaoMs,
    required this.passou,
    this.mensagemErro,
    this.stackTrace,
  });

  final String nome;
  final String categoria;
  final int duracaoMs;
  final bool passou;
  final String? mensagemErro;
  final String? stackTrace;

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'categoria': categoria,
      'duracaoMs': duracaoMs,
      'passou': passou,
      'mensagemErro': mensagemErro,
      'stackTrace': stackTrace,
    };
  }
}
