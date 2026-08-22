# adb_utils Example

This example demonstrates the complete **happy path**:

1. Connect to the ADB server.
2. Select a device.
3. Start the Phantom agent.
4. Extract the UI hierarchy.
5. Click an element by text.

## Run

```bash
dart run example/example.dart
```

## Requirements

- ADB installed and running (`adb start-server`)
- At least one connected device (`adb devices -l`)
- Phantom APKs already embedded as Base64 by the library itself.

## Related Docs

- Setup: [../doc/setup/getting_started.md](../doc/setup/getting_started.md)
- Configuration: [../doc/setup/configuration.md](../doc/setup/configuration.md)
- Protocols: [../doc/architecture/protocols.md](../doc/architecture/protocols.md)
