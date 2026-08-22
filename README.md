# adb_utils

[![pub.dev](https://img.shields.io/pub/v/adb_utils.svg)](https://pub.dev/packages/adb_utils)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.11-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Dart library for interacting with the ADB (Android Debug Bridge) server and Android devices through the native socket protocol. Inspired by Python's [openatx/adbutils](https://github.com/openatx/adbutils).

This library communicates directly with the local ADB server over TCP (`127.0.0.1:5037`), avoiding repeated, inefficient invocations of the `adb` executable.

---

## Features

- **Device management**: list, connect, disconnect, and track device state.
- **Shell execution**: run commands and capture output and exit codes (`returnCode`).
- **Installation and apps**: install/uninstall APKs through byte streaming and retrieve advanced app information (`dumpsys`).
- **Interaction**: capture native screenshot bytes and simulate taps, swipes, and key events.
- **Sockets and forwarding**: create local/reverse port forwards and raw socket connections to device services.
- **Native SYNC file transfer**: push, read, inspect, and list files through ADB SYNC.
- **Phantom (UiAutomator agent)**: orchestrate instrumented-agent startup and send JSON actions over TCP.
- **Phantom video stream (H.264)**: consume a raw video stream (NAL units) through dynamically discovered ports.
- **HTML test report**: automatically generate `report.html` after `dart test`, including detailed failure evidence.

---

## Getting Started

### Requirements

- Dart SDK `^3.11.4`
- ADB (Android Debug Bridge) installed and its server running (`adb start-server`).

### Installation

Add `adb_utils` to your `pubspec.yaml`:

```yaml
dependencies:
  adb_utils: ^0.4.7
```

Then install it with:

```sh
dart pub get
```

---

## Tests

```sh
# Runs every available test through the aggregate tag
dart test --tags all_possible
```

---

## Usage

Here is a quick example of connecting to ADB and reading a device model:

```dart
import 'package:adb_utils/adb_utils.dart';

void main() async {
  final adb = AdbClient();

  // List all connected devices
  for (final d in await adb.deviceList()) {
    print('${d.serial} - ${d.state.name} - ${d.model ?? ''}');
  }

  // Get a device (throws when none are connected)
  final device = await adb.device();
  
  // Read properties through `getprop`, with optional native caching
  print(await device.prop.model);        // e.g. "Pixel 7"
  
  // Execute a shell command
  print(await device.shell('uname -r')); // kernel version
}
```

---

## Detailed API

### `AdbClient`

`AdbClient` is the library entry point. It represents the connection to the ADB server on your machine.

```dart
final adb = AdbClient(
  host: '127.0.0.1',
  port: 5037,
  socketTimeout: Duration(seconds: 10),
);

// Get a device by serial or transport ID
final d1 = await adb.device(serial: '8d1f93be');
final d2 = await adb.device(transportId: 24);

// Connect over TCP (equivalent to adb connect)
await adb.connect('192.168.1.100:5555');

// Track additions, state changes, and removals in real time
await for (final event in adb.trackDevices()) {
  print('${event.serial} conectado? ${event.present}');
}
```

### `AdbDevice`

`AdbDevice` represents a specific Android device.

**Shell and properties**
```dart
String out = await d.shell('ls -l /sdcard');

// shell2 returns a ShellResult with the exit code (returnCode).
ShellResult result = await d.shell2('ls /root');
print(result.returnCode); // 0 = success; any other value = error.

// Convenient shortcuts for properties (getprop)
print(await d.prop.sdkVersion); // e.g. "33"
```

**Display information and screenshots**
```dart
var (width, height) = await d.windowSize();
bool isScreenOn = await d.isScreenOn();

// Capture the screen directly as binary data (without saving a device file)
Uint8List png = await d.screenshot();
```

**Taps and keys**
```dart
await d.click(540, 960);
await d.swipe(100, 500, 100, 200, 0.3); // start X,Y -> end X,Y in 0.3s
await d.sendKeys('Hello World!');
await d.keyEvent('KEYCODE_HOME');
```

**APK and package management**
```dart
// Install an APK through socket streaming (no manual push required)
await d.install(
  apkPath: 'build/app.apk',
  replace: true, 
  grantAllPermissions: true,
);

await d.uninstall(packageName: 'com.example.app');

// Get the app currently displayed on screen
ForegroundAppInfo app = await d.appCurrent();
```

### File Transfer (`AdbSync`)

Operations through the native ADB SYNC transfer protocol (`adb.sync`).

```dart
// PUSH (local -> Android)
await d.sync.push('/local/path/file.txt', '/sdcard/file.txt');
await d.sync.push(Uint8List.fromList([...]), '/sdcard/data.bin'); // directly from memory

// PULL (Android -> local)
await d.sync.pull('/sdcard/config.json', '/local/path/config.json'); // writes directly to disk (streaming)

// READ (Android -> local memory)
Uint8List bytes = await d.sync.readBytes('/sdcard/config.json');
String texto    = await d.sync.readText('/sdcard/config.json');

// STAT (read size and modification information)
Map<String, int> info = await d.sync.stat('/sdcard/file.txt');
// returns data such as: {'mode': 33188, 'size': 1024, 'mtime': 16843453}
```

### UiAutomator Agent (`PhantomClient`)

For UI automation through the instrumented agent:

```dart
import 'package:adb_utils/adb_utils.dart';

final adb = AdbClient();
final d = await adb.device();

final phantom = d.phantom;
await phantom.startAgent();

final xml = await phantom.dumpWindow();
final hierarchy = await phantom.dumpWindowHierarchy();
final clicked = await phantom.clickByText('Entrar');
final videoStream = await phantom.startVideoStream();

await for (final nalChunk in videoStream) {
  // `nalChunk` contains raw H.264 bytes (NAL units).
  // Send it to your decoder/player.
}

print(xml);
print('rotation => ${hierarchy.rotation}');
print('clickByText => $clicked');
```

`startAgent` pushes APKs to `/data/local/tmp` when needed, installs them with
`pm install -t -r`, force-stops the old agent, starts instrumentation with the
explicit `PhantomServer#startServer` class, reads the JSON handshake at
`context.filesDir/phantom_ports.json`, and discovers dynamic
`command_port`/`video_port` values through `run-as com.example.phantom_agent`.

The client then reserves free host ports and automatically applies:

- `adb forward tcp:<host_command_port> tcp:<device_command_port>`
- `adb forward tcp:<host_video_port> tcp:<device_video_port>`

`startVideoStream()` uses the dynamic mapping resolved by `startAgent()` and
returns a continuous `Stream<List<int>>` containing raw H.264 video (NAL
units), without hard-coded ports.

---

## Automatic HTML Report After `dart test`

When you run:

```sh
dart test
```

the project automatically generates a `report.html` file in the root containing:

- a summary panel (total, passed, failed, total duration);
- a table of every executed test;
- highlighted failure evidence with a dark-red background, monospace `<pre><code>` block, and horizontal scrolling for long messages.

### Available reporting APIs

Reporting APIs are also exported by the main barrel:

```dart
import 'package:adb_utils/adb_utils.dart';

final result = TestResult(
  nome: 'Connect through socket',
  categoria: 'Connectivity',
  duracao: const Duration(milliseconds: 120),
  passou: true,
);

final reporter = HtmlReporter(outputPath: 'report.html');
await reporter.writeReport([result]);
```

### Sequential execution wrapper (`TestRunner`)

For custom scenarios outside `package:test`, use:

```dart
final runner = TestRunner();
await runner.runTest('Name', 'Category', () async {
  // asynchronous test logic
});
await HtmlReporter(outputPath: 'report.html').writeReport(runner.resultados);
```

> Note: temporary report aggregation files are written to `logs/test-report/`.

---

## Error Handling

The library represents unsuccessful responses with three `Exception`-based types in `exceptions.dart`:

| Exception | Description |
| --- | --- |
| `AdbError` | The ADB server returned `FAIL` or a malformed protocol response. |
| `AdbTimeout` | The socket reached its timeout or a shell connection lost access. |
| `AdbInstallError` | An installation (`install`) session reported a specific error. |

---

## License

This project is distributed under the [MIT License](LICENSE).
