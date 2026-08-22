# Core Concepts

Conceptual reference for the package's primary public classes.

## AdbClient

**Responsibility:** connection to the ADB server and host-scoped operations.

Key capabilities:

- `serverVersion()`
- `deviceList()`
- `device(serial:, transportId:)`
- `connect()` / `disconnect()`
- `trackDevices()`

Exemplo:

```dart
final adb = AdbClient();
final devices = await adb.deviceList();
final d = await adb.device(serial: devices.first.serial);
```

## AdbDevice

**Responsibility:** Android device-scoped operations.

Key capabilities:

- shell: `shell()`, `shell2()`
- input: `click()`, `swipe()`, `sendKeys()`, `keyEvent()`
- media/display: `screenshot()`, `windowSize()`, `rotation()`
- apps: `install()`, `uninstall()`, `appInfo()`, `appCurrent()`
- networking: `forward()`, `forwardRemove()`, `createConnection()`
- files: `sync` (`AdbSync`)

Exemplo:

```dart
final model = await d.prop.model;
final result = await d.shell2('echo hello');
print(result.returnCode);
```

## AdbSync

**Responsibility:** file transfer through the SYNC protocol.

Principais capacidades:

- `push(local, remote)`
- `pull(remote, local)`
- `readBytes(remote)`
- `readText(remote)`
- `stat(remote)`

## PhantomClient

**Responsibility:** UI automation based on an instrumented agent and TCP socket.

Principais capacidades:

- `startAgent()`
- `dumpWindow()`
- `dumpWindowHierarchy()`
- `clickByText(text)`
- `startVideoStream()` (H.264 raw stream)

Exemplo:

```dart
final phantom = d.phantom;
await phantom.startAgent();
final ok = await phantom.clickByText('Entrar');
print(ok);
```

## UiHierarchy / UiNode / Bounds

**Responsibility:** typed UI XML tree model.

Common usage:

```dart
final hierarchy = await phantom.dumpWindowHierarchy();
print('Rotation: ${hierarchy.rotation}');
print('Root nodes: ${hierarchy.nodes.length}');
```

## Reporting Types

For reporting and test pipelines:

- `TestResult`
- `HtmlReporter`
- `TestRunner`

Typical flow:

```dart
final runner = TestRunner();
await runner.runTest('Smoke', 'ci', () async {});
await HtmlReporter(outputPath: 'report.html').writeReport(runner.resultados);
```
