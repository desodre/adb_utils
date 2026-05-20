/// Represents the result of one automated test execution.
class TestResult {
  const TestResult({
    required this.nome,
    required this.categoria,
    required this.duracao,
    required this.passou,
    this.mensagemErro,
    this.stackTrace,
    this.evidencias = const [],
  });

  final String nome;
  final String categoria;
  final Duration duracao;
  final bool passou;
  final String? mensagemErro;
  final String? stackTrace;
  final List<TestEvidence> evidencias;
}

class TestEvidence {
  const TestEvidence({
    required this.label,
    required this.path,
    required this.mediaType,
  });

  final String label;
  final String path;
  final String mediaType;
}
