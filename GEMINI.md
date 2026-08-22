# Project: adb_utils

Dart library for interacting with the Android Debug Bridge (ADB) server and devices via the native socket protocol. Inspired by [openatx/adbutils](https://github.com/openatx/adbutils).

## Project Overview

- **Technologies:** Dart SDK `^3.11.4`, ADB Wire Protocol.
- **Core Principle:** Communicates directly with the ADB server socket (`127.0.0.1:5037`) using hex-length-prefixed messages.
- **Architecture:**
    - `AdbClient`: Entry point. Manages server-level operations (version, connect/disconnect, device listing, tracking).
    - `AdbDevice`: Device-level operations (shell, input, properties, app management). Uses `client.transportFor(serial)` to switch protocol context.
    - `AdbTransport`: Low-level socket handler. Implements `XXXX<payload>` (4-char hex length) encoding/decoding.
    - `AdbSync`: File transfer using the SYNC protocol. `push`, `pull`, `readBytes`, `readText`, and `stat` are fully functional following [SYNC.TXT](https://cs.android.com/android/platform/superproject/+/master:packages/modules/adb/SYNC.TXT).

## Development & Commands

### Workflow
- **Lint & Format:** `dart analyze` and `dart format .`
- **Execution:** `dart run` (invokes `bin/adb_utils.dart` to list devices).

### Testing Strategy
- **Unit Tests:** `dart test test/adb_utils_test.dart` (Offline, no dependencies).
- **Integration:** `dart test --tags integration` (Requires `adb start-server`).
- **Device:** `dart test --tags device` (Requires physical device or emulator).
- **CI Safety:** Use `dart test --exclude-tags device`.

## ADB Wire Protocol & Conventions

- **Transport Lifecycle:** Open a fresh `AdbTransport` for every command (`openTransport()` or `transportFor()`) and ensure it is closed in a `finally` block. Reuse only for persistent streams (e.g., `trackDevices`).
- **Message Format:** Every request starts with a 4-char uppercase hex length: `XXXX<payload>`. Server responds with `OKAY` or `FAIL` followed by the message.
- **Shell Exit Codes:** Uses the `;echo EXIT:$?` trick in `shell2` to retrieve return codes without requiring the shell v2 protocol.
- **Device Selection:** Commands targeting a specific device must first send `host:transport:<serial>`.

## CI / CD & Publishing

- **CI (`ci.yml`):** Runs on push/PR to `main`. Performs analysis, formatting checks, and unit tests.
- **Publishing (`publish.yml`):** Triggered by tags `v*.*.*`. Uses **pub.dev OIDC** for automated publishing.
- **Release Process:**
    1. Bump version in `pubspec.yaml` and update `CHANGELOG.md`.
    2. Commit and push.
    3. `git tag vX.Y.Z && git push origin vX.Y.Z`.

## Directory Map

- `lib/src/protocol/`: Low-level protocol implementation.
- `lib/src/models/`: Strongly typed data structures (`AppInfo`, `ShellResult`, etc.).
- `test/helpers/`: Contains `requireAdbServer()`, `requireDevice()`, and custom matchers.
- `mock/apks/`: Contains the lightweight `UiTestSupport.apk` fixture used by
  installation, permission, app-info, and Phantom UI integration tests.
