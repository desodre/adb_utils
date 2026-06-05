import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'exceptions.dart';
import 'adb_device.dart';
import 'models/dir_entry.dart';

const _syncData = 'DATA';
const _syncDone = 'DONE';
// ignore: unused_element
const _syncRecv = 'RECV';
const _syncSend = 'SEND';
// ignore: unused_element
const _syncStat = 'STAT';
// ignore: unused_element
const _syncList = 'LIST';
const _syncQuit = 'QUIT';

/// File transfer operations via the ADB SYNC protocol.
///
/// Access via [AdbDevice.sync].
class AdbSync {
  AdbSync(this._device);

  final AdbDevice _device;

  // ── Push ──────────────────────────────────────────────────────────────────

  /// Pushes [source] to [remotePath] on the device.
  ///
  /// [source] can be a [String] path, a [io.File], [Uint8List] bytes,
  /// or any other [List<int>].
  Future<void> push(Object source, String remotePath) async {
    final Uint8List bytes;
    if (source is String) {
      bytes = await io.File(source).readAsBytes();
    } else if (source is io.File) {
      bytes = await source.readAsBytes();
    } else if (source is Uint8List) {
      bytes = source;
    } else if (source is List<int>) {
      bytes = Uint8List.fromList(source);
    } else {
      throw AdbError('Unsupported source type: ${source.runtimeType}');
    }
    await _pushBytes(bytes, remotePath);
  }

  Future<void> _pushBytes(
    Uint8List data,
    String remotePath, {
    int mode = 0x1A4, // 0644 octal
  }) async {
    final t = await _device.client.transportFor(_device.serial);
    try {
      await t.sendCommand('sync:');

      // SEND <path,mode>
      final pathMode = '$remotePath,$mode';
      final pathModeBytes = utf8.encode(pathMode);
      final sendMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncSend))
        ..add(_le32(pathModeBytes.length))
        ..add(pathModeBytes);
      t.socket.add(sendMsg.toBytes());

      // DATA chunks (max 64 KB each)
      const maxChunk = 65536;
      for (var offset = 0; offset < data.length; offset += maxChunk) {
        final end = (offset + maxChunk < data.length)
            ? offset + maxChunk
            : data.length;
        final chunk = data.sublist(offset, end);
        final dataMsg = BytesBuilder(copy: false)
          ..add(utf8.encode(_syncData))
          ..add(_le32(chunk.length))
          ..add(chunk);
        t.socket.add(dataMsg.toBytes());
      }

      // DONE <mtime>
      final mtime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final doneMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncDone))
        ..add(_le32(mtime));
      t.socket.add(doneMsg.toBytes());
      await t.socket.flush();

      // Read OKAY/FAIL response (SYNC uses LE32 length, not 4-char hex)
      final status = utf8.decode(await t.readBytes(4));
      final lenBytes = await t.readBytes(4);
      final length = ByteData.view(
        Uint8List.fromList(lenBytes).buffer,
      ).getUint32(0, Endian.little);

      if (status == 'OKAY') return;
      if (status == 'FAIL') {
        final msg = utf8.decode(await t.readBytes(length));
        throw AdbError('SYNC push failed: $msg');
      }
      throw AdbError('Unexpected SYNC status: $status');
    } finally {
      final quitMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncQuit))
        ..add(_le32(0));
      t.socket.add(quitMsg.toBytes());
      await t.close();
    }
  }

  static List<int> _le32(int value) {
    final bd = ByteData(4);
    bd.setUint32(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  /// Pulls [remotePath] from the device to [localPath].
  ///
  /// Writes directly to the file stream to efficiently handle large files.
  Future<void> pull(String remotePath, String localPath) async {
    final t = await _device.client.transportFor(_device.serial);
    io.IOSink? sink;
    try {
      await t.sendCommand('sync:');

      // RECV <path>
      final pathBytes = utf8.encode(remotePath);
      final reqMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncRecv))
        ..add(_le32(pathBytes.length))
        ..add(pathBytes);
      t.socket.add(reqMsg.toBytes());
      await t.socket.flush();

      sink = io.File(localPath).openWrite();

      while (true) {
        final id = utf8.decode(await t.readBytes(4));
        if (id == _syncDone) {
          await t.readBytes(4); // discard 0
          break;
        }
        if (id == 'FAIL') {
          final lenBytes = await t.readBytes(4);
          final length = ByteData.view(
            Uint8List.fromList(lenBytes).buffer,
          ).getUint32(0, Endian.little);
          final msg = utf8.decode(await t.readBytes(length));
          throw AdbError('SYNC pull failed: $msg');
        }
        if (id != _syncData) throw AdbError('Expected DATA, got $id');

        final lenBytes = await t.readBytes(4);
        final length = ByteData.view(
          Uint8List.fromList(lenBytes).buffer,
        ).getUint32(0, Endian.little);
        final chunk = await t.readBytes(length);
        sink.add(chunk);
      }
    } finally {
      await sink?.flush();
      await sink?.close();

      final quitMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncQuit))
        ..add(_le32(0));
      t.socket.add(quitMsg.toBytes());
      await t.close();
    }
  }

  /// Returns the raw bytes of a remote file.
  Future<Uint8List> readBytes(String remotePath) async {
    final t = await _device.client.transportFor(_device.serial);
    try {
      await t.sendCommand('sync:');

      // RECV <path>
      final pathBytes = utf8.encode(remotePath);
      final reqMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncRecv))
        ..add(_le32(pathBytes.length))
        ..add(pathBytes);
      t.socket.add(reqMsg.toBytes());
      await t.socket.flush();

      final out = BytesBuilder(copy: false);
      while (true) {
        final id = utf8.decode(await t.readBytes(4));
        if (id == _syncDone) {
          await t.readBytes(4); // discard 0
          break;
        }
        if (id == 'FAIL') {
          final lenBytes = await t.readBytes(4);
          final length = ByteData.view(
            Uint8List.fromList(lenBytes).buffer,
          ).getUint32(0, Endian.little);
          final msg = utf8.decode(await t.readBytes(length));
          throw AdbError('SYNC recv failed: $msg');
        }
        if (id != _syncData) throw AdbError('Expected DATA, got $id');

        final lenBytes = await t.readBytes(4);
        final length = ByteData.view(
          Uint8List.fromList(lenBytes).buffer,
        ).getUint32(0, Endian.little);
        final chunk = await t.readBytes(length);
        out.add(chunk);
      }
      return out.toBytes();
    } finally {
      final quitMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncQuit))
        ..add(_le32(0));
      t.socket.add(quitMsg.toBytes());
      await t.close();
    }
  }

  /// Returns the text content of a remote file.
  Future<String> readText(
    String remotePath, {
    String encoding = 'utf-8',
  }) async {
    final bytes = await readBytes(remotePath);
    return utf8.decode(bytes, allowMalformed: true);
  }

  // ── Stat ──────────────────────────────────────────────────────────────────

  /// Returns basic stat info for [remotePath].
  /// Result: `{'mode': int, 'size': int, 'mtime': int}`
  Future<Map<String, int>> stat(String remotePath) async {
    final t = await _device.client.transportFor(_device.serial);
    try {
      await t.sendCommand('sync:');

      // STAT <path>
      final pathBytes = utf8.encode(remotePath);
      final reqMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncStat))
        ..add(_le32(pathBytes.length))
        ..add(pathBytes);
      t.socket.add(reqMsg.toBytes());
      await t.socket.flush();

      final id = utf8.decode(await t.readBytes(4));
      if (id != _syncStat) {
        throw AdbError('Expected STAT, got $id');
      }

      final modeBytes = await t.readBytes(4);
      final sizeBytes = await t.readBytes(4);
      final mtimeBytes = await t.readBytes(4);

      final mode = ByteData.view(
        Uint8List.fromList(modeBytes).buffer,
      ).getUint32(0, Endian.little);
      final size = ByteData.view(
        Uint8List.fromList(sizeBytes).buffer,
      ).getUint32(0, Endian.little);
      final mtime = ByteData.view(
        Uint8List.fromList(mtimeBytes).buffer,
      ).getUint32(0, Endian.little);

      return {'mode': mode, 'size': size, 'mtime': mtime};
    } finally {
      final quitMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncQuit))
        ..add(_le32(0));
      t.socket.add(quitMsg.toBytes());
      await t.close();
    }
  }

  /// Lists the contents of a remote directory using the bin command LIST of the SYNC protocol.
  ///
  /// If [includeSentinels] is false, filters out special files "." and "..".
  /// Throws [AdbError] if operation fails.
  Future<List<AdbDirEntry>> list(
    String remotePath, {
    bool includeSentinels = false,
  }) async {
    final t = await _device.client.transportFor(_device.serial);
    try {
      await t.sendCommand('sync:');

      final pathBytes = utf8.encode(remotePath);
      final reqMsg = BytesBuilder(copy: false)
        ..add(utf8.encode('LIST'))
        ..add(_le32(pathBytes.length))
        ..add(pathBytes);
      t.socket.add(reqMsg.toBytes());
      await t.socket.flush();

      final entries = <AdbDirEntry>[];
      while (true) {
        final id = utf8.decode(await t.readBytes(4));
        if (id == 'DONE') {
          await t.readBytes(16);
          break;
        }
        if (id == 'FAIL') {
          final lenBytes = await t.readBytes(4);
          final length = ByteData.view(
            Uint8List.fromList(lenBytes).buffer,
          ).getUint32(0, Endian.little);
          final msg = utf8.decode(await t.readBytes(length));
          throw AdbError('SYNC list failed: $msg');
        }
        if (id != 'DENT') {
          throw AdbError('Expected DENT or DONE, got $id');
        }

        final metaBytes = await t.readBytes(16);
        final bd = ByteData.view(Uint8List.fromList(metaBytes).buffer);
        final mode = bd.getUint32(0, Endian.little);
        final size = bd.getUint32(4, Endian.little);
        final mtimeSec = bd.getUint32(8, Endian.little);
        final namelen = bd.getUint32(12, Endian.little);

        final nameBytes = await t.readBytes(namelen);
        final name = utf8.decode(nameBytes);

        if (!includeSentinels && (name == '.' || name == '..')) {
          continue;
        }

        entries.add(
          AdbDirEntry(
            name: name,
            mode: mode,
            size: size,
            mtime: DateTime.fromMillisecondsSinceEpoch(
              mtimeSec * 1000,
              isUtc: true,
            ),
          ),
        );
      }
      return entries;
    } finally {
      final quitMsg = BytesBuilder(copy: false)
        ..add(utf8.encode(_syncQuit))
        ..add(_le32(0));
      t.socket.add(quitMsg.toBytes());
      await t.close();
    }
  }
}
