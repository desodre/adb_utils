import 'package:adb_utils/adb_utils.dart';
import 'package:test/test.dart';

// Realistic dumpsys output (trimmed) for a user-installed package.
const _dumpsysUserApp = '''
Package [com.example.app] (abc1234):
    versionCode=42 minSdk=21 targetSdk=33
    versionName=1.2.3
    lastUpdateTime=2024-03-15 10:30:00
      firstInstallTime=1969-12-31 20:00:00
      firstInstallTime=2024-01-01 09:00:00
''';

// Realistic dumpsys output for a system app with two real user entries.
const _dumpsysSystemApp = '''
Package [com.android.settings] (5d43f04):
    versionCode=35 minSdk=35 targetSdk=35
    versionName=15
    lastUpdateTime=2025-05-29 13:05:29
      firstInstallTime=2025-05-29 13:05:29
      firstInstallTime=2025-06-12 15:40:34
''';

// Dumpsys output with no optional fields.
const _dumpsysMinimal = '''
Package [com.bare.app] (000000):
''';

const _dumpsysBattery = '''
Current Battery Service state:
  AC powered: false
  USB powered: true
  Wireless powered: false
  Max charging current: 3225000
  Max charging voltage: 22000000
  Charge counter: 3964000
  status: 5
  health: 2
  present: true
  level: 100
  scale: 100
  voltage: 4449
  temperature: 240
  technology: Li-poly
  Charging state: 0
''';

void main() {
  group('BatteryInfo', () {
    test('parses dumpsys output correctly', () {
      final info = BatteryInfo.fromDumpsys(_dumpsysBattery);
      expect(info.level, equals(100));
      expect(info.temperature, equals(24.0)); // 240 / 10
      expect(info.status, equals(BatteryStatus.full)); // status: 5
      expect(info.usbPowered, isTrue);
      expect(info.acPowered, isFalse);
    });
  });

  group('DeviceState', () {
    test('parses known states', () {
      expect(DeviceState.parse('device'), DeviceState.device);
      expect(DeviceState.parse('offline'), DeviceState.offline);
      expect(DeviceState.parse('unauthorized'), DeviceState.unauthorized);
    });

    test('parse unknown returns unknown', () {
      expect(DeviceState.parse('bogus'), DeviceState.unknown);
    });
  });

  group('ShellResult', () {
    test('isSuccess when returnCode is 0', () {
      const r = ShellResult(command: 'echo hi', returnCode: 0, output: 'hi\n');
      expect(r.isSuccess, isTrue);
    });

    test('isSuccess false when non-zero returnCode', () {
      const r = ShellResult(command: 'false', returnCode: 1, output: '');
      expect(r.isSuccess, isFalse);
    });
  });

  group('NetworkType', () {
    test('prefix values', () {
      expect(NetworkType.tcp.prefix, 'tcp');
      expect(NetworkType.localAbstract.prefix, 'localabstract');
      expect(NetworkType.dev.prefix, 'dev');
    });
  });

  group('ForwardItem', () {
    test('toString', () {
      const item = ForwardItem(
        serial: 'abc123',
        local: 'tcp:9999',
        remote: 'localabstract:scrcpy',
      );
      expect(item.toString(), contains('abc123'));
    });
  });

  group('AppInfo.fromDumpsys', () {
    test('parses packageName, versionCode, versionName', () {
      final info = AppInfo.fromDumpsys('com.example.app', _dumpsysUserApp);
      expect(info.packageName, equals('com.example.app'));
      expect(info.versionCode, equals(42));
      expect(info.versionName, equals('1.2.3'));
    });

    test('parses lastUpdateTime correctly', () {
      final info = AppInfo.fromDumpsys('com.example.app', _dumpsysUserApp);
      expect(info.lastUpdateTime, equals(DateTime(2024, 3, 15, 10, 30, 0)));
    });

    test('filters epoch sentinel and returns real firstInstallTime', () {
      final info = AppInfo.fromDumpsys('com.example.app', _dumpsysUserApp);
      // epoch (1969) must be discarded; only 2024-01-01 remains
      expect(info.firstInstallTime, equals(DateTime(2024, 1, 1, 9, 0, 0)));
    });

    test(
      'returns earliest firstInstallTime when multiple real dates exist',
      () {
        final info = AppInfo.fromDumpsys(
          'com.android.settings',
          _dumpsysSystemApp,
        );
        // 2025-05-29 is earlier than 2025-06-12
        expect(info.firstInstallTime, equals(DateTime(2025, 5, 29, 13, 5, 29)));
      },
    );

    test('returns null optional fields for minimal output', () {
      final info = AppInfo.fromDumpsys('com.bare.app', _dumpsysMinimal);
      expect(info.versionCode, isNull);
      expect(info.versionName, isNull);
      expect(info.firstInstallTime, isNull);
      expect(info.lastUpdateTime, isNull);
    });

    test('throws AdbError when package not found', () {
      expect(
        () => AppInfo.fromDumpsys(
          'com.missing.pkg',
          'Unable to find package: com.missing.pkg\n',
        ),
        throwsA(isA<AdbError>()),
      );
    });

    test('throws AdbError when header is absent', () {
      expect(
        () => AppInfo.fromDumpsys('com.example.app', 'some unrelated output'),
        throwsA(isA<AdbError>()),
      );
    });

    test('toString includes packageName and versionName', () {
      final info = AppInfo.fromDumpsys('com.example.app', _dumpsysUserApp);
      expect(info.toString(), contains('com.example.app'));
      expect(info.toString(), contains('1.2.3'));
    });
  });
}
