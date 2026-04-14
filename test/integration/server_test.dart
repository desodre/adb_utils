@Tags(['integration'])
library;

import 'package:adb_utils/adb_utils.dart';
import 'package:test/test.dart';

import '../helpers/adb_test_helpers.dart';

/// Integration tests for [AdbClient].
///
/// These tests require the ADB server to be running (`adb start-server`)
/// but do NOT require a device to be connected.
///
/// Run with:
///   dart test test/integration/server_test.dart
///   dart test --tags integration
void main() {
  late AdbClient adb;

  setUpAll(() async {
    adb = await requireAdbServer();
  });

  // ── Server ──────────────────────────────────────────────────────────────

  group('AdbClient.serverVersion', () {
    test('returns a positive integer', () async {
      final version = await adb.serverVersion();
      expect(version, isPositive);
    });
  });

  // ── Device list ──────────────────────────────────────────────────────────

  group('AdbClient.deviceList', () {
    test('returns a list (may be empty)', () async {
      final devices = await adb.deviceList();
      expect(devices, isA<List<DeviceInfo>>());
    });

    test('each DeviceInfo has non-empty serial', () async {
      final devices = await adb.deviceList();
      for (final d in devices) {
        expect(d.serial, isNotEmpty, reason: 'DeviceInfo.serial must not be empty');
      }
    });

    test('each DeviceInfo has a known DeviceState', () async {
      final devices = await adb.deviceList();
      for (final d in devices) {
        expect(DeviceState.values, contains(d.state));
      }
    });
  });

  // ── Connect / disconnect ─────────────────────────────────────────────────

  group('AdbClient.connect', () {
    test('throws AdbTimeout when server cannot reach address in time', () async {
      // Port 59999 on localhost — if no listener, the OS sends ECONNREFUSED
      // and ADB server returns immediately; if filtered, AdbTimeout fires.
      // Either outcome is acceptable; what must NOT happen is a 30-second hang.
      try {
        final result = await adb.connect(
          '127.0.0.1:59999',
          timeout: const Duration(seconds: 4),
        );
        // Fast ECONNREFUSED path — ADB server replied with an error string
        expect(result, isA<String>());
        expect(result, isNotEmpty);
      } on AdbTimeout {
        // Filtered port path — timeout fired correctly
      }
    });
  });

  group('AdbClient.disconnect', () {
    test('returns a string when address is not connected', () async {
      // ADB server returns FAIL for unknown addresses; disconnect() converts
      // that to a plain string instead of throwing.
      final result = await adb.disconnect('127.0.0.1:59999');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });
  });

  // ── Forward list ─────────────────────────────────────────────────────────

  group('AdbClient.forwardList', () {
    test('returns a list', () async {
      final forwards = await adb.forwardList();
      expect(forwards, isA<List<ForwardItem>>());
    });
  });
}
