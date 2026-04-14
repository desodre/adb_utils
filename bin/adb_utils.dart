import 'package:adb_utils/adb_utils.dart';

/// CLI entry point — lists connected devices by default.
void main(List<String> arguments) async {
  final adb = AdbClient();

  try {
    final version = await adb.serverVersion();
    print('ADB server version: $version');

    final devices = await adb.deviceList();
    if (devices.isEmpty) {
      print('No devices connected.');
      return;
    }

    for (final d in devices) {
      print(d);
    }
  } on AdbError catch (e) {
    print('Error: $e');
  }
}
