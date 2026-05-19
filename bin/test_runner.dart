import 'dart:async';

import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  final runner = TestRunner();

  await runner.runTest('Conectar via Socket', 'Conectividade', () async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
  });

  await runner.runTest(
    'Buscar elemento no PhantomAgent',
    'UI Automation',
    () async {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      throw TimeoutException('Elemento nao encontrado no ecra');
    },
  );

  await runner.runTest('Parsing de resposta JSON', 'Parser', () async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    throw const FormatException('Resposta invalida: campo "nodes" ausente');
  });

  final reporter = HtmlReporter(outputPath: 'report.html');
  await reporter.writeReport(runner.resultados);
}
