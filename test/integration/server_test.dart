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
    test('returns a string response for unreachable address', () async {
      // ADB server responds with a message, not an exception, for bad addresses.
      final result = await adb.connect(
        '127.0.0.1:59999',
        timeout: const Duration(seconds: 3),
      );
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });
  });

  group('AdbClient.disconnect', () {
    test('returns a string response for address not connected', () async {
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
