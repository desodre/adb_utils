import 'dart:convert';
import 'dart:io';

import '../adb_device.dart';

/// Client responsible for installing and communicating with the Phantom
/// UiAutomator agent running on an Android device.
class PhantomClient {
  PhantomClient({required this.device, this.port = 9008});

  /// Target device used for all ADB operations.
  final AdbDevice device;

  /// TCP port exposed by the Phantom agent.
  final int port;

  /// Pushes APKs, installs them, starts the instrumentation agent and
  /// configures TCP forwarding for local communication.
  Future<void> startAgent(String targetApkPath, String agentApkPath) async {
    const targetRemotePath = '/data/local/tmp/target.apk';
    const agentRemotePath = '/data/local/tmp/agent.apk';

    await device.sync.push(targetApkPath, targetRemotePath);
    await device.sync.push(agentApkPath, agentRemotePath);

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
  }

  /// Sends a JSON payload to the Phantom agent and returns the decoded
  /// JSON response.
  Future<Map<String, dynamic>> _sendJsonPayload(
    Map<String, dynamic> payload,
  ) async {
    Socket? socket;
    try {
      socket = await Socket.connect('127.0.0.1', port);
      socket.writeln(jsonEncode(payload));
      await socket.flush();

      final bytes = <int>[];
      await for (final chunk in socket) {
        bytes.addAll(chunk);
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
