## 0.3.0

- **feat(phantom)**: added `PhantomClient` to orchestrate UiAutomator agent lifecycle and TCP communication.
  - Added `startAgent(targetApkPath, agentApkPath)` with APK push, install, force-stop, background instrumentation start, and port forwarding.
  - Added JSON socket communication flow with robust chunked response handling.
  - Added `dumpWindow()` and `clickByText()` high-level actions.
- **test(phantom)**: added focused unit tests for `startAgent`, JSON payload exchange, `dumpWindow()`, and `clickByText()`.
- **chore(phantom)**: added bundled APK artifacts for the phantom flow:
  - `lib/src/phantom/apks/agent.apk`
  - `lib/src/phantom/apks/target.apk`

## 0.2.2

- **feat(adb_sync)**: fully implemented file transfer operations via the ADB SYNC protocol.
  - Added `pull()`: download files using memory-efficient streaming.
  - Added `readBytes()` and `readText()`: read remote file contents directly into memory.
  - Added `stat()`: query remote file size, mode, and modification time.

## 0.1.3

- fix: apply `dart format` to `app_info.dart` and `adb_utils_test.dart`

## 0.1.2

- added `AppInfo.fromDumpsys` to get more detailed information about the app, such as version and permissions. This is useful for users who want to know more about the apps installed on their devices.
- added `AdbDevice.appInfo` to retrieve the `AppInfo` for a given package name.
