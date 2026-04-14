import 'dart:async';

import 'exceptions.dart';
import 'models/device_info.dart';
import 'models/forward_item.dart';
import 'protocol/adb_transport.dart';
import 'adb_device.dart';

/// Event emitted by [AdbClient.trackDevices].
class DeviceEvent {
  const DeviceEvent({
    required this.serial,
    required this.state,
    required this.present,
  });

  final String serial;
  final DeviceState state;

  /// `true` if the device became available, `false` if it disconnected.
  final bool present;

  @override
  String toString() =>
      'DeviceEvent(serial: $serial, present: $present, state: ${state.name})';
}

/// Client for the ADB server. Entry point of the library.
///
/// ```dart
/// final adb = AdbClient();
/// final devices = await adb.deviceList();
/// final d = await adb.device();
/// print(await d.shell('getprop ro.product.model'));
/// ```
class AdbClient {
  AdbClient({
    this.host = '127.0.0.1',
    this.port = 5037,
    this.socketTimeout = const Duration(seconds: 10),
  });

  final String host;
  final int port;
  final Duration socketTimeout;

  /// Opens a fresh transport to the ADB server.
  Future<AdbTransport> openTransport() =>
      AdbTransport.connect(host, port, timeout: socketTimeout);

  // ── Server ────────────────────────────────────────────────────────────────

  /// Returns the ADB server version integer (e.g. 39).
  Future<int> serverVersion() async {
    final t = await openTransport();
    try {
      await t.sendCommand('host:version');
      final raw = await t.readString();
      return int.parse(raw, radix: 16);
    } finally {
      await t.close();
    }
  }

  /// Kills the ADB server.
  Future<void> killServer() async {
    final t = await openTransport();
    try {
      await t.send('host:kill');
    } finally {
      await t.close();
    }
  }

  // ── Device list ───────────────────────────────────────────────────────────

  /// Returns all connected devices.
  Future<List<DeviceInfo>> deviceList() async {
    final t = await openTransport();
    try {
      await t.sendCommand('host:devices-l');
      final body = await t.readString();
      return _parseDeviceList(body);
    } finally {
      await t.close();
    }
  }

  List<DeviceInfo> _parseDeviceList(String body) {
    final devices = <DeviceInfo>[];
    for (final line in body.trim().split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final serial = parts[0];
      final state = DeviceState.parse(parts[1]);
      int? transportId;
      String? product, model, device;
      for (final part in parts.skip(2)) {
        final kv = part.split(':');
        if (kv.length != 2) continue;
        switch (kv[0]) {
          case 'transport_id':
            transportId = int.tryParse(kv[1]);
          case 'product':
            product = kv[1];
          case 'model':
            model = kv[1];
          case 'device':
            device = kv[1];
        }
      }
      devices.add(
        DeviceInfo(
          serial: serial,
          state: state,
          transportId: transportId,
          product: product,
          model: model,
          device: device,
        ),
      );
    }
    return devices;
  }

  // ── Device selection ──────────────────────────────────────────────────────

  /// Returns an [AdbDevice] for the given [serial] or [transportId].
  ///
  /// If neither is given, expects exactly one device connected.
  /// Throws [AdbError] if zero or multiple devices are connected.
  Future<AdbDevice> device({String? serial, int? transportId}) async {
    if (serial != null) {
      return AdbDevice(serial: serial, client: this);
    }
    if (transportId != null) {
      final devices = await deviceList();
      final info = devices.firstWhere(
        (d) => d.transportId == transportId,
        orElse: () => throw AdbError('No device with transportId $transportId'),
      );
      return AdbDevice(serial: info.serial, client: this);
    }
    final devices = await deviceList();
    final online = devices.where((d) => d.state == DeviceState.device).toList();
    if (online.isEmpty) throw AdbError('No device connected');
    if (online.length > 1) {
      throw AdbError(
        'Multiple devices connected; specify serial or transportId. '
        'Found: ${online.map((d) => d.serial).join(', ')}',
      );
    }
    return AdbDevice(serial: online.first.serial, client: this);
  }

  // ── Connect / disconnect ──────────────────────────────────────────────────

  /// Connects to a remote device (equivalent to `adb connect <host:port>`).
  ///
  /// Returns the server's response string (e.g. "connected to 192.168.1.1:5555").
  /// Throws [AdbTimeout] if the server does not respond within [timeout].
  Future<String> connect(
    String address, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final t = await openTransport();
    try {
      await t.send('host:connect:$address');
      // readOkay + readString must both be inside the timeout window,
      // because the ADB server only replies after the TCP connection attempt.
      return await Future(() async {
        await t.readOkay();
        return t.readString();
      }).timeout(
        timeout,
        onTimeout: () =>
            throw AdbTimeout('connect to $address timed out after $timeout'),
      );
    } finally {
      await t.close();
    }
  }

  /// Disconnects a remote device.
  ///
  /// Returns the server's response string.
  /// Never throws [AdbError] — when the device is not connected the server
  /// sends a FAIL response whose message is returned as a plain string,
  /// matching the behaviour of the `adb disconnect` CLI command.
  Future<String> disconnect(String address) async {
    final t = await openTransport();
    try {
      await t.send('host:disconnect:$address');
      try {
        await t.readOkay();
        return await t.readString();
      } on AdbError catch (e) {
        // ADB server sends FAIL + message when device is not connected.
        // Return the message string instead of throwing, like `adb disconnect`.
        return e.message;
      }
    } finally {
      await t.close();
    }
  }

  // ── Forward / reverse lists ───────────────────────────────────────────────

  /// Lists all active port forwards across all devices.
  Future<List<ForwardItem>> forwardList({String? serial}) async {
    final t = await openTransport();
    try {
      final cmd = serial != null
          ? 'host-serial:$serial:list-forward'
          : 'host:list-forward';
      await t.sendCommand(cmd);
      final body = await t.readString();
      return _parseForwardList(body);
    } finally {
      await t.close();
    }
  }

  List<ForwardItem> _parseForwardList(String body) {
    final items = <ForwardItem>[];
    for (final line in body.trim().split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.trim().split(' ');
      if (parts.length < 3) continue;
      items.add(
        ForwardItem(serial: parts[0], local: parts[1], remote: parts[2]),
      );
    }
    return items;
  }

  // ── Track devices ─────────────────────────────────────────────────────────

  /// Streams device connect/disconnect events.
  ///
  /// Throws [AdbError] if the ADB server is killed while tracking.
  Stream<DeviceEvent> trackDevices() async* {
    final t = await openTransport();
    await t.sendCommand('host:track-devices');
    try {
      while (true) {
        final body = await t.readString();
        for (final line in body.trim().split('\n')) {
          if (line.trim().isEmpty) continue;
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length < 2) continue;
          final serial = parts[0];
          final state = DeviceState.parse(parts[1]);
          yield DeviceEvent(
            serial: serial,
            state: state,
            present: state != DeviceState.offline,
          );
        }
      }
    } finally {
      await t.close();
    }
  }

  /// Opens a transport connection already switched to [serial].
  Future<AdbTransport> transportFor(String serial) async {
    final t = await openTransport();
    await t.sendCommand('host:transport:$serial');
    return t;
  }
}
