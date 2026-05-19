# Core Concepts

Referência conceitual das principais classes públicas expostas pelo pacote.

## AdbClient

**Responsabilidade:** conexão com o servidor ADB e operações host-scoped.

Principais capacidades:

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

**Responsabilidade:** operações por dispositivo Android.

Principais capacidades:

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

**Responsabilidade:** transferência de ficheiros via protocolo SYNC.

Principais capacidades:

- `push(local, remote)`
- `pull(remote, local)`
- `readBytes(remote)`
- `readText(remote)`
- `stat(remote)`

## PhantomClient

**Responsabilidade:** automação UI baseada em agent instrumentado e socket TCP.

Principais capacidades:

- `startAgent(targetApkPath, agentApkPath)`
- `dumpWindow()`
- `dumpWindowHierarchy()`
- `clickByText(text)`
- `startVideoStream()` (H.264 raw stream)

Exemplo:

```dart
final phantom = PhantomClient(device: d, port: 9008);
await phantom.startAgent(
  'lib/src/phantom/apks/target.apk',
  'lib/src/phantom/apks/agent.apk',
);
final ok = await phantom.clickByText('Entrar');
print(ok);
```

## UiHierarchy / UiNode / Bounds

**Responsabilidade:** modelo tipado da árvore XML de UI.

Uso comum:

```dart
final hierarchy = await phantom.dumpWindowHierarchy();
print('Rotation: ${hierarchy.rotation}');
print('Root nodes: ${hierarchy.nodes.length}');
```

## Reporting Types

Para documentação e pipelines de teste:

- `TestResult`
- `HtmlReporter`
- `TestRunner`

Fluxo típico:

```dart
final runner = TestRunner();
await runner.runTest('Smoke', 'ci', () async {});
await HtmlReporter(outputPath: 'report.html').writeReport(runner.resultados);
```

