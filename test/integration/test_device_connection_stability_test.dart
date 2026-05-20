@TestOn('vm')
@Tags(['device', 'real_device', 'destructive'])
library;

import 'dart:io';

import 'package:adb_utils/adb_utils.dart';

import '../helpers/adb_test_helpers.dart';
import '../helpers/reporting.dart';

void main() {
  configureHtmlReporting(
    suiteName: 'integration/test_device_connection_stability_test.dart',
  );

  late AdbClient adb;
  late AdbDevice d;

  setUpAll(() async {
    final devices = await AdbClient().listDevices();
    if (devices.isEmpty) {
      markTestSkipped('Dispositivos não encontrados');
    }
    d = await requireRealDevice();
    adb = d.client;
    if (!await isAdbCliAvailable()) {
      markTestSkipped('adb CLI não disponível para simular queda de conexão.');
    }
  });

  group('ADB connection resilience', () {
    test(
      'detects disconnect and recovers startAgent after device returns',
      () async {
        final serial = d.serial;

        final kill = await Process.run('adb', ['kill-server']);
        if (kill.exitCode != 0) {
          markTestSkipped('Could not kill adb server: ${kill.stderr}');
        }

        await expectLater(() => d.getState(), throwsA(isA<Object>()));

        final start = await Process.run('adb', ['start-server']);
        if (start.exitCode != 0) {
          fail('Could not start adb server again: ${start.stderr}');
        }

        await waitForDeviceOnline(adb: adb, serial: serial);

        final recovered = await adb.device(serial: serial);
        await recovered.phantom.startAgent();
        final state = await recovered.getState();

        expect(state.trim(), equals('device'));
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
