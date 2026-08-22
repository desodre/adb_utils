@Tags(['all_possible'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_utils/adb_utils.dart';
import 'package:test/test.dart';

class _TrackingServer {
  _TrackingServer._(this._server, this._snapshots, this._fragmentSnapshots);

  final ServerSocket _server;
  final List<String> _snapshots;
  final bool _fragmentSnapshots;
  final _connections = <Socket>{};
  var connectionsClosed = 0;

  int get port => _server.port;

  static Future<_TrackingServer> start(
    List<String> snapshots, {
    bool fragmentSnapshots = false,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final trackingServer = _TrackingServer._(
      server,
      snapshots,
      fragmentSnapshots,
    );
    server.listen(trackingServer._handleConnection);
    return trackingServer;
  }

  Future<void> _handleConnection(Socket socket) async {
    _connections.add(socket);
    try {
      final command = await _readCommand(socket);
      expect(command, 'host:track-devices');
      socket.add(utf8.encode('OKAY'));
      await socket.flush();

      for (final snapshot in _snapshots) {
        final message = _lengthPrefixed(snapshot);
        if (_fragmentSnapshots) {
          final midpoint = message.length ~/ 2;
          socket.add(message.sublist(0, midpoint));
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 1));
          socket.add(message.sublist(midpoint));
        } else {
          socket.add(message);
        }
        await socket.flush();
      }
      await socket.done;
    } finally {
      _connections.remove(socket);
      connectionsClosed++;
      await socket.close();
    }
  }

  static List<int> _lengthPrefixed(String value) {
    final bytes = utf8.encode(value);
    return utf8.encode(bytes.length.toRadixString(16).padLeft(4, '0')) + bytes;
  }

  static Future<String> _readCommand(Socket socket) async {
    final iterator = StreamIterator<List<int>>(socket);
    final bytes = <int>[];
    while (bytes.length < 4) {
      if (!await iterator.moveNext()) throw StateError('Socket closed early');
      bytes.addAll(iterator.current);
    }
    final length = int.parse(utf8.decode(bytes.sublist(0, 4)), radix: 16);
    while (bytes.length < 4 + length) {
      if (!await iterator.moveNext()) throw StateError('Socket closed early');
      bytes.addAll(iterator.current);
    }
    await iterator.cancel();
    return utf8.decode(bytes.sublist(4, 4 + length));
  }

  Future<void> close() async {
    for (final socket in _connections.toList()) {
      socket.destroy();
    }
    await _server.close();
  }
}

void main() {
  group('AdbClient.trackDevices', () {
    test(
      'emits additions, state changes, and removals from snapshots',
      () async {
        final server = await _TrackingServer.start([
          'one\tdevice\ntwo\toffline\n',
          'one\toffline\nthree\tdevice\n',
        ]);
        addTearDown(server.close);

        final events = await AdbClient(
          port: server.port,
        ).trackDevices().take(5).toList();

        expect(
          events.map((event) => (event.serial, event.state, event.present)),
          [
            ('one', DeviceState.device, true),
            ('two', DeviceState.offline, true),
            ('one', DeviceState.offline, true),
            ('three', DeviceState.device, true),
            ('two', DeviceState.offline, false),
          ],
        );
      },
    );

    test(
      'does not emit unchanged devices and handles fragmented snapshots',
      () async {
        final server = await _TrackingServer.start([
          'emulator-5554\tdevice\n',
          'emulator-5554\tdevice\n',
        ], fragmentSnapshots: true);
        addTearDown(server.close);

        final event = await AdbClient(port: server.port).trackDevices().first;

        expect(event.serial, 'emulator-5554');
        expect(event.state, DeviceState.device);
        expect(event.present, isTrue);
      },
    );

    test(
      'closes the tracking transport when the subscription is cancelled',
      () async {
        final server = await _TrackingServer.start(['serial\tdevice\n']);
        addTearDown(server.close);
        final subscription = AdbClient(
          port: server.port,
        ).trackDevices().listen((_) {});

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();
      },
    );
  });
}
