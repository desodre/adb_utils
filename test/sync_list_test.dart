@Tags(['all_possible'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adb_utils/adb_utils.dart';
import 'helpers/reporting.dart';

List<int> _le32(int val) {
  final bd = ByteData(4);
  bd.setUint32(0, val, Endian.little);
  return bd.buffer.asUint8List();
}

void _writeDent(Socket socket, String name, int mode, int size, int mtime) {
  final nameBytes = utf8.encode(name);
  final builder = BytesBuilder(copy: false)
    ..add(utf8.encode('DENT'))
    ..add(_le32(mode))
    ..add(_le32(size))
    ..add(_le32(mtime))
    ..add(_le32(nameBytes.length))
    ..add(nameBytes);
  socket.add(builder.toBytes());
}

void _writeDone(Socket socket) {
  final builder = BytesBuilder(copy: false)
    ..add(utf8.encode('DONE'))
    ..add(List<int>.filled(16, 0));
  socket.add(builder.toBytes());
}

class MockAdbSyncServer {
  MockAdbSyncServer(this.server);
  final ServerSocket server;
  int get port => server.port;

  static Future<MockAdbSyncServer> start({
    required void Function(Socket socket, String path) onListRequest,
    String? failMessage,
    String? invalidHeader,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) async {
      final buffer = <int>[];
      Completer<void>? dataWaiter;

      void onData(List<int> chunk) {
        buffer.addAll(chunk);
        dataWaiter?.complete();
        dataWaiter = null;
      }

      final sub = socket.listen(onData);

      Future<List<int>> readExact(int n) async {
        while (buffer.length < n) {
          dataWaiter = Completer<void>();
          await dataWaiter!.future;
        }
        final res = buffer.sublist(0, n);
        buffer.removeRange(0, n);
        return res;
      }

      try {
        // 1. Read host:transport
        final lenBytes = await readExact(4);
        final len = int.parse(utf8.decode(lenBytes), radix: 16);
        await readExact(len); // read transport command
        socket.add(utf8.encode('OKAY'));

        // 2. Read sync:
        final syncLenBytes = await readExact(4);
        final syncLen = int.parse(utf8.decode(syncLenBytes), radix: 16);
        await readExact(syncLen); // read "sync:"
        socket.add(utf8.encode('OKAY'));

        // 3. Read LIST command
        final cmdBytes = await readExact(4);
        final cmd = utf8.decode(cmdBytes);
        if (cmd == 'LIST') {
          final pathLenBytes = await readExact(4);
          final pathLen = ByteData.view(
            Uint8List.fromList(pathLenBytes).buffer,
          ).getUint32(0, Endian.little);
          final path = utf8.decode(await readExact(pathLen));

          if (failMessage != null) {
            final msgBytes = utf8.encode(failMessage);
            final builder = BytesBuilder(copy: false)
              ..add(utf8.encode('FAIL'))
              ..add(_le32(msgBytes.length))
              ..add(msgBytes);
            socket.add(builder.toBytes());
          } else if (invalidHeader != null) {
            socket.add(utf8.encode(invalidHeader));
          } else {
            onListRequest(socket, path);
          }
        }

        // 4. Read QUIT
        final quitBytes = await readExact(8);
        final quitCmd = utf8.decode(quitBytes.sublist(0, 4));
        if (quitCmd == 'QUIT') {
          // done
        }
      } catch (_) {
        // Ignore socket disconnects during cleanup
      } finally {
        await sub.cancel();
        await socket.close();
      }
    });

    return MockAdbSyncServer(server);
  }

  Future<void> close() => server.close();
}

void main() {
  configureHtmlReporting(suiteName: 'unit/sync_list_test.dart');

  group('AdbDirEntry Model', () {
    test('decodes directory mode correctly', () {
      final entry = AdbDirEntry(
        name: 'my_directory',
        mode: 16877, // Octal: 0040755 (directory)
        size: 0,
        mtime: DateTime.fromMillisecondsSinceEpoch(1600000000000, isUtc: true),
      );

      expect(entry.isDirectory, isTrue);
      expect(entry.isFile, isFalse);
      expect(entry.isLink, isFalse);
      expect(entry.permissionsOctal, equals('755'));
      expect(entry.permissionsString, equals('drwxr-xr-x'));
    });

    test('decodes file mode correctly', () {
      final entry = AdbDirEntry(
        name: 'my_file.txt',
        mode: 33188, // Octal: 0100644 (regular file)
        size: 1024,
        mtime: DateTime.fromMillisecondsSinceEpoch(1600000000000, isUtc: true),
      );

      expect(entry.isDirectory, isFalse);
      expect(entry.isFile, isTrue);
      expect(entry.isLink, isFalse);
      expect(entry.permissionsOctal, equals('644'));
      expect(entry.permissionsString, equals('-rw-r--r--'));
      expect(
        entry.toString(),
        contains('-rw-r--r--     1024 2020-09-13T12:26:40.000Z my_file.txt'),
      );
    });

    test('decodes symlink mode correctly', () {
      final entry = AdbDirEntry(
        name: 'my_link',
        mode: 41471, // Octal: 0120777 (symlink)
        size: 0,
        mtime: DateTime.fromMillisecondsSinceEpoch(1600000000000, isUtc: true),
      );

      expect(entry.isDirectory, isFalse);
      expect(entry.isFile, isFalse);
      expect(entry.isLink, isTrue);
      expect(entry.permissionsOctal, equals('777'));
      expect(entry.permissionsString, equals('lrwxrwxrwx'));
    });
  });

  group('AdbSync.list Protocol', () {
    test(
      'retrieves and parses directory entries excluding sentinels',
      () async {
        final mockServer = await MockAdbSyncServer.start(
          onListRequest: (socket, path) {
            expect(path, equals('/sdcard'));
            _writeDent(socket, '.', 16877, 0, 1600000000);
            _writeDent(socket, '..', 16877, 0, 1600000000);
            _writeDent(socket, 'photo.jpg', 33188, 500000, 1600000000);
            _writeDent(socket, 'documents', 16877, 0, 1600000000);
            _writeDone(socket);
          },
        );

        try {
          final client = AdbClient(host: '127.0.0.1', port: mockServer.port);
          final device = await client.device(serial: 'fake-serial');
          final list = await device.sync.list(
            '/sdcard',
            includeSentinels: false,
          );

          expect(list, hasLength(2));
          expect(list[0].name, equals('photo.jpg'));
          expect(list[0].isFile, isTrue);
          expect(list[0].size, equals(500000));
          expect(list[1].name, equals('documents'));
          expect(list[1].isDirectory, isTrue);
        } finally {
          await mockServer.close();
        }
      },
    );

    test(
      'retrieves and parses directory entries including sentinels',
      () async {
        final mockServer = await MockAdbSyncServer.start(
          onListRequest: (socket, path) {
            expect(path, equals('/sdcard'));
            _writeDent(socket, '.', 16877, 0, 1600000000);
            _writeDent(socket, '..', 16877, 0, 1600000000);
            _writeDent(socket, 'photo.jpg', 33188, 500000, 1600000000);
            _writeDone(socket);
          },
        );

        try {
          final client = AdbClient(host: '127.0.0.1', port: mockServer.port);
          final device = await client.device(serial: 'fake-serial');
          final list = await device.sync.list(
            '/sdcard',
            includeSentinels: true,
          );

          expect(list, hasLength(3));
          expect(list[0].name, equals('.'));
          expect(list[1].name, equals('..'));
          expect(list[2].name, equals('photo.jpg'));
        } finally {
          await mockServer.close();
        }
      },
    );

    test('throws AdbError on protocol FAIL response', () async {
      final mockServer = await MockAdbSyncServer.start(
        onListRequest: (s, p) {},
        failMessage: 'Permission denied',
      );

      try {
        final client = AdbClient(host: '127.0.0.1', port: mockServer.port);
        final device = await client.device(serial: 'fake-serial');

        await expectLater(
          device.sync.list('/root'),
          throwsA(
            isA<AdbError>().having(
              (e) => e.message,
              'message',
              contains('Permission denied'),
            ),
          ),
        );
      } finally {
        await mockServer.close();
      }
    });

    test('throws AdbError on unexpected response header', () async {
      final mockServer = await MockAdbSyncServer.start(
        onListRequest: (s, p) {},
        invalidHeader: 'BOGU',
      );

      try {
        final client = AdbClient(host: '127.0.0.1', port: mockServer.port);
        final device = await client.device(serial: 'fake-serial');

        await expectLater(
          device.sync.list('/sdcard'),
          throwsA(
            isA<AdbError>().having(
              (e) => e.message,
              'message',
              contains('Expected DENT or DONE, got BOGU'),
            ),
          ),
        );
      } finally {
        await mockServer.close();
      }
    });
  });
}
