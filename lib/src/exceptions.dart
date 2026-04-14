/// Thrown when the ADB server returns a FAIL response or an unexpected error occurs.
class AdbError implements Exception {
  AdbError(this.message);

  final String message;

  @override
  String toString() => 'AdbError: $message';
}

/// Thrown when a shell command or connection exceeds its timeout.
class AdbTimeout extends AdbError {
  AdbTimeout(super.message);

  @override
  String toString() => 'AdbTimeout: $message';
}

/// Thrown when `adb install` fails.
class AdbInstallError extends AdbError {
  AdbInstallError(super.message);

  @override
  String toString() => 'AdbInstallError: $message';
}
