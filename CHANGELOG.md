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
