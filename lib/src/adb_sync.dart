import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'exceptions.dart';
import 'adb_device.dart';

// SYNC protocol command codes — used when implementing the SYNC protocol.
// ignore_for_file: unused_element
const _syncData = 'DATA';
const _syncDone = 'DONE';
const _syncRecv = 'RECV';
const _syncSend = 'SEND';
const _syncStat = 'STAT';
const _syncList = 'LIST';
const _syncQuit = 'QUIT';

/// File transfer operations via the ADB SYNC protocol.
///
/// Access via [AdbDevice.sync].
class AdbSync {
  AdbSync(this._device);

  // ignore: unused_field
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

  Future<void> _pushBytes(Uint8List data, String remotePath) async {
    // TODO: Implement full ADB SYNC protocol SEND command
    // See: https://cs.android.com/android/platform/superproject/+/master:packages/modules/adb/SYNC.TXT
    throw UnimplementedError('SYNC push not yet implemented');
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
