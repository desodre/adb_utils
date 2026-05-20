import 'dart:async';
import 'dart:io';

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

/// Compatibility helper used by QA suites.
extension AdbClientListDevicesCompat on AdbClient {
  Future<List<DeviceInfo>> listDevices() => deviceList();
}

Future<AdbDevice> requireRealDevice() async {
  final adb = AdbClient();
  final devices = await adb.listDevices();
  if (devices.isEmpty) {
    markTestSkipped('Dispositivos não encontrados');
    throw StateError('No devices available for real_device suite');
  }

  final online = devices.where((d) => d.state == DeviceState.device).toList();
  if (online.isEmpty) {
    markTestSkipped('Nenhum dispositivo online encontrado.');
    return adb.device(serial: devices.first.serial);
  }

  for (final info in online) {
    final device = await adb.device(serial: info.serial);
    if (await isRealHardwareDevice(device)) {
      return device;
    }
  }

  markTestSkipped('Nenhum dispositivo físico encontrado (apenas emuladores).');
  return adb.device(serial: online.first.serial);
}

Future<List<AdbDevice>> requireAtLeastDevices(int minimum) async {
  final adb = AdbClient();
  final devices = await adb.listDevices();
  final online = devices.where((d) => d.state == DeviceState.device).toList();
  if (online.length < minimum) {
    markTestSkipped(
      'São necessários pelo menos $minimum dispositivos online; encontrados ${online.length}.',
    );
  }

  return Future.wait(online.map((d) => adb.device(serial: d.serial)));
}

Future<bool> isRealHardwareDevice(AdbDevice d) async {
  final qemu = (await d.shell('getprop ro.kernel.qemu')).trim();
  final model = (await d.shell('getprop ro.product.model')).toLowerCase();
  final fingerprint = (await d.shell(
    'getprop ro.build.fingerprint',
  )).toLowerCase();

  final isEmulatorLike =
      qemu == '1' ||
      model.contains('emulator') ||
      model.contains('sdk') ||
      model.contains('generic') ||
      fingerprint.contains('generic') ||
      d.serial.startsWith('emulator-');

  return !isEmulatorLike;
}

Future<bool> isAdbCliAvailable() async {
  try {
    final result = await Process.run('adb', ['version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> waitForDeviceOnline({
  required AdbClient adb,
  required String serial,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final devices = await adb.listDevices();
    final found = devices.any(
      (d) => d.serial == serial && d.state == DeviceState.device,
    );
    if (found) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw TimeoutException(
    'Device $serial did not return online within $timeout',
  );
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
