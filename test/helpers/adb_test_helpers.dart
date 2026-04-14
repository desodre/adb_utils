import 'package:adb_utils/adb_utils.dart';
import 'package:test/test.dart';

/// Checks if the ADB server is reachable. Returns null on success, error
/// message on failure.
Future<String?> probeAdbServer({
  String host = '127.0.0.1',
  int port = 5037,
}) async {
  final adb = AdbClient(
    host: host,
    port: port,
    socketTimeout: const Duration(seconds: 3),
  );
  try {
    await adb.serverVersion();
    return null;
  } catch (e) {
    return e.toString();
  }
}

/// Tries to get the first connected device. Returns null if none available
/// or ADB server is not running.
Future<AdbDevice?> probeDevice({
  String host = '127.0.0.1',
  int port = 5037,
}) async {
  final adb = AdbClient(
    host: host,
    port: port,
    socketTimeout: const Duration(seconds: 3),
  );
  try {
    return await adb.device();
  } catch (_) {
    return null;
  }
}

/// Skips the current test if the ADB server is not reachable.
Future<AdbClient> requireAdbServer() async {
  final err = await probeAdbServer();
  if (err != null) {
    markTestSkipped('ADB server not available: $err');
  }
  return AdbClient();
}

/// Skips the current test if no device is connected.
Future<AdbDevice> requireDevice() async {
  final device = await probeDevice();
  if (device == null) {
    markTestSkipped('No device/emulator connected');
  }
  return device!;
}

/// Matcher that checks a string is a valid PNG (starts with PNG magic bytes).
const isPng = _PngMatcher();

class _PngMatcher extends Matcher {
  const _PngMatcher();

  static const _magic = [137, 80, 78, 71, 13, 10, 26, 10];

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! List<int> || item.length < 8) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (item[i] != _magic[i]) return false;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('a valid PNG byte sequence');
}
