import 'dart:async';
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
const String _tempEvidenceDirName = 'adb_utils_test_evidence';

String _suiteName = 'test-suite';
bool _configured = false;
final Object _evidenceZoneKey = Object();
int _evidenceCounter = 0;

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
      final evidencias = <_ReportEvidence>[];
      try {
        await runZoned(() async {
          final result = body();
          if (result is Future) {
            await result;
          }
        }, zoneValues: {_evidenceZoneKey: evidencias});

        await _appendResult(
          _ReportRecord(
            nome: description?.toString() ?? 'Unnamed test',
            categoria: _suiteName,
            duracaoMs: stopwatch.elapsedMilliseconds,
            passou: true,
            evidencias: evidencias,
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
            evidencias: evidencias,
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

/// Saves binary evidence into a temporary file and links it to the current test.
Future<File> addTestEvidenceBytes({
  required String label,
  required List<int> bytes,
  required String extension,
  required String mediaType,
}) async {
  final evidencias = Zone.current[_evidenceZoneKey];
  if (evidencias is! List<_ReportEvidence>) {
    throw StateError(
      'addTestEvidenceBytes must be called inside reporting.test body.',
    );
  }

  final safeExt = extension
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .toLowerCase();
  final safeLabel = _sanitizeFilePart(label);
  final id =
      '${DateTime.now().millisecondsSinceEpoch}_${pid}_${_evidenceCounter++}';
  final fileName = '$id-$safeLabel${safeExt.isEmpty ? '' : '.$safeExt'}';

  final tempDir = Directory(
    '${Directory.systemTemp.path}/$_tempEvidenceDirName',
  );
  await tempDir.create(recursive: true);

  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  evidencias.add(
    _ReportEvidence(label: label, path: file.path, mediaType: mediaType),
  );
  return file;
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
      final raw = (await sessionFile.readAsString()).trim();
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final pidValue = decoded['pid'];
            if (pidValue is int) {
              sessionPid = pidValue;
            }
          }
        } on FormatException {
          sessionPid = null;
        }
      }
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
    await raf.setPosition(await raf.length());
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

    Map<String, dynamic> row;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      row = decoded;
    } on FormatException {
      continue;
    }

    final nome = row['nome'];
    final categoria = row['categoria'];
    final duracaoMs = row['duracaoMs'];
    final passou = row['passou'];
    if (nome is! String ||
        categoria is! String ||
        duracaoMs is! int ||
        passou is! bool) {
      continue;
    }

    results.add(
      TestResult(
        nome: nome,
        categoria: categoria,
        duracao: Duration(milliseconds: duracaoMs),
        passou: passou,
        mensagemErro: row['mensagemErro'] as String?,
        stackTrace: row['stackTrace'] as String?,
        evidencias: _parseEvidencias(row['evidencias']),
      ),
    );
  }

  final reporter = HtmlReporter(outputPath: 'report.html');
  await reporter.writeReport(results);
}

List<TestEvidence> _parseEvidencias(dynamic raw) {
  if (raw is! List) {
    return const [];
  }

  final parsed = <TestEvidence>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }

    final label = item['label'];
    final path = item['path'];
    final mediaType = item['mediaType'];
    if (label is! String || path is! String || mediaType is! String) {
      continue;
    }

    parsed.add(TestEvidence(label: label, path: path, mediaType: mediaType));
  }
  return parsed;
}

String _sanitizeFilePart(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  if (sanitized.isEmpty) {
    return 'evidence';
  }
  return sanitized;
}

class _ReportRecord {
  const _ReportRecord({
    required this.nome,
    required this.categoria,
    required this.duracaoMs,
    required this.passou,
    this.mensagemErro,
    this.stackTrace,
    this.evidencias = const [],
  });

  final String nome;
  final String categoria;
  final int duracaoMs;
  final bool passou;
  final String? mensagemErro;
  final String? stackTrace;
  final List<_ReportEvidence> evidencias;

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'categoria': categoria,
      'duracaoMs': duracaoMs,
      'passou': passou,
      'mensagemErro': mensagemErro,
      'stackTrace': stackTrace,
      'evidencias': evidencias.map((e) => e.toJson()).toList(),
    };
  }
}

class _ReportEvidence {
  const _ReportEvidence({
    required this.label,
    required this.path,
    required this.mediaType,
  });

  final String label;
  final String path;
  final String mediaType;

  Map<String, String> toJson() {
    return {'label': label, 'path': path, 'mediaType': mediaType};
  }
}
