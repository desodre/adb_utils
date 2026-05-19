# adb_utils Example

Este exemplo demonstra o **happy path** completo:

1. Conectar ao servidor ADB.
2. Selecionar um device.
3. Inicializar o Phantom agent.
4. Extrair a hierarquia de UI.
5. Executar um clique por texto.

## Run

```bash
dart run example/example.dart
```

## Requirements

- ADB instalado e ativo (`adb start-server`)
- Pelo menos um dispositivo conectado (`adb devices -l`)
- APKs do Phantom presentes em:
  - `lib/src/phantom/apks/target.apk`
  - `lib/src/phantom/apks/agent.apk`

## Related Docs

- Setup: [../doc/setup/getting_started.md](../doc/setup/getting_started.md)
- Configuration: [../doc/setup/configuration.md](../doc/setup/configuration.md)
- Protocols: [../doc/architecture/protocols.md](../doc/architecture/protocols.md)

