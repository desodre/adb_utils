# Architecture Overview

`adb_utils` communicates directly with the ADB server through a TCP socket
(`127.0.0.1:5037`) and provides high-level abstractions for device operations,
file transfer, and UI automation.

## High-Level Components

1. **AdbTransport**  
Low-level ADB protocol layer (wire format `XXXX<payload>`).
2. **AdbClient**  
Entry point for host-scoped operations: device listing, connect/disconnect, and tracking.
3. **AdbDevice**  
Device-scoped operations: shell, input, screenshots, app management, and forwarding.
4. **AdbSync**  
File transfer through the SYNC protocol (push/pull/read/stat).
5. **PhantomClient**  
Orchestrates installation/startup of the UIAutomator agent and executes JSON commands through TCP.
6. **Reporting**  
Generates HTML reports for test executions.

## Design Principles

### 1) One transport per command

Each operation opens a new `AdbTransport`, executes the command, and closes the
socket in `finally`. This reduces side effects between commands and improves
error isolation.

### 2) Explicit host vs device context

- Host-scoped: uses `AdbClient.openTransport()`.
- Device-scoped: uses `AdbClient.transportFor(serial)`.

### 3) Fail-fast with typed exceptions

Protocol and timeout errors are propagated through explicit types (`AdbError`,
`AdbTimeout`, `AdbInstallError`), avoiding silent fallbacks.

## Phantom Flow (UI Automation)

`PhantomClient.startAgent()` executa:

1. Push APKs to `/data/local/tmp`.
2. Install with `pm install -t -r`.
3. Force-stop the agent.
4. Start instrumentation (`am instrument`) with the explicit `PhantomServer#startServer` class in the background.
5. Poll `files/phantom_ports.json` (in the app's `context.filesDir`) through `run-as com.example.phantom_agent cat files/phantom_ports.json`, to obtain `command_port` and `video_port`.
6. Reserve free host ports and apply host↔device `adb forward` rules for commands and video.

Depois disso, comandos como `dumpWindow()` e `clickByText()` usam payload JSON via TCP.

## Video Streaming Path

`PhantomClient.startVideoStream()`:

1. reuses the dynamic mapping created by `startAgent()`;
2. connects a local socket at `127.0.0.1:<hostVideoPort>`;
3. returns a `Stream<List<int>>` containing raw H.264 bytes (NAL units).

## Documentation Links

- Detailed protocol: [protocols.md](protocols.md)
- Advanced guides: [../guides/advanced_features.md](../guides/advanced_features.md)
