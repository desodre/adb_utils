## 0.1.3

- fix: apply `dart format` to `app_info.dart` and `adb_utils_test.dart`

## 0.1.2

- added `AppInfo.fromDumpsys` to get more detailed information about the app, such as version and permissions. This is useful for users who want to know more about the apps installed on their devices.
- added `AdbDevice.appInfo` to retrieve the `AppInfo` for a given package name.
