# Troubleshooting

Checklist for diagnosing common ADB, Phantom, and reporting issues.

## 1) `No device connected` / `Multiple devices connected`

### Symptoms

- `AdbError('No device connected')`
- `AdbError('Multiple devices connected; specify serial...')`

### Checks

```bash
adb start-server
adb devices -l
```

### Fix

Select a serial explicitly:

```dart
final device = await AdbClient().device(serial: 'emulator-5554');
```

## 2) Phantom command timeout / empty response

### Symptoms

- exception in `dumpWindow()` / `clickByText()`
- timeout on the Phantom socket

### Checks

```bash
adb -s <serial> shell ps -A | grep phantom
adb -s <serial> logcat -d | grep -i -E "phantom|uiautomator|instrument"
adb -s <serial> forward --list
```

### Fix

1. Restart the `startAgent(...)` flow.
2. Check that dynamic forwards (`hostCommandPort`/`hostVideoPort`) were created for the same serial.
3. Reinstall the APKs when versions do not match.

## 3) Video stream without data

### Symptoms

- `startVideoStream()` connects, but no chunks arrive.

### Checks

```bash
adb -s <serial> forward --list
adb -s <serial> logcat -d | grep -i -E "codec|h264|media"
```

### Fix

1. Restart `startAgent()` to renegotiate dynamic ports and recreate forwards.
2. Restart the agent to recover the encoder.
3. Check display permissions and state on the device.

## 4) `dart test` without a final report

### Symptoms

- test execution fails in `tearDownAll`;
- `FormatException` while reading `results.jsonl`.

### Checks

```bash
ls -la logs/test-report
```

### Fix

- keep the reporting helper outside a `*_test.dart` filename;
- ensure concurrent append operations are locked;
- ignore invalid residual lines during parsing.

## 5) Install failures (`AdbInstallError`)

### Symptoms

- `INSTALL_FAILED_*` no resultado de `install`.

### Checks

```bash
adb -s <serial> shell pm list packages | grep <package>
adb -s <serial> shell getprop ro.build.version.sdk
```

### Fix

- use the appropriate flags (`replace`, `allowTest`, `allowDowngrade`, `grantAllPermissions`);
- remove a conflicting previous version when necessary.

## Health-Check Script (Quick)

```bash
adb start-server && adb devices -l && adb forward --list
```
