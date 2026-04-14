## 0.1.0

- Initial release.
- `AdbClient`: connect to ADB server, list/select devices, connect/disconnect remote devices, forward list, track devices.
- `AdbDevice`: shell, shell2, device properties, screenshot, input (click/swipe/keyevent), app listing, port forwarding, raw socket connections.
- `AdbSync`: push/pull API defined (SYNC protocol implementation in progress).
- `AdbTransport`: low-level ADB wire protocol over TCP with Completer-based I/O (no polling).
- Full exception hierarchy: `AdbError`, `AdbTimeout`, `AdbInstallError`.

