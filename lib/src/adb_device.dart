import 'dart:convert';
import 'dart:io' show File, Socket, SocketException;
import 'dart:typed_data';

import 'exceptions.dart';
import 'models/network_type.dart';
import 'models/shell_result.dart';
import 'models/app_info.dart';
import 'adb_sync.dart';
import 'adb_client.dart';

/// Provides access to device properties (equivalent to Python's `d.prop`).
class DeviceProperties {
  DeviceProperties(this._device);

  final AdbDevice _device;
  final _cache = <String, String>{};

  Future<String> get(String key, {bool cache = false}) async {
    if (cache && _cache.containsKey(key)) return _cache[key]!;
    final value = (await _device.shell('getprop $key')).trim();
    if (cache) _cache[key] = value;
    return value;
  }

  Future<String> get name => get('ro.product.name');
  Future<String> get model => get('ro.product.model');
  Future<String> get device => get('ro.product.device');
  Future<String> get brand => get('ro.product.brand');
  Future<String> get sdkVersion => get('ro.build.version.sdk');
  Future<String> get release => get('ro.build.version.release');
  Future<String> get product => get('ro.product.name');
}

/// Represents a single Android device and exposes ADB operations.
///
/// Obtain via [AdbClient.device].
class AdbDevice {
  AdbDevice({required this.serial, required this.client});

  final String serial;
  final AdbClient client;

  late final prop = DeviceProperties(this);
  late final sync = AdbSync(this);

  // ── Shell ─────────────────────────────────────────────────────────────────

  /// Runs a shell command and returns stdout+stderr as a single string.
  ///
  /// Throws [AdbTimeout] if [timeout] elapses.
  Future<String> shell(
    Object command, {
    Duration? timeout,
    String encoding = 'utf-8',
  }) async {
    final cmd = command is List ? command.join(' ') : command as String;
    final t = await client.transportFor(serial);
    try {
      await t.sendCommand('shell:$cmd');
      final raw = await t.readAll();
      return utf8.decode(raw, allowMalformed: true);
    } on SocketException catch (e) {
      throw AdbTimeout('shell timed out: $e');
    } finally {
      await t.close();
    }
  }

  /// Runs a shell command and returns a [ShellResult] with exit code.
  ///
  /// Exit code is obtained by appending `;echo EXIT:$?` to the command.
  Future<ShellResult> shell2(Object command) async {
    final cmd = command is List ? command.join(' ') : command as String;
    final output = await shell('$cmd;echo EXIT:\$?');
    final match = RegExp(r'EXIT:(\d+)\s*$').firstMatch(output);
    final returnCode = match != null ? int.parse(match.group(1)!) : -1;
    final cleanOutput = match != null
        ? output.substring(0, match.start)
        : output;
    return ShellResult(
      command: cmd,
      returnCode: returnCode,
      output: cleanOutput,
    );
  }

  // ── Device info ───────────────────────────────────────────────────────────

  Future<String> getSerialNo() => shell('getprop ro.serialno');
  Future<String> getState() async {
    final t = await client.openTransport();
    try {
      await t.sendCommand('host-serial:$serial:get-state');
      return t.readString();
    } finally {
      await t.close();
    }
  }

  /// Returns (width, height) of the display.
  Future<(int, int)> windowSize() async {
    final out = await shell('wm size');
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(out);
    if (match == null) throw AdbError('Could not parse window size: $out');
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Returns current screen rotation (0=natural, 1=left, 2=right, 3=upsidedown).
  Future<int> rotation() async {
    final out = await shell(
      'dumpsys input | grep SurfaceOrientation | head -1',
    );
    final match = RegExp(r'SurfaceOrientation: (\d)').firstMatch(out);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  /// Returns `true` if the screen is on.
  Future<bool> isScreenOn() async {
    final out = await shell('dumpsys input_method | grep mInteractive');
    return out.contains('mInteractive=true');
  }

  // ── Screenshot ────────────────────────────────────────────────────────────

  /// Returns PNG screenshot bytes.
  Future<Uint8List> screenshot() async {
    final t = await client.transportFor(serial);
    try {
      await t.sendCommand('shell:screencap -p');
      final raw = await t.readAll();
      return Uint8List.fromList(raw);
    } finally {
      await t.close();
    }
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  Future<void> click(num x, num y) => shell('input tap $x $y');

  Future<void> swipe(num x1, num y1, num x2, num y2, double durationSeconds) =>
      shell('input swipe $x1 $y1 $x2 $y2 ${(durationSeconds * 1000).toInt()}');

  Future<void> sendKeys(String text) =>
      shell('input text ${Uri.encodeComponent(text)}');

  Future<void> keyEvent(String keyCode) => shell('input keyevent $keyCode');

  // ── Apps ──────────────────────────────────────────────────────────────────

  /// Lists installed package names.
  Future<List<String>> listPackages({bool thirdPartyOnly = false}) async {
    final flag = thirdPartyOnly ? '-3' : '';
    final out = await shell('pm list packages $flag');
    return out
        .trim()
        .split('\n')
        .where((l) => l.startsWith('package:'))
        .map((l) => l.substring('package:'.length).trim())
        .toList();
  }

  /// Returns info for the currently displayed app.
  ///
  /// Tries three sources in order to support Android 9–15, where the
  /// `dumpsys activity` output format varies by vendor and API level.
  Future<ForegroundAppInfo> appCurrent() async {
    // All sources run in parallel; we pick the first non-empty match.
    final outputs = await Future.wait([
      // Most reliable on Android 10+: activity top lists running activities.
      shell('dumpsys activity top 2>/dev/null | grep "ACTIVITY " | head -1'),
      // Window manager focus — works across all versions.
      shell('dumpsys window 2>/dev/null | grep mCurrentFocus | head -1'),
      // Activity manager — key name varies by API/vendor.
      shell(
        'dumpsys activity activities 2>/dev/null'
        ' | grep -E "topResumedActivity|mResumedActivity|ResumedActivity"'
        ' | grep -v "null" | head -1',
      ),
    ]);

    final packageActivity = RegExp(
      r'([a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_][a-zA-Z0-9_]*)+)'
      r'/'
      r'([.a-zA-Z][a-zA-Z0-9_.]*)',
    );

    for (final out in outputs) {
      final match = packageActivity.firstMatch(out);
      if (match != null) {
        final pkg = match.group(1)!;
        final activity = match.group(2)!;
        final resolved = activity.startsWith('.') ? '$pkg$activity' : activity;
        return ForegroundAppInfo(packageName: pkg, activity: resolved);
      }
    }

    throw AdbError(
      'Could not parse current app. Raw outputs:\n${outputs.join('\n')}',
    );
  }

  // ── Forward / reverse ─────────────────────────────────────────────────────

  /// Creates a port forward: `local` → `remote`.
  Future<void> forward(String local, String remote) async {
    final t = await client.openTransport();
    try {
      await t.sendCommand('host-serial:$serial:forward:$local;$remote');
    } finally {
      await t.close();
    }
  }

  /// Removes a forward rule by its [local] address.
  Future<void> forwardRemove(String local) async {
    final t = await client.openTransport();
    try {
      await t.sendCommand('host-serial:$serial:killforward:$local');
    } finally {
      await t.close();
    }
  }

  Future<void> forwardRemoveAll() async {
    final t = await client.openTransport();
    try {
      await t.sendCommand('host-serial:$serial:killforward-all');
    } finally {
      await t.close();
    }
  }

  /// Creates a reverse port forward: `remote` → `local`.
  Future<void> reverse(String remote, String local) =>
      shell('reverse:$remote;$local');

  // ── Socket connection ─────────────────────────────────────────────────────

  /// Opens a raw socket connection through the device.
  ///
  /// Example: `createConnection(NetworkType.localAbstract, 'scrcpy')`
  Future<Socket> createConnection(NetworkType type, Object address) async {
    final t = await client.transportFor(serial);
    await t.sendCommand('${type.prefix}:$address');
    // Return the underlying socket for caller to use directly
    return t.socket;
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  Future<void> root() => shell('root:');
  Future<void> tcpip(int port) => shell('tcpip:$port');

  Future<void> openBrowser(String url) =>
      shell('am start -a android.intent.action.VIEW -d "$url"');

  Future<void> volumeUp({int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await keyEvent('KEYCODE_VOLUME_UP');
    }
  }

  Future<void> volumeDown({int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await keyEvent('KEYCODE_VOLUME_DOWN');
    }
  }

  Future<void> volumeMute() => keyEvent('KEYCODE_VOLUME_MUTE');

  /// Installs an APK, equivalent to `adb install [flags] <apkPath>`.
  ///
  /// Streams the APK bytes directly to the device via
  /// `exec:cmd package install -S <size>` — no temp file needed.
  Future<String> install({
    required String apkPath,
    bool replace = false,
    bool allowTest = false,
    bool allowDowngrade = false,
    bool grantAllPermissions = false,
    bool instantApp = false,
  }) async {
    final bytes = await File(apkPath).readAsBytes();

    final args = <String>[];
    if (replace) args.add('-r');
    if (allowTest) args.add('-t');
    if (allowDowngrade) args.add('-d');
    if (grantAllPermissions) args.add('-g');
    if (instantApp) args.add('--instant');
    args.addAll(['-S', '${bytes.length}']);

    final t = await client.transportFor(serial);
    try {
      await t.sendCommand('exec:cmd package install ${args.join(' ')}');
      t.socket.add(bytes);
      await t.socket.flush();
      final raw = await t.readAll();
      return utf8.decode(raw, allowMalformed: true);
    } finally {
      await t.close();
    }
  }

  /// Uninstalls a package, equivalent to `adb uninstall <packageName>`.
  Future<String> uninstall({required String packageName}) async {
    final t = await client.transportFor(serial);
    try {
      await t.sendCommand('exec:cmd package uninstall $packageName');
      final raw = await t.readAll();
      return utf8.decode(raw, allowMalformed: true);
    } finally {
      await t.close();
    }
  }

  @override
  String toString() =>
      'AdbDevice(serial: $serial, model: ${prop.model},  product: ${prop.product})';
}
