/// Result of a shell command executed via `shell2` (v2 protocol).
class ShellResult {
  const ShellResult({
    required this.command,
    required this.returnCode,
    required this.output,
    this.stdout,
    this.stderr,
  });

  final String command;
  final int returnCode;

  /// Combined stdout + stderr (v1 protocol) or full output (v2 protocol).
  final String output;

  /// Stdout only — populated when using shell v2 protocol.
  final String? stdout;

  /// Stderr only — populated when using shell v2 protocol.
  final String? stderr;

  bool get isSuccess => returnCode == 0;

  @override
  String toString() =>
      'ShellResult(command: $command, returnCode: $returnCode)';
}
