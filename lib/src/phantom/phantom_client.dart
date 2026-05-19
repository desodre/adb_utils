import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../adb_device.dart';
import '../models/ui_hierarchy.dart';
import 'phantom_binaries.dart';

/// Client responsible for installing and communicating with the Phantom
/// UiAutomator agent running on an Android device.
class PhantomClient {
  PhantomClient({required this.device, this.port = 9008}) {
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(
        port,
        'port',
        'Port must be between 1 and 65535',
      );
    }
  }

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _responseTimeout = Duration(seconds: 10);
  static const int _maxResponseBytes = 1024 * 1024;

  /// Target device used for all ADB operations.
  final AdbDevice device;

  /// TCP port exposed by the Phantom agent.
  final int port;

  /// Pushes embedded APKs, installs them, starts the instrumentation agent and
  /// configures TCP forwarding for local communication.
  Future<void> startAgent() async {
    const targetRemotePath = '/data/local/tmp/target.apk';
    const agentRemotePath = '/data/local/tmp/agent.apk';
    final tempDir = await Directory.systemTemp.createTemp('adb_utils_phantom_');
    final targetTempFile = File(
      '${tempDir.path}${Platform.pathSeparator}target_temp.apk',
    );
    final agentTempFile = File(
      '${tempDir.path}${Platform.pathSeparator}agent_temp.apk',
    );

    await targetTempFile.writeAsBytes(
      base64Decode(targetApkBase64),
      flush: true,
    );
    await agentTempFile.writeAsBytes(base64Decode(agentApkBase64), flush: true);

    try {
      await device.sync.push(targetTempFile.path, targetRemotePath);
      await device.sync.push(agentTempFile.path, agentRemotePath);

      await device.shell('pm install -t -r $targetRemotePath');
      await device.shell('pm install -t -r $agentRemotePath');

      await device.shell('am force-stop com.example.phantom_agent');
      await device.shell(
        'nohup am instrument -w '
        'com.example.phantom_agent.test/androidx.test.runner.AndroidJUnitRunner '
        '> /dev/null 2>&1 &',
      );

      await Future.delayed(const Duration(seconds: 2));
      await device.forward('tcp:$port', 'tcp:$port');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Starts the Phantom raw video stream over TCP.
  ///
  /// The returned stream is a continuous byte stream where each chunk contains
  /// raw H.264 data (NAL units) produced by the Android agent. Consumers are
  /// expected to parse/decode those NAL units according to their media pipeline.
  Future<Stream<List<int>>> startVideoStream() async {
    await device.forward('tcp:9009', 'tcp:9009');
    final socket = await Socket.connect('127.0.0.1', 9009);
    return socket;
  }

  /// Sends a JSON payload to the Phantom agent and returns the decoded
  /// JSON response.
  Future<Map<String, dynamic>> _sendJsonPayload(
    Map<String, dynamic> payload,
  ) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: _connectTimeout,
      );
      socket.writeln(jsonEncode(payload));
      await socket.flush();

      final bytes = <int>[];
      await for (final chunk in socket.timeout(_responseTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxResponseBytes) {
          throw Exception(
            'Phantom agent response exceeded $_maxResponseBytes bytes',
          );
        }
      }

      if (bytes.isEmpty) {
        throw Exception('Empty response from Phantom agent');
      }

      final decoded = jsonDecode(utf8.decode(bytes)) as Object?;
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response format from Phantom agent');
      }
      return decoded;
    } finally {
      socket?.destroy();
    }
  }

  /// Requests the current UI hierarchy XML from the Phantom agent.
  ///
  /// Throws [Exception] when the agent returns a non-success status.
  Future<String> dumpWindow() async {
    final response = await _sendJsonPayload({'action': 'dumpWindow'});
    if (response['status'] == 'success') {
      return response['xml'] as String;
    }
    throw Exception(
      'Failed to dump window: ${response['message'] ?? response}',
    );
  }

  /// Requests and parses the current UI hierarchy into [UiHierarchy].
  Future<UiHierarchy> dumpWindowHierarchy() async {
    final xml = await dumpWindow();
    return UiHierarchy.fromXmlString(xml);
  }

  /// Clicks the first node matching [text].
  ///
  /// Returns `true` when the operation succeeds.
  Future<bool> clickByText(String text) async {
    final response = await _sendJsonPayload({
      'action': 'clickByText',
      'text': text,
    });
    return response['status'] == 'success';
  }
}

extension PhantomAdbDeviceExtension on AdbDevice {
  PhantomClient get phantom => PhantomClient(device: this);
}
