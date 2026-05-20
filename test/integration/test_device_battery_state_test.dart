@TestOn('vm')
@Tags(['device', 'real_device', 'all_possible'])
library;

import 'package:adb_utils/adb_utils.dart';

import '../helpers/adb_test_helpers.dart';
import '../helpers/reporting.dart';

Map<String, String> _parseDumpsysBattery(String raw) {
  final parsed = <String, String>{};
  for (final line in raw.split('\n')) {
    final idx = line.indexOf(':');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim().toLowerCase();
    final value = line.substring(idx + 1).trim();
    parsed[key] = value;
  }
  return parsed;
}

void main() {
  configureHtmlReporting(
    suiteName: 'integration/test_device_battery_state_test.dart',
  );

  late AdbDevice d;

  setUpAll(() async {
    final devices = await AdbClient().listDevices();
    if (devices.isEmpty) {
      markTestSkipped('Dispositivos não encontrados');
    }
    d = await requireRealDevice();
  });

  group('Hardware battery sensor sanity', () {
    test('dumpsys battery returns physically plausible values', () async {
      final out = await d.shell('dumpsys battery');
      final battery = _parseDumpsysBattery(out);

      final level = int.tryParse(battery['level'] ?? '');
      final voltageMv = int.tryParse(battery['voltage'] ?? '');
      final tempTenthsC = int.tryParse(battery['temperature'] ?? '');

      expect(level, isNotNull, reason: 'Battery level missing: ${d.serial}');
      expect(
        voltageMv,
        isNotNull,
        reason: 'Battery voltage missing: ${d.serial}',
      );
      expect(
        tempTenthsC,
        isNotNull,
        reason: 'Battery temperature missing: ${d.serial}',
      );

      expect(
        level!,
        inInclusiveRange(0, 100),
        reason: 'Invalid battery level on serial=${d.serial}',
      );
      expect(
        voltageMv!,
        inInclusiveRange(2500, 5500),
        reason: 'Invalid battery voltage on serial=${d.serial}',
      );
      expect(
        tempTenthsC!,
        inInclusiveRange(-200, 900),
        reason: 'Invalid battery temperature on serial=${d.serial}',
      );
    });
  });
}
