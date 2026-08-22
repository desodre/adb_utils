# Getting Started

This guide covers installation, prerequisites, and the minimum setup needed to
run ADB commands through `adb_utils`.

## Prerequisites

1. Dart SDK `^3.11.4`
2. Android Debug Bridge (ADB) instalado
3. Servidor ADB ativo

```bash
dart --version
adb version
adb start-server
adb devices -l
```

## Install Package

Add the package to `pubspec.yaml`:

```yaml
dependencies:
  adb_utils: ^0.4.7
```

Then run:

```bash
dart pub get
```

## Minimal Bootstrap

```dart
import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  final adb = AdbClient();
  final device = await adb.device();
  final model = await device.prop.model;
  print('Connected device model: $model');
}
```

## Quick Health Check

Use this snippet to validate the complete path (host -> ADB server -> device transport):

```dart
import 'package:adb_utils/adb_utils.dart';

Future<void> main() async {
  final adb = AdbClient();
  final version = await adb.serverVersion();
  final devices = await adb.deviceList();

  print('ADB server version: $version');
  print('Connected devices: ${devices.length}');

  if (devices.isEmpty) {
    print('No devices available.');
    return;
  }

  final d = await adb.device(serial: devices.first.serial);
  final shellOut = await d.shell('echo adb_utils_ok');
  print('Shell result: ${shellOut.trim()}');
}
```

## Next Steps

- Advanced configuration: [configuration.md](configuration.md)
- Architecture: [../architecture/overview.md](../architecture/overview.md)
- Complete example: [../../example/README.md](../../example/README.md)
