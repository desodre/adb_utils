# Copilot Instructions

## Project

Dart pub.dev library for interacting with ADB (Android Debug Bridge) — inspired by [openatx/adbutils](https://github.com/openatx/adbutils). Communicates directly with the ADB server socket (default `127.0.0.1:5037`) using the ADB wire protocol.

## Commands

```sh
dart run          # runs bin/adb_utils.dart (lists connected devices)

# Tests
dart test test/adb_utils_test.dart              # unit tests only (no external deps)
dart test --tags integration                    # needs ADB server (adb start-server)
dart test --tags device                         # needs connected device/emulator
dart test --exclude-tags device                 # CI without device
dart test --name "test name"                    # single test by name

dart analyze      # lint
dart format .     # format
```

## Architecture

```
lib/
  adb_utils.dart          ← barrel; re-exports everything public
  src/
    adb_client.dart       ← AdbClient: connects to ADB server, lists/selects devices
    adb_device.dart       ← AdbDevice: shell, screenshot, input, forward, props
    adb_sync.dart         ← AdbSync: push/pull via SYNC protocol (partially implemented)
    exceptions.dart       ← AdbError, AdbTimeout, AdbInstallError
    protocol/
      adb_transport.dart  ← low-level socket; ADB wire protocol encode/decode
    models/
      device_info.dart    ← DeviceInfo, DeviceState
      shell_result.dart   ← ShellResult
      forward_item.dart   ← ForwardItem
      network_type.dart   ← NetworkType enum
      app_info.dart       ← AppInfo, ForegroundAppInfo
test/
  adb_utils_test.dart         ← unit tests (no external deps)
  helpers/
    adb_test_helpers.dart     ← requireAdbServer(), requireDevice(), isPng matcher
  integration/
    server_test.dart          ← tag:integration — needs ADB server, no device
    device_test.dart          ← tag:device — needs connected device/emulator
```

## ADB Wire Protocol

Every message Client→Server: `XXXX<payload>` (4-char uppercase hex length + UTF-8 body).  
Server→Client response: `OKAY` or `FAIL` + `XXXX<message>`.  
Transport must be selected before device-scoped commands: `host:transport:<serial>`.  
`AdbTransport.openTransport()` (on `AdbClient`) opens a fresh socket; always `close()` in `finally`.

## Key Conventions

- **One transport per command.** Each operation opens a new `AdbTransport`, sends its command, reads the response, then closes. Reuse only for streaming (shell output, `trackDevices`).
- **`AdbDevice` methods call `client.transportFor(serial)`** for device-scoped commands and `client.openTransport()` for host-scoped commands (forward management, get-state).
- **`AdbSync` is a stub.** The SYNC protocol constants (`_syncData` etc.) are defined but methods throw `UnimplementedError`. Implement using the [SYNC.TXT spec](https://cs.android.com/android/platform/superproject/+/master:packages/modules/adb/SYNC.TXT).
- **`shell2` exit code trick**: appends `;echo EXIT:$?` to the command and parses the suffix — avoids needing shell v2 protocol support.
- Linting: `package:lints/recommended.yaml`, no custom rules. SDK `^3.11.4`.
