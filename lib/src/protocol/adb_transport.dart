import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../exceptions.dart';

/// Handles low-level communication with the ADB server using the ADB wire protocol.
///
/// Protocol:
///   - Client → Server: 4-char hex length + UTF-8 payload
///   - Server → Client: "OKAY" or "FAIL" followed by 4-char hex length + message
class AdbTransport {
  AdbTransport(this.socket) {
    // Subscription MUST be started eagerly so buffered data is captured
    // before any read call is made.
    _sub = socket.listen(_onData, onDone: _onDone, onError: _onError);
  }

  /// The underlying TCP socket. Use for raw byte access (e.g., [AdbDevice.createConnection]).
  final Socket socket;

  late final StreamSubscription<List<int>> _sub;
  final _buffer = <int>[];
  bool _closed = false;
  Object? _socketError;

  // Completer woken up whenever new data arrives, so _readExact avoids polling.
  Completer<void>? _dataWaiter;

  void _onData(List<int> chunk) {
    _buffer.addAll(chunk);
    _dataWaiter?.complete();
    _dataWaiter = null;
  }

  void _onDone() {
    _closed = true;
    _dataWaiter?.complete();
    _dataWaiter = null;
  }

  void _onError(Object error) {
    _socketError = error;
    _dataWaiter?.completeError(error);
    _dataWaiter = null;
  }

  /// Wraps an existing [Socket] into an [AdbTransport].
  static Future<AdbTransport> connect(
    String host,
    int port, {
    Duration? timeout,
  }) async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: timeout ?? const Duration(seconds: 10),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    return AdbTransport(socket);
  }

  /// Sends a message with the ADB 4-hex-char length prefix.
  Future<void> send(String message) async {
    final encoded = utf8.encode(message);
    final header = encoded.length
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    socket.add(utf8.encode(header) + encoded);
    await socket.flush();
  }

  /// Reads exactly [n] bytes. Waits efficiently via a Completer;
  /// throws [AdbError] if the socket closes before enough bytes arrive.
  Future<List<int>> _readExact(int n) async {
    while (_buffer.length < n) {
      if (_socketError != null) {
        throw AdbError('Socket error: $_socketError');
      }
      if (_closed) {
        throw AdbError(
          'Connection closed before receiving $n bytes '
          '(got ${_buffer.length})',
        );
      }
      _dataWaiter = Completer<void>();
      await _dataWaiter!.future;
    }
    final result = _buffer.sublist(0, n);
    _buffer.removeRange(0, n);
    return result;
  }

  /// Reads the 4-char hex length prefix, then that many bytes.
  Future<String> readString() async {
    final lenBytes = await _readExact(4);
    final length = int.parse(utf8.decode(lenBytes), radix: 16);
    final data = await _readExact(length);
    return utf8.decode(data);
  }

  /// Reads all bytes until the socket closes (e.g., shell output).
  Future<List<int>> readAll() async {
    await _sub.asFuture<void>();
    return List<int>.from(_buffer);
  }

  /// Reads an "OKAY" / "FAIL" status from the server.
  /// Returns on OKAY, throws [AdbError] on FAIL.
  Future<void> readOkay() async {
    final status = utf8.decode(await _readExact(4));
    if (status == 'OKAY') return;
    if (status == 'FAIL') {
      final message = await readString();
      throw AdbError(message);
    }
    throw AdbError('Unexpected status: $status');
  }

  /// Sends a command and validates the OKAY response.
  Future<void> sendCommand(String command) async {
    await send(command);
    await readOkay();
  }

  Future<void> close() async {
    await _sub.cancel();
    await socket.close();
  }
}
