import 'dart:convert';
import 'dart:io';

import 'test_result.dart';

/// Generates an HTML report from a collection of [TestResult].
class HtmlReporter {
  HtmlReporter({this.outputPath = 'report.html'});

  final String outputPath;
  final HtmlEscape _htmlEscape = const HtmlEscape(HtmlEscapeMode.element);

  Future<void> writeReport(List<TestResult> results) async {
    final total = results.length;
    final passaram = results.where((result) => result.passou).length;
    final falharam = total - passaram;
    final tempoTotal = results.fold(
      Duration.zero,
      (acc, item) => acc + item.duracao,
    );

    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="pt-BR">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('<title>Relatorio de Testes</title>')
      ..writeln('<style>')
      ..writeln(_buildCss())
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main class="container">')
      ..writeln('<h1>Relatorio de Execucao de Testes</h1>')
      ..writeln('<section class="summary-grid">')
      ..writeln(_summaryCard('Total', '$total'))
      ..writeln(_summaryCard('Passaram', '$passaram'))
      ..writeln(_summaryCard('Falharam', '$falharam'))
      ..writeln(_summaryCard('Tempo Total', _formatDuration(tempoTotal)))
      ..writeln('</section>')
      ..writeln('<section class="table-wrapper">')
      ..writeln('<table>')
      ..writeln('<thead>')
      ..writeln(
        '<tr><th>Nome</th><th>Categoria</th><th>Duracao</th><th>Status</th></tr>',
      )
      ..writeln('</thead>')
      ..writeln('<tbody>');

    for (final result in results) {
      final statusClass = result.passou ? 'passed' : 'failed';
      final statusLabel = result.passou ? 'Sucesso' : 'Falha';

      buffer
        ..writeln('<tr class="result-row $statusClass">')
        ..writeln('<td>${_escape(result.nome)}</td>')
        ..writeln('<td>${_escape(result.categoria)}</td>')
        ..writeln('<td>${_formatDuration(result.duracao)}</td>')
        ..writeln(
          '<td><span class="badge $statusClass">$statusLabel</span></td>',
        )
        ..writeln('</tr>');

      if (!result.passou) {
        final mensagemErro = result.mensagemErro ?? 'Sem mensagem de erro';
        final stackTrace = result.stackTrace ?? 'Sem stack trace';
        final failureContent =
            'Mensagem:\n$mensagemErro\n\nStack Trace:\n$stackTrace';

        buffer
          ..writeln('<tr class="failure-details-row">')
          ..writeln('<td colspan="4">')
          ..writeln('<div class="failure-panel">')
          ..writeln('<h3>Evidencia de Falha</h3>')
          ..writeln('<pre><code>${_escape(failureContent)}</code></pre>')
          ..writeln('</div>')
          ..writeln('</td>')
          ..writeln('</tr>');
      }
    }

    buffer
      ..writeln('</tbody>')
      ..writeln('</table>')
      ..writeln('</section>')
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');

    final outputFile = File(outputPath);
    await outputFile.writeAsString(buffer.toString());
  }

  String _escape(String value) => _htmlEscape.convert(value);

  String _summaryCard(String label, String value) {
    return '''
<article class="summary-card">
  <p class="summary-label">$label</p>
  <p class="summary-value">$value</p>
</article>
''';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(
      3,
      '0',
    );
    return '$minutes:$seconds.$milliseconds';
  }

  String _buildCss() {
    return '''
:root {
  color-scheme: dark;
  --bg: #0d1117;
  --panel: #161b22;
  --panel-border: #30363d;
  --text: #e6edf3;
  --muted: #8b949e;
  --ok-bg: #1f6feb22;
  --ok-text: #3fb950;
  --fail-bg: #da363322;
  --fail-text: #ff7b72;
}
* {
  box-sizing: border-box;
}
body {
  margin: 0;
  padding: 24px;
  font-family: Inter, Segoe UI, Roboto, sans-serif;
  background: var(--bg);
  color: var(--text);
}
.container {
  max-width: 1080px;
  margin: 0 auto;
}
h1 {
  margin-bottom: 20px;
  font-size: 1.7rem;
}
.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}
.summary-card {
  background: var(--panel);
  border: 1px solid var(--panel-border);
  border-radius: 12px;
  padding: 14px;
}
.summary-label {
  margin: 0;
  color: var(--muted);
  font-size: 0.85rem;
}
.summary-value {
  margin: 8px 0 0;
  font-size: 1.4rem;
  font-weight: 700;
}
.table-wrapper {
  background: var(--panel);
  border: 1px solid var(--panel-border);
  border-radius: 12px;
  overflow: hidden;
}
table {
  width: 100%;
  border-collapse: collapse;
}
th, td {
  text-align: left;
  padding: 12px 14px;
  border-bottom: 1px solid var(--panel-border);
  vertical-align: top;
}
thead th {
  color: var(--muted);
  font-weight: 600;
  letter-spacing: 0.02em;
}
.result-row:hover {
  background: #1a212b;
}
.badge {
  display: inline-block;
  border-radius: 999px;
  padding: 3px 10px;
  font-size: 0.8rem;
  font-weight: 600;
}
.badge.passed {
  background: var(--ok-bg);
  color: var(--ok-text);
}
.badge.failed {
  background: var(--fail-bg);
  color: var(--fail-text);
}
.failure-details-row td {
  padding-top: 0;
}
.failure-panel {
  background: #3a0e11;
  border: 1px solid #8f2d33;
  border-radius: 10px;
  margin: 8px 0 14px;
  padding: 10px;
}
.failure-panel h3 {
  margin: 0 0 8px;
  color: #ffb3b3;
  font-size: 0.95rem;
}
.failure-panel pre {
  margin: 0;
  background: #220608;
  border: 1px solid #6b2329;
  border-radius: 8px;
  padding: 10px;
  overflow-x: auto;
}
.failure-panel code {
  color: #ffd7d5;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  white-space: pre;
}
''';
  }
}
