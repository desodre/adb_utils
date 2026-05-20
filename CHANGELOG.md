## 0.4.6
- **fix(phantom)**: replaced Logcat-based dynamic port discovery with deterministic file handshake in app-private storage (`context.filesDir/phantom_ports.json`).
- **fix(phantom)**: Dart client now reads/cleans handshake file using `run-as com.example.phantom_agent` to avoid sandbox permission errors on `/data/local/tmp` and `/tmp`.
- **fix(phantom)**: start instrumentation process is now launched asynchronously without shell redirection dependence, improving compatibility across real devices/emulators.
- **test(phantom)**: updated `phantom_client_test.dart` expectations for `run-as` file polling and cleanup flow.
- **chore(phantom)**: refreshed embedded Phantom APK artifacts and regenerated `phantom_binaries.dart`.

## 0.4.5
- **fix(phantom)**: use filesDir handshake via run-as, previously had issues with permissions and inconsistent behavior.

## 0.4.4
- **feat(logging)**: added structured Smart Logs with `package:logging`, including hierarchical loggers per device/Phantom serial and configurable global logging bootstrap.
- **feat(observability)**: added contextual telemetry (`FINE`, `INFO`, `WARNING`, `SEVERE`) for shell execution, Phantom startup, dynamic-port discovery, and TCP forwarding.
- **feat(shell-smart-trace)**: non-zero `shell2` exit codes now emit SEVERE smart traces with command, exit code, and sanitized output.
- **fix(phantom)**: hardened dynamic port discovery flow with logcat cleanup + polling retries/fallbacks and improved resilience for noisy multi-device environments.
- **fix(tests)**: stabilized integration suites by isolating destructive scenarios, improving environment gating, and converting transient infra failures into contextual skips where appropriate.
- **docs**: synchronized `adb_utils` and `phantom_agent` documentation with the dynamic-port architecture (`ServerSocket(0)` + `adb forward`) and updated operational troubleshooting guidance.

## 0.4.3
- **feat(phantom)**: embedded Phantom APK binaries in Dart source via Base64, removing runtime dependency on local APK file paths.
- **feat(phantom)**: refactored `PhantomClient.startAgent()` to install from embedded binaries using safe temporary files created at runtime.
- **feat(phantom)**: added `AdbDevice.phantom` extension for ergonomic usage (`await device.phantom.startAgent();`).
- **build(tooling)**: added `tool/generate_base64_apks.dart` to regenerate `lib/src/phantom/phantom_binaries.dart`.
- **docs**: updated README/docs/examples to the new no-path Phantom startup flow.

## 0.4.2
- **docs**: updated documentation to reflect the latest changes in release 0.4.2.
- **ex**: also add examples.



## 0.4.1

- **hotfix(reporting)**: fixed automatic HTML report generation in `dart test`.
  - Renamed test helper from `test/helpers/reporting_test.dart` to `test/helpers/reporting.dart` so it is no longer discovered as a standalone test file.
  - Fixed concurrent JSONL append writes by forcing file-end position before writing under lock.
  - Hardened report/session JSON parsing to ignore malformed residual lines instead of failing in `tearDownAll`.

## 0.4.0

- **feat(phantom)**: added `PhantomClient.startVideoStream()` for raw H.264 streaming.
  - Automatically configures `adb forward tcp:9009 -> tcp:9009`.
  - Opens a native `Socket` on `127.0.0.1:9009` and returns it as `Stream<List<int>>`.
  - Added API docs clarifying the stream contains raw H.264 NAL units.
- **feat(reporting)**: added automated HTML test reporting utilities.
  - Added `TestResult` model (`lib/src/reporting/test_result.dart`).
  - Added `HtmlReporter` (`lib/src/reporting/html_reporter.dart`) with summary cards and failure evidence blocks (`mensagemErro` + `stackTrace` in `<pre><code>`).
  - Added sequential test wrapper `TestRunner` (`lib/src/reporting/test_runner.dart`).
  - Exported reporting APIs in `lib/adb_utils.dart`.
  - Added demo runner at `bin/test_runner.dart` that writes `report.html`.
- **test(reporting)**: `dart test` now generates `report.html` automatically.
  - Added `test/helpers/reporting_test.dart` to capture per-test results and failures.
  - Integrated reporting helper in unit and integration suites:
    - `test/adb_utils_test.dart`
    - `test/phantom_client_test.dart`
    - `test/integration/server_test.dart`
    - `test/integration/device_test.dart`
- **test(phantom)**: added coverage for `startVideoStream()` forwarding and byte streaming behavior.

## 0.3.2

- chore: apply `dart format` across project files required by CI/release workflow.

## 0.3.1

- **feat(ui_hierarchy)**: added typed UI hierarchy model and package export.
  - Added `UiHierarchy`, `UiNode`, and `Bounds` in `lib/src/models/ui_hierarchy.dart`.
  - Exported `ui_hierarchy.dart` from the main barrel (`adb_utils.dart`).
- **feat(phantom)**: added `dumpWindowHierarchy()` to parse XML directly into `UiHierarchy`.
- **security**: hardened shell/socket surfaces.
  - Added package-name validation in `appInfo()` and `uninstall()`.
  - Added URL validation/sanitization in `openBrowser()`.
  - Added Phantom socket connect/response timeouts, response size cap, empty-response check, and strict port-range validation.
- **test**: added security-focused tests and hierarchy parsing coverage.
- **docs**: updated README with Phantom + `UiHierarchy` usage.

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
