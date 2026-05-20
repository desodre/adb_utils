@TestOn('vm')
@Tags(['device', 'real_device', 'all_possible'])
library;

import 'package:adb_utils/adb_utils.dart';

import '../helpers/adb_test_helpers.dart';
import '../helpers/reporting.dart';

int? _extractThermalStatus(String out) {
  final patterns = <RegExp>[
    RegExp(r'Thermal Status:\s*(\d+)', caseSensitive: false),
    RegExp(r'mStatus:\s*(\d+)', caseSensitive: false),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(out);
    if (m != null) {
      return int.tryParse(m.group(1)!);
    }
  }
  return null;
}

void main() {
  configureHtmlReporting(
    suiteName: 'integration/test_device_thermal_throttle_test.dart',
  );

  late AdbDevice d;

  setUpAll(() async {
    final devices = await AdbClient().listDevices();
    if (devices.isEmpty) {
      markTestSkipped('Dispositivos não encontrados');
    }
    d = await requireRealDevice();
  });

  group('Thermal throttling diagnostics', () {
    test(
      'logs warning on thermal stress but keeps test execution healthy',
      () async {
        final out = await d.shell('dumpsys thermalservice');
        final status = _extractThermalStatus(out);
        if (status == null) {
          markTestSkipped(
            'Could not parse thermal status on serial=${d.serial}',
          );
        }

        if (status! >= 4) {
          print(
            'WARNING: serial=${d.serial} thermal throttling status=$status '
            '(severe). Video agent tests may show degraded performance.',
          );
        }

        expect(status, inInclusiveRange(0, 6));
      },
    );
  });
}
