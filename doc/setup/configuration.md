# Configuration

Advanced configuration for production, CI, and Phantom UI automation.

## AdbClient Configuration

`AdbClient` lets you customize the ADB server host, port, and socket timeout:

```dart
import 'package:adb_utils/adb_utils.dart';

final adb = AdbClient(
  host: '127.0.0.1',
  port: 5037,
  socketTimeout: const Duration(seconds: 15),
);
```

### When to change defaults

- `host`: remote environment/tunnel (for example, ADB exposed on another host).
- `port`: non-default ADB server port.
- `socketTimeout`: slow links, emulators over VPN, or unstable CI.

## Device Selection Strategy

Avoid ambiguity in environments with multiple devices:

```dart
final target = await adb.device(serial: 'emulator-5554');
```

Or by `transportId`:

```dart
final target = await adb.device(transportId: 7);
```

## Port Forwarding

For host <-> device service TCP communication:

```dart
final phantom = target.phantom;
await phantom.startAgent(); // resolves and applies dynamic forwards
print('Command port (host): ${phantom.hostCommandPort}');
print('Video port (host): ${phantom.hostVideoPort}');
```

Best practices:

1. Prefer the `PhantomClient` automatic flow to resolve dynamically published ports.
2. For non-Phantom services, remove forwarding during cleanup when appropriate:

```dart
await target.forwardRemove('tcp:${phantom.hostCommandPort}');
await target.forwardRemove('tcp:${phantom.hostVideoPort}');
```

## Phantom Agent Configuration

`startAgent()` already uses Base64-embedded APKs from the package itself.
You do not need to provide file paths:

```dart
final phantom = target.phantom;
await phantom.startAgent();
```

When you need to update the embedded binaries, regenerate them:

```bash
dart run tool/generate_base64_apks.dart
```

## Timeouts and Failure Behavior

Internally, `PhantomClient` uses:

- a TCP connection timeout;
- a response timeout;
- a maximum JSON response size.

This prevents silent hangs and corrupted responses in production.

## Related Docs

- Phantom flow architecture: [../architecture/overview.md](../architecture/overview.md)
- JSON protocol and H.264 stream: [../architecture/protocols.md](../architecture/protocols.md)
