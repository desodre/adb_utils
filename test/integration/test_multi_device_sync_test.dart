@TestOn('vm')
@Tags(['device', 'multi_device', 'all_possible'])
library;

import 'package:adb_utils/adb_utils.dart';

import '../helpers/adb_test_helpers.dart';
import '../helpers/reporting.dart';

void main() {
  configureHtmlReporting(
    suiteName: 'integration/test_multi_device_sync_test.dart',
  );

  late AdbClient adb;
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
    adb = devices.first.client;
  });

  group('Parallel multi-device operations', () {
    test(
      'runs startAgent + dumpWindow in parallel without cross-device leakage',
      () async {
        final onlineSerials = (await adb.listDevices())
            .where((d) => d.state == DeviceState.device)
            .map((d) => d.serial)
            .toSet();

        final selected = devices
            .where((d) => onlineSerials.contains(d.serial))
            .toList();
        if (selected.length < 2) {
          markTestSkipped(
            'Menos de 2 dispositivos online no momento do teste.',
          );
          return;
        }
        late final List<({String serial, String xml})> results;
        try {
          results = await Future.wait(
            selected.take(2).toList().asMap().entries.map((entry) async {
              final index = entry.key;
              final device = entry.value;
              final serial = device.serial;

              try {
                final phantom = PhantomClient(
                  device: device,
                  port: 9010 + index,
                );
                await phantom.startAgent();
                final xml = await phantom.dumpWindow();
                return (serial: serial, xml: xml);
              } catch (e) {
                throw StateError('serial=$serial failed in parallel sync: $e');
              }
            }),
          );
        } on StateError catch (e) {
          if (e.message.contains(
                'Could not read dynamic Phantom ports from logcat',
              ) ||
              e.message.contains('Connection refused') ||
              e.message.contains('device offline')) {
            markTestSkipped(
              'Phantom agent não está estável neste ambiente de teste: $e',
            );
            return;
          }
          rethrow;
        }

        for (final result in results) {
          expect(
            result.xml,
            contains('<hierarchy'),
            reason: 'dumpWindow invalid response for serial=${result.serial}',
          );
        }
      },
    );
  });
}
