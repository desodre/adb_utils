/// Represents the result of one automated test execution.
class TestResult {
  const TestResult({
    required this.nome,
    required this.categoria,
    required this.duracao,
    required this.passou,
    this.mensagemErro,
    this.stackTrace,
  });

  final String nome;
  final String categoria;
  final Duration duracao;
  final bool passou;
  final String? mensagemErro;
  final String? stackTrace;
}
