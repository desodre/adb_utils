import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_utils/src/adb_client.dart';
import 'package:adb_utils/src/adb_device.dart';
import 'package:adb_utils/src/models/ui_hierarchy.dart';
import 'package:adb_utils/src/adb_sync.dart';
import 'package:adb_utils/src/phantom/phantom_client.dart';
import 'helpers/reporting_test.dart';

class _FakeAdbSync extends AdbSync {
  _FakeAdbSync(super.device);

  final pushes = <(Object, String)>[];

  @override
  Future<void> push(Object source, String remotePath) async {
    pushes.add((source, remotePath));
  }
}

class _FakeAdbDevice extends AdbDevice {
  _FakeAdbDevice() : super(serial: 'fake-serial', client: AdbClient());

  final shellCommands = <String>[];
  final forwardCalls = <(String, String)>[];
  late final _FakeAdbSync fakeSync = _FakeAdbSync(this);

  @override
  AdbSync get sync => fakeSync;

  @override
  Future<String> shell(
    Object command, {
    Duration? timeout,
    String encoding = 'utf-8',
  }) async {
    final cmd = command is List ? command.join(' ') : command as String;
    shellCommands.add(cmd);
    return '';
  }

  @override
  Future<void> forward(String local, String remote) async {
    forwardCalls.add((local, remote));
  }
}

Future<({ServerSocket server, Future<Map<String, dynamic>> request})>
_startJsonServer(String response, {bool chunked = false}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final requestCompleter = Completer<Map<String, dynamic>>();

  unawaited(() async {
    final client = await server.first;
    final line = await utf8.decoder
        .bind(client)
        .transform(const LineSplitter())
        .first;
    requestCompleter.complete(jsonDecode(line) as Map<String, dynamic>);

    final bytes = utf8.encode(response);
    if (chunked && bytes.length > 1) {
      final mid = bytes.length ~/ 2;
      client.add(bytes.sublist(0, mid));
      await client.flush();
      client.add(bytes.sublist(mid));
    } else {
      client.add(bytes);
    }
    await client.flush();
    await client.close();
    await server.close();
  }());

  return (server: server, request: requestCompleter.future);
}

Future<ServerSocket> _startVideoServer(List<int> payload) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 9009);
  unawaited(() async {
    final client = await server.first;
    client.add(payload);
    await client.flush();
    await client.close();
    await server.close();
  }());
  return server;
}

void main() {
  configureHtmlReporting(suiteName: 'unit/phantom_client_test.dart');

  group('PhantomClient constructor', () {
    test('rejects invalid TCP port', () {
      expect(
        () => PhantomClient(device: _FakeAdbDevice(), port: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => PhantomClient(device: _FakeAdbDevice(), port: 70000),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PhantomClient.startAgent', () {
    test('pushes APKs, installs, starts agent and forwards port', () async {
      final fakeDevice = _FakeAdbDevice();
      final client = PhantomClient(device: fakeDevice, port: 9008);

      await client.startAgent('/tmp/target-local.apk', '/tmp/agent-local.apk');

      expect(
        fakeDevice.fakeSync.pushes,
        equals([
          ('/tmp/target-local.apk', '/data/local/tmp/target.apk'),
          ('/tmp/agent-local.apk', '/data/local/tmp/agent.apk'),
        ]),
      );
      expect(
        fakeDevice.shellCommands,
        equals([
          'pm install -t -r /data/local/tmp/target.apk',
          'pm install -t -r /data/local/tmp/agent.apk',
          'am force-stop com.example.phantom_agent',
          'nohup am instrument -w com.example.phantom_agent.test/androidx.test.runner.AndroidJUnitRunner > /dev/null 2>&1 &',
        ]),
      );
      expect(fakeDevice.forwardCalls, equals([('tcp:9008', 'tcp:9008')]));
    });
  });

  group('PhantomClient socket communication', () {
    test(
      'startVideoStream forwards 9009 and returns raw H.264 byte stream',
      () async {
        final server = await _startVideoServer([0, 0, 0, 1, 103, 66, 0, 30]);
        final fakeDevice = _FakeAdbDevice();
        final client = PhantomClient(device: fakeDevice);

        final stream = await client.startVideoStream();
        final socket = stream as Socket;
        final bytes = await socket.expand((chunk) => chunk).toList();

        expect(server.port, equals(9009));
        expect(fakeDevice.forwardCalls, equals([('tcp:9009', 'tcp:9009')]));
        expect(bytes, equals([0, 0, 0, 1, 103, 66, 0, 30]));
      },
    );

    test('dumpWindow returns xml when status is success', () async {
      final serverData = await _startJsonServer(
        '{"status":"success","xml":"<hierarchy rotation=\\"1\\"/>"}',
        chunked: true,
      );
      final fakeDevice = _FakeAdbDevice();
      final client = PhantomClient(
        device: fakeDevice,
        port: serverData.server.port,
      );

      final xml = await client.dumpWindow();
      final request = await serverData.request;

      expect(xml, equals('<hierarchy rotation="1"/>'));
      expect(request, equals({'action': 'dumpWindow'}));
    });

    test('dumpWindowHierarchy parses xml into UiHierarchy', () async {
      final serverData = await _startJsonServer(
        '{"status":"success","xml":"<hierarchy rotation=\\"2\\"><node index=\\"0\\" text=\\"Entrar\\" resource-id=\\"\\" class=\\"android.widget.Button\\" package=\\"com.example\\" content-desc=\\"\\" checkable=\\"false\\" checked=\\"false\\" clickable=\\"true\\" enabled=\\"true\\" focusable=\\"true\\" focused=\\"false\\" scrollable=\\"false\\" long-clickable=\\"false\\" password=\\"false\\" selected=\\"false\\" visible-to-user=\\"true\\" bounds=\\"[10,20][110,120]\\" drawing-order=\\"0\\" hint=\\"\\" display-id=\\"0\\"/></hierarchy>"}',
      );
      final fakeDevice = _FakeAdbDevice();
      final client = PhantomClient(
        device: fakeDevice,
        port: serverData.server.port,
      );

      final hierarchy = await client.dumpWindowHierarchy();
      final request = await serverData.request;

      expect(hierarchy, isA<UiHierarchy>());
      expect(hierarchy.rotation, equals(2));
      expect(hierarchy.nodes, hasLength(1));
      expect(hierarchy.nodes.first.text, equals('Entrar'));
      expect(
        hierarchy.nodes.first.bounds.center,
        equals({'x': 60.0, 'y': 70.0}),
      );
      expect(request, equals({'action': 'dumpWindow'}));
    });

    test('dumpWindow throws when status is not success', () async {
      final serverData = await _startJsonServer(
        '{"status":"error","message":"agent not ready"}',
      );
      final fakeDevice = _FakeAdbDevice();
      final client = PhantomClient(
        device: fakeDevice,
        port: serverData.server.port,
      );

      await expectLater(client.dumpWindow(), throwsA(isA<Exception>()));
      final request = await serverData.request;
      expect(request, equals({'action': 'dumpWindow'}));
    });

    test('clickByText returns true only when status is success', () async {
      final successServer = await _startJsonServer('{"status":"success"}');
      final successClient = PhantomClient(
        device: _FakeAdbDevice(),
        port: successServer.server.port,
      );

      final ok = await successClient.clickByText('Entrar');
      final successRequest = await successServer.request;

      expect(ok, isTrue);
      expect(
        successRequest,
        equals({'action': 'clickByText', 'text': 'Entrar'}),
      );

      final failServer = await _startJsonServer('{"status":"error"}');
      final failClient = PhantomClient(
        device: _FakeAdbDevice(),
        port: failServer.server.port,
      );

      final failed = await failClient.clickByText('Entrar');
      final failRequest = await failServer.request;

      expect(failed, isFalse);
      expect(failRequest, equals({'action': 'clickByText', 'text': 'Entrar'}));
    });
  });
}
