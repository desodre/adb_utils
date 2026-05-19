import 'test_result.dart';

/// Executes tests sequentially and stores each [TestResult].
class TestRunner {
  final List<TestResult> resultados = [];

  Future<void> runTest(
    String nome,
    String categoria,
    Future<void> Function() testLogic,
  ) async {
    final stopwatch = Stopwatch()..start();
    bool passou = false;
    String? mensagemErro;
    String? stackTrace;

    try {
      await testLogic();
      passou = true;
    } catch (e, stack) {
      mensagemErro = e.toString();
      stackTrace = stack.toString();
    } finally {
      stopwatch.stop();
    }

    resultados.add(
      TestResult(
        nome: nome,
        categoria: categoria,
        duracao: stopwatch.elapsed,
        passou: passou,
        mensagemErro: mensagemErro,
        stackTrace: stackTrace,
      ),
    );
  }
}
