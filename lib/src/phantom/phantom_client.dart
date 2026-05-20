import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../adb_device.dart';
import '../logging/adb_logging.dart';
import '../models/ui_hierarchy.dart';
import 'phantom_binaries.dart';

/// Client responsible for installing and communicating with the Phantom
/// UiAutomator agent running on an Android device.
class PhantomClient {
  PhantomClient({required this.device, this.port = 9008, int? videoPort})
    : _hostCommandPort = port,
      _hostVideoPort = videoPort ?? (port + 1) {
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(
        port,
        'port',
        'Port must be between 1 and 65535',
      );
    }
    final resolvedVideoPort = videoPort ?? (port + 1);
    if (resolvedVideoPort < 1 || resolvedVideoPort > 65535) {
      throw ArgumentError.value(
        resolvedVideoPort,
        'videoPort',
        'Port must be between 1 and 65535',
      );
    }
  }

  static const Duration _connectTimeout = Duration(seconds: 5);
  static const int _maxResponseBytes = 1024 * 1024;
  static const String _agentPackage = 'com.example.phantom_agent';
  static const String _agentTestPackage = 'com.example.phantom_agent.test';
  static const String _portsFilePath = 'files/phantom_ports.json';
  static const String _commandPortKey = 'commandPort';
  static const String _videoPortKey = 'videoPort';
  static const String _commandPortJsonKey = 'command_port';
  static const String _videoPortJsonKey = 'video_port';

  /// Target device used for all ADB operations.
  final AdbDevice device;
  late final Logger _logger = Logger('PhantomClient.${device.serial}');

  /// Initial fallback command port exposed by the Phantom agent.
  final int port;
  int _hostCommandPort;
  int _hostVideoPort;
  int? _deviceCommandPort;
  int? _deviceVideoPort;

  int get hostCommandPort => _hostCommandPort;
  int get hostVideoPort => _hostVideoPort;
  int? get deviceCommandPort => _deviceCommandPort;
  int? get deviceVideoPort => _deviceVideoPort;

  /// Pushes embedded APKs, installs them, starts the instrumentation agent and
  /// configures TCP forwarding for local communication.
  Future<void> startAgent() async {
    const targetRemotePath = '/data/local/tmp/target.apk';
    const agentRemotePath = '/data/local/tmp/agent.apk';
    const packageName = _agentPackage;
    const testRunner = 'androidx.test.runner.AndroidJUnitRunner';
    final stopwatch = Stopwatch()..start();
    _logger.info('Starting PhantomAgent bootstrap');

    if (await _shouldInstallPackages()) {
      _logger.info('Phantom packages missing; pushing and installing APKs');
      final tempDir = await Directory.systemTemp.createTemp(
        'adb_utils_phantom_',
      );
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
      await agentTempFile.writeAsBytes(
        base64Decode(agentApkBase64),
        flush: true,
      );

      try {
        await device.sync.push(targetTempFile.path, targetRemotePath);
        await device.sync.push(agentTempFile.path, agentRemotePath);

        await device.shell('pm install -t -r $targetRemotePath');
        await device.shell('pm install -t -r $agentRemotePath');
        _logger.fine('Phantom APK installation completed');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    } else {
      _logger.fine('Phantom packages already installed; skipping APK install');
    }

    await device.shell('am force-stop $_agentPackage');
    await device.shell('run-as $_agentPackage rm -f $_portsFilePath');
    final instrumentationCommand =
        'am instrument -w -e class $packageName.PhantomServer#startServer '
        '$packageName.test/$testRunner';
    unawaited(() async {
      try {
        await device.shell(instrumentationCommand);
        _logger.fine('Instrumentation process finished');
      } catch (e, st) {
        _logger.warning('Instrumentation process failed', e, st);
      }
    }());
    _logger.fine('Instrumentation process started');

    final dynamicPorts = await _readPortsFromFile();
    await device.shell('run-as $_agentPackage rm -f $_portsFilePath');
    final deviceCommandPort = dynamicPorts[_commandPortKey]!;
    final deviceVideoPort = dynamicPorts[_videoPortKey]!;
    _logger.shout(
      'Dynamic ports detected: CMD=$deviceCommandPort VID=$deviceVideoPort',
    );
    final hostCommandPort = await _reserveHostPort();
    final hostVideoPort = await _reserveHostPort();

    await device.forward('tcp:$hostCommandPort', 'tcp:$deviceCommandPort');
    await device.forward('tcp:$hostVideoPort', 'tcp:$deviceVideoPort');
    _logger.info(
      'TCP tunnels established: hostCmd=$hostCommandPort->deviceCmd=$deviceCommandPort, hostVid=$hostVideoPort->deviceVid=$deviceVideoPort',
    );
    _hostCommandPort = hostCommandPort;
    _hostVideoPort = hostVideoPort;
    _deviceCommandPort = deviceCommandPort;
    _deviceVideoPort = deviceVideoPort;

    try {
      await _waitForAgentHealth();
    } on TimeoutException catch (e) {
      final logcat = await device.shell(
        'logcat -d -s AndroidRuntime PhantomServer | tail -n 25',
      );
      _logger.severe('Phantom health-check failed', e);
      throw Exception('${e.message}\n\nRecent logcat:\n$logcat');
    }
    stopwatch.stop();
    _logger.info(
      'PhantomAgent initialized successfully in ${stopwatch.elapsedMilliseconds}ms',
    );
  }

  /// Starts the Phantom raw video stream over TCP.
  ///
  /// The returned stream is a continuous byte stream where each chunk contains
  /// raw H.264 data (NAL units) produced by the Android agent. Consumers are
  /// expected to parse/decode those NAL units according to their media pipeline.
  Future<Stream<List<int>>> startVideoStream() async {
    _logger.info('Opening H.264 video stream on host port $_hostVideoPort');
    final socket = await Socket.connect('127.0.0.1', _hostVideoPort);
    socket.done.then(
      (_) => _logger.fine('H.264 video stream closed'),
      onError: (Object e, StackTrace st) =>
          _logger.warning('H.264 video stream closed with error', e, st),
    );
    return socket;
  }

  /// Sends a JSON payload to the Phantom agent and returns the decoded
  /// JSON response.
  Future<Map<String, dynamic>> _sendJsonPayload(
    Map<String, dynamic> payload,
  ) async {
    Socket? socket;
    try {
      final action = payload['action'];
      socket = await Socket.connect(
        '127.0.0.1',
        _hostCommandPort,
        timeout: _connectTimeout,
      );
      _logger.fine('Sending Phantom JSON action="$action"');
      socket.writeln(jsonEncode(payload));
      await socket.flush();

      final responseBytes = <int>[];
      await for (final chunk in socket) {
        responseBytes.addAll(chunk);
        if (responseBytes.length > _maxResponseBytes) {
          _logger.severe('Phantom response exceeded maximum payload size');
          throw Exception(
            'Phantom agent response exceeded $_maxResponseBytes bytes',
          );
        }
      }

      if (responseBytes.isEmpty) {
        throw Exception('Empty response from Phantom agent');
      }

      final decoded = jsonDecode(utf8.decode(responseBytes)) as Object?;
      if (decoded is! Map<String, dynamic>) {
        _logger.severe('Phantom response parsing failed: invalid JSON shape');
        throw Exception('Invalid response format from Phantom agent');
      }
      _logger.fine('Phantom action="$action" completed');
      return decoded;
    } catch (e, st) {
      _logger.severe('Phantom JSON exchange failed', e, st);
      rethrow;
    } finally {
      socket?.destroy();
    }
  }

  Future<bool> _shouldInstallPackages() async {
    final output = await device.shell('pm list packages | grep $_agentPackage');
    return !(output.contains('package:$_agentPackage') &&
        output.contains('package:$_agentTestPackage'));
  }

  Future<Map<String, int>> _readPortsFromFile() async {
    const attempts = 20;
    const interval = Duration(milliseconds: 300);
    var lastFileOutput = '';

    for (var i = 0; i < attempts; i++) {
      final result = await device.shell(
        'run-as $_agentPackage cat $_portsFilePath',
      );
      final trimmed = result.trim();
      lastFileOutput = result;

      if (trimmed.isNotEmpty &&
          !trimmed.contains('No such file or directory')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            final commandPort = decoded[_commandPortJsonKey];
            final videoPort = decoded[_videoPortJsonKey];
            final parsedCommandPort = switch (commandPort) {
              int value => value,
              String value => int.tryParse(value),
              _ => null,
            };
            final parsedVideoPort = switch (videoPort) {
              int value => value,
              String value => int.tryParse(value),
              _ => null,
            };
            if (parsedCommandPort != null && parsedVideoPort != null) {
              return {
                _commandPortKey: parsedCommandPort,
                _videoPortKey: parsedVideoPort,
              };
            }
          }
        } on FormatException {
          _logger.warning(
            'Handshake file not fully written yet; retrying JSON parse',
          );
        }
      }

      if (i < attempts - 1) {
        _logger.warning('Handshake file polling retry (${i + 1}/$attempts)');
        await Future<void>.delayed(interval);
      }
    }

    _logger.severe(
      'Handshake file polling timed out after $attempts attempts. '
      'Last file content: ${truncateForLog(lastFileOutput)}',
    );
    throw TimeoutException(
      'Could not read dynamic Phantom ports file after $attempts '
      'attempts. Last file content:\n$lastFileOutput',
    );
  }

  Future<int> _reserveHostPort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final reservedPort = server.port;
    await server.close();
    return reservedPort;
  }

  Future<void> _waitForAgentHealth() async {
    const maxAttempts = 10;
    const backoff = Duration(milliseconds: 300);
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _hostCommandPort,
          timeout: backoff,
        );
        socket.destroy();
        return;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          _logger.warning(
            'Phantom health-check retry ($attempt/$maxAttempts): $e',
          );
          await Future<void>.delayed(backoff);
        }
      }
    }

    _logger.severe(
      'Phantom health-check timed out after $maxAttempts attempts: $lastError',
    );
    throw TimeoutException(
      'Phantom agent did not become healthy after $maxAttempts attempts '
      'on localhost:$_hostCommandPort. Last error: $lastError',
    );
  }

  /// Requests the current UI hierarchy XML from the Phantom agent.
  ///
  /// Throws [Exception] when the agent returns a non-success status.
  Future<String> dumpWindow() async {
    final response = await _sendJsonPayload({'action': 'dumpWindow'});
    if (response['status'] == 'success') {
      final xml = response['xml'] as String;
      _logger.fine(
        'UI dump received successfully (size: ${utf8.encode(xml).length} bytes)',
      );
      return xml;
    }
    _logger.severe('dumpWindow failed: ${response['message'] ?? response}');
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
    final ok = response['status'] == 'success';
    if (!ok) {
      _logger.warning('clickByText failed for "$text": ${response['message']}');
    }
    return ok;
  }
}

extension PhantomAdbDeviceExtension on AdbDevice {
  PhantomClient get phantom => PhantomClient(device: this);
}
