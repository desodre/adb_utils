@Tags(['device'])
library;

import 'package:adb_utils/adb_utils.dart';
import 'package:test/test.dart';

import '../helpers/adb_test_helpers.dart';

/// Integration tests that require a physical device or emulator connected.
///
/// Run with:
///   dart test test/integration/device_test.dart
///   dart test --tags device
///
/// All tests are skipped automatically when no device is available.
void main() {
  late AdbClient adb;
  late AdbDevice d;

  setUpAll(() async {
    d = await requireDevice();
    adb = d.client;
  });

  // ── Device selection ─────────────────────────────────────────────────────

  group('AdbClient.device', () {
    test('returns AdbDevice with non-empty serial', () {
      expect(d.serial, isNotEmpty);
    });

    test('device(serial: ...) returns same device', () async {
      final d2 = await adb.device(serial: d.serial);
      expect(d2.serial, equals(d.serial));
    });

    test('deviceList includes the connected device', () async {
      final devices = await adb.deviceList();
      expect(devices.map((x) => x.serial), contains(d.serial));
    });
  });

  // ── State ────────────────────────────────────────────────────────────────

  group('AdbDevice.getState', () {
    test('returns "device"', () async {
      final state = await d.getState();
      expect(state.trim(), equals('device'));
    });
  });

  // ── Shell ────────────────────────────────────────────────────────────────

  group('AdbDevice.shell', () {
    test('echo returns expected output', () async {
      final out = await d.shell('echo hello_adb');
      expect(out.trim(), equals('hello_adb'));
    });

    test('accepts a List<String> command', () async {
      final out = await d.shell(['echo', 'list_cmd']);
      expect(out.trim(), equals('list_cmd'));
    });

    test('multiline output is preserved', () async {
      final out = await d.shell('printf "line1\\nline2\\nline3"');
      expect(out.trim().split('\n').length, equals(3));
    });

    test('non-existent command produces output on stderr', () async {
      final out = await d.shell('command_that_does_not_exist_xyz 2>&1');
      expect(out, isNotEmpty);
    });
  });

  group('AdbDevice.shell2', () {
    test('successful command has returnCode 0', () async {
      final result = await d.shell2('echo ok');
      expect(result.returnCode, equals(0));
      expect(result.isSuccess, isTrue);
      expect(result.output.trim(), equals('ok'));
    });

    test('failing command has non-zero returnCode', () async {
      // `exit N` kills the shell before `;echo EXIT:$?` runs.
      // `(exit N)` runs in a subshell — outer shell captures $? correctly.
      final result = await d.shell2('(exit 42)');
      expect(result.returnCode, equals(42));
      expect(result.isSuccess, isFalse);
    });

    test('command field matches input', () async {
      final result = await d.shell2('echo test');
      expect(result.command, equals('echo test'));
    });
  });

  // ── Properties ───────────────────────────────────────────────────────────

  group('DeviceProperties', () {
    test('model is non-empty', () async {
      final model = await d.prop.model;
      expect(model, isNotEmpty);
    });

    test('brand is non-empty', () async {
      final brand = await d.prop.brand;
      expect(brand, isNotEmpty);
    });

    test('sdkVersion parses as integer >= 21', () async {
      final sdk = await d.prop.sdkVersion;
      expect(int.parse(sdk), greaterThanOrEqualTo(21));
    });

    test('release is non-empty', () async {
      final release = await d.prop.release;
      expect(release, isNotEmpty);
    });

    test('get() with cache returns same value twice', () async {
      final v1 = await d.prop.get('ro.product.model', cache: true);
      final v2 = await d.prop.get('ro.product.model', cache: true);
      expect(v1, equals(v2));
    });
  });

  // ── Device info ───────────────────────────────────────────────────────────

  group('AdbDevice.getSerialNo', () {
    test('returns non-empty string', () async {
      final serial = await d.getSerialNo();
      expect(serial.trim(), isNotEmpty);
    });
  });

  group('AdbDevice.windowSize', () {
    test('returns positive width and height', () async {
      final (w, h) = await d.windowSize();
      expect(w, greaterThan(0));
      expect(h, greaterThan(0));
    });

    test('both dimensions are plausible screen values', () async {
      final (w, h) = await d.windowSize();
      // Smallest Android screens are ~320px; largest are ~3840px
      expect(w, inInclusiveRange(200, 4000));
      expect(h, inInclusiveRange(200, 4000));
    });
  });

  group('AdbDevice.rotation', () {
    test('returns value in [0, 1, 2, 3]', () async {
      final rot = await d.rotation();
      expect(rot, inInclusiveRange(0, 3));
    });
  });

  group('AdbDevice.isScreenOn', () {
    test('returns a boolean', () async {
      final on = await d.isScreenOn();
      expect(on, isA<bool>());
    });
  });

  // ── Screenshot ────────────────────────────────────────────────────────────

  group('AdbDevice.screenshot', () {
    test('returns non-empty bytes', () async {
      final bytes = await d.screenshot();
      expect(bytes, isNotEmpty);
    });

    test('bytes are a valid PNG', () async {
      final bytes = await d.screenshot();
      expect(bytes, isPng);
    });

    test('PNG is larger than 1 KB', () async {
      final bytes = await d.screenshot();
      expect(bytes.length, greaterThan(1024));
    });
  });

  // ── Apps ──────────────────────────────────────────────────────────────────

  group('AdbDevice.listPackages', () {
    test('returns non-empty list', () async {
      final packages = await d.listPackages();
      expect(packages, isNotEmpty);
    });

    test('all entries are non-empty strings', () async {
      final packages = await d.listPackages();
      for (final pkg in packages) {
        expect(pkg, isNotEmpty);
      }
    });

    test('thirdPartyOnly is subset of all packages', () async {
      final all = await d.listPackages();
      final thirdParty = await d.listPackages(thirdPartyOnly: true);
      for (final pkg in thirdParty) {
        expect(all, contains(pkg));
      }
    });

    test('system packages include "android"', () async {
      final packages = await d.listPackages();
      expect(packages, contains('android'));
    });
  });

  group('AdbDevice.appCurrent', () {
    test('returns ForegroundAppInfo with non-empty package and activity', () async {
      final app = await d.appCurrent();
      expect(app.packageName, isNotEmpty);
      expect(app.activity, isNotEmpty);
    });
  });

  // ── Port forward ──────────────────────────────────────────────────────────

  group('AdbDevice forward / forwardRemove', () {
    const testLocalPort = 'tcp:47123';
    const testRemotePort = 'tcp:47124';

    tearDown(() async {
      // clean up regardless of test outcome
      try {
        await d.forwardRemove(testLocalPort);
      } catch (_) {}
    });

    test('forward creates a rule visible in forwardList', () async {
      await d.forward(testLocalPort, testRemotePort);
      final forwards = await adb.forwardList(serial: d.serial);
      expect(
        forwards.where((f) => f.local == testLocalPort && f.remote == testRemotePort),
        isNotEmpty,
      );
    });

    test('forwardRemove removes the rule', () async {
      await d.forward(testLocalPort, testRemotePort);
      await d.forwardRemove(testLocalPort);
      final forwards = await adb.forwardList(serial: d.serial);
      expect(
        forwards.where((f) => f.local == testLocalPort),
        isEmpty,
      );
    });

    test('forwardRemoveAll clears all device forwards', () async {
      await d.forward(testLocalPort, testRemotePort);
      await d.forwardRemoveAll();
      final forwards = await adb.forwardList(serial: d.serial);
      expect(
        forwards.where((f) => f.serial == d.serial),
        isEmpty,
      );
    });
  });

  // ── AdbSync ───────────────────────────────────────────────────────────────

  group('AdbSync (via shell workaround)', () {
    const remotePath = '/data/local/tmp/adb_utils_test_file.txt';
    const content = 'adb_utils integration test content';

    setUp(() async {
      // Write test file via shell (sync push not yet implemented)
      await d.shell('echo -n "$content" > $remotePath');
    });

    tearDown(() async {
      await d.shell('rm -f $remotePath');
    });

    test('shell can create and verify a file', () async {
      final out = await d.shell('cat $remotePath');
      expect(out.trim(), equals(content));
    });

    test('file size is correct', () async {
      final result = await d.shell2('wc -c < $remotePath');
      expect(result.isSuccess, isTrue);
      final size = int.tryParse(result.output.trim());
      expect(size, equals(content.length));
    });
  });
}
