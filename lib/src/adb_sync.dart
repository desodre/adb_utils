import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'exceptions.dart';
import 'adb_device.dart';

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
  Future<void> pull(String remotePath, String localPath) async {
    final bytes = await readBytes(remotePath);
    await io.File(localPath).writeAsBytes(bytes);
  }

  /// Returns the raw bytes of a remote file.
  Future<Uint8List> readBytes(String remotePath) async {
    // TODO: Implement full ADB SYNC protocol RECV command
    throw UnimplementedError('SYNC readBytes not yet implemented');
  }

  /// Returns the text content of a remote file.
  Future<String> readText(
    String remotePath, {
    String encoding = 'utf-8',
  }) async {
    final bytes = await readBytes(remotePath);
    return utf8.decode(bytes);
  }

  // ── Stat ──────────────────────────────────────────────────────────────────

  /// Returns basic stat info for [remotePath].
  /// Result: `{'mode': int, 'size': int, 'mtime': int}`
  Future<Map<String, int>> stat(String remotePath) async {
    // TODO: Implement ADB SYNC STAT command
    throw UnimplementedError('SYNC stat not yet implemented');
  }
}
