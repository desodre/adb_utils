# Troubleshooting

Checklist para diagnosticar problemas comuns com ADB, Phantom e reporting.

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

Selecione serial explicitamente:

```dart
final device = await AdbClient().device(serial: 'emulator-5554');
```

## 2) Phantom command timeout / empty response

### Symptoms

- exceção em `dumpWindow()` / `clickByText()`
- timeout na socket do Phantom

### Checks

```bash
adb -s <serial> shell ps -A | grep phantom
adb -s <serial> logcat -d | grep -i -E "phantom|uiautomator|instrument"
adb -s <serial> forward --list
```

### Fix

1. Reinicie o fluxo `startAgent(...)`.
2. Valide se `tcp:9008` está forwardado para o mesmo serial.
3. Reinstale APKs quando houver mismatch de versões.

## 3) Video stream without data

### Symptoms

- `startVideoStream()` conecta, mas não chegam chunks.

### Checks

```bash
adb -s <serial> forward --list | grep 9009
adb -s <serial> logcat -d | grep -i -E "codec|h264|media"
```

### Fix

1. Recrie o forward `tcp:9009`.
2. Reinicie o agent para recuperar encoder.
3. Verifique permissões/estado de display no device.

## 4) `dart test` sem relatório final

### Symptoms

- execução de testes falha no `tearDownAll`;
- `FormatException` ao ler `results.jsonl`.

### Checks

```bash
ls -la logs/test-report
```

### Fix

- mantenha helper de reporting fora de nome `*_test.dart`;
- garanta append concorrente sob lock;
- ignore linhas residuais inválidas no parse.

## 5) Install failures (`AdbInstallError`)

### Symptoms

- `INSTALL_FAILED_*` no resultado de `install`.

### Checks

```bash
adb -s <serial> shell pm list packages | grep <package>
adb -s <serial> shell getprop ro.build.version.sdk
```

### Fix

- use flags adequadas (`replace`, `allowTest`, `allowDowngrade`, `grantAllPermissions`);
- remova versão anterior conflituosa quando necessário.

## Health-Check Script (Quick)

```bash
adb start-server && adb devices -l && adb forward --list
```

