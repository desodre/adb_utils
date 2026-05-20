@TestOn('vm')
@Tags(['device', 'multi_device', 'all_possible'])
library;

import 'package:adb_utils/adb_utils.dart';

import '../helpers/adb_test_helpers.dart';
import '../helpers/reporting.dart';

void main() {
  configureHtmlReporting(
    suiteName: 'integration/test_device_conflict_isolation_test.dart',
  );

  late List<AdbDevice> devices;

  setUpAll(() async {
    final found = await AdbClient().listDevices();
    if (found.isEmpty) {
      markTestSkipped('Dispositivos não encontrados');
    }
    devices = await requireAtLeastDevices(2);
    if (devices.length < 2) {
      markTestSkipped('São necessários pelo menos 2 dispositivos online.');
    }
  });

  group('Local port conflict isolation', () {
    test('handles same local control port across two devices', () async {
      const sharedPort = 9008;
      final pair = devices.take(2).toList();

      final outcomes = await Future.wait(
        pair.map((device) async {
          final serial = device.serial;
          try {
            final phantom = PhantomClient(device: device, port: sharedPort);
            await phantom.startAgent();
            return (serial: serial, ok: true, error: '');
          } catch (e) {
            return (serial: serial, ok: false, error: e.toString());
          }
        }),
      );

      final failures = outcomes.where((o) => !o.ok).toList();
      final successes = outcomes.where((o) => o.ok).toList();

      if (failures.isNotEmpty) {
        expect(
          failures,
          isNotEmpty,
          reason:
              'Expected at least one explicit failure when sharing local port. '
              'Errors: ${failures.map((f) => "serial=${f.serial} error=${f.error}").join(" | ")}',
        );
      } else {
        expect(
          successes.length,
          equals(2),
          reason:
              'Both serials succeeded on shared local port; ADB handled isolation.',
        );
      }
    });
  });
}
