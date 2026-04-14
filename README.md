# adb_utils

[![pub.dev](https://img.shields.io/pub/v/adb_utils.svg)](https://pub.dev/packages/adb_utils)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.11-blue)](https://dart.dev)

Biblioteca Dart para interagir com o servidor ADB (Android Debug Bridge) e dispositivos Android via protocolo socket nativo — inspirada em [openatx/adbutils](https://github.com/openatx/adbutils) para Python.

---

## Requisitos

- Dart SDK `^3.11.4`
- ADB instalado e o servidor em execução (`adb start-server`)

---

## Instalação

Adicione ao `pubspec.yaml`:

```yaml
dependencies:
  adb_utils: ^0.1.0
```

```sh
dart pub get
```

---

## Uso rápido

```dart
import 'package:adb_utils/adb_utils.dart';

void main() async {
  final adb = AdbClient();

  // listar dispositivos
  for (final d in await adb.deviceList()) {
    print('${d.serial}  ${d.state.name}  ${d.model ?? ''}');
  }

  // obter dispositivo (único conectado)
  final d = await adb.device();
  print(await d.prop.model);         // ex: "Pixel 7"
  print(await d.shell('uname -r'));  // versão do kernel
}
```

---

## AdbClient

Ponto de entrada da biblioteca. Conecta ao servidor ADB (padrão `127.0.0.1:5037`).

```dart
final adb = AdbClient(
  host: '127.0.0.1',
  port: 5037,
  socketTimeout: Duration(seconds: 10),
);
```

### Dispositivos

```dart
// todos os dispositivos
List<DeviceInfo> devices = await adb.deviceList();

// selecionar por serial
AdbDevice d = await adb.device(serial: '8d1f93be');

// selecionar por transport ID
AdbDevice d = await adb.device(transportId: 24);

// único dispositivo conectado (erro se zero ou múltiplos)
AdbDevice d = await adb.device();
```

### Conectar dispositivo remoto

```dart
// equivalente a: adb connect 192.168.1.100:5555
String result = await adb.connect('192.168.1.100:5555');

// desconectar
await adb.disconnect('192.168.1.100:5555');
```

### Monitorar dispositivos

```dart
// stream de eventos de conexão/desconexão
await for (final event in adb.trackDevices()) {
  print('${event.serial} — presente: ${event.present}');
}
```

### Forwards globais

```dart
// listar todos os forwards ativos
List<ForwardItem> forwards = await adb.forwardList();

// filtrar por dispositivo
List<ForwardItem> forwards = await adb.forwardList(serial: '8d1f93be');
```

### Servidor

```dart
int version = await adb.serverVersion(); // ex: 39
await adb.killServer();
```

---

## AdbDevice

Obtido via `adb.device(...)`. Representa um dispositivo Android conectado.

### Shell

```dart
// saída como String (stdout + stderr)
String output = await d.shell('getprop ro.product.model');

// aceita lista
String output = await d.shell(['getprop', 'ro.product.model']);

// com código de saída
ShellResult result = await d.shell2('ls /sdcard');
print(result.output);      // saída do comando
print(result.returnCode);  // 0 = sucesso
print(result.isSuccess);   // true/false
```

### Propriedades do dispositivo

```dart
print(await d.prop.model);      // ro.product.model
print(await d.prop.brand);      // ro.product.brand
print(await d.prop.release);    // ro.build.version.release
print(await d.prop.sdkVersion); // ro.build.version.sdk

// qualquer prop, com cache opcional
String val = await d.prop.get('ro.board.platform', cache: true);
```

### Informações de tela

```dart
var (width, height) = await d.windowSize(); // (1080, 1920)
int rot = await d.rotation(); // 0=portrait, 1=left, 2=right, 3=upsidedown
bool on = await d.isScreenOn();
```

### Screenshot

```dart
// retorna bytes PNG
Uint8List png = await d.screenshot();
await File('screen.png').writeAsBytes(png);
```

### Input / controle

```dart
await d.click(540, 960);                     // toque em coordenada
await d.swipe(100, 500, 100, 200, 0.3);      // swipe em 300ms
await d.sendKeys('Hello World');             // digitar texto
await d.keyEvent('KEYCODE_HOME');            // tecla HOME
await d.volumeUp();                          // volume +1
await d.volumeDown(times: 3);               // volume -3
await d.volumeMute();
```

### Aplicativos

```dart
// listar pacotes instalados
List<String> packages = await d.listPackages();
List<String> thirdParty = await d.listPackages(thirdPartyOnly: true);

// app em primeiro plano
ForegroundAppInfo app = await d.appCurrent();
print(app.packageName);
print(app.activity);

// abrir URL no browser
await d.openBrowser('https://flutter.dev');
```

### Port forward / reverse

```dart
// forward: tcp:9999 no host → porta local do dispositivo
await d.forward('tcp:9999', 'localabstract:scrcpy');

// remover forward
await d.forwardRemove('tcp:9999');
await d.forwardRemoveAll();
```

### Conexão de socket direto

```dart
// criar conexão raw com serviço no dispositivo
import 'dart:io';

Socket socket = await d.createConnection(NetworkType.localAbstract, 'minitouch');
// usar socket normalmente...
await socket.close();
```

### Utilitários

```dart
await d.root();          // reinicia adbd como root
await d.tcpip(5555);     // habilita ADB via TCP na porta 5555
String serial = await d.getSerialNo();
String state  = await d.getState();
```

---

## Transferência de arquivos (`AdbSync`)

> **⚠ Em implementação.** A API está definida mas o protocolo SYNC ainda está sendo implementado.

```dart
// push: enviar arquivo para o dispositivo
await d.sync.push('/local/path/file.txt', '/sdcard/file.txt');
await d.sync.push(Uint8List.fromList([...]), '/sdcard/data.bin');

// pull: baixar arquivo do dispositivo
await d.sync.pull('/sdcard/file.txt', '/local/path/file.txt');

// ler diretamente como bytes ou texto
Uint8List bytes = await d.sync.readBytes('/sdcard/file.txt');
String text     = await d.sync.readText('/sdcard/file.txt');
```

---

## Tratamento de erros

```dart
try {
  final d = await adb.device();
  await d.shell('comando');
} on AdbTimeout catch (e) {
  print('Timeout: $e');
} on AdbError catch (e) {
  print('Erro ADB: $e');
}
```

| Exceção           | Quando ocorre                                          |
|-------------------|-------------------------------------------------------|
| `AdbError`        | Servidor retorna `FAIL` ou resposta inesperada        |
| `AdbTimeout`      | Comando ou conexão ultrapassa o timeout               |
| `AdbInstallError` | Falha no `adb install`                                |

---

## Modelos de dados

| Classe              | Descrição                                              |
|---------------------|-------------------------------------------------------|
| `DeviceInfo`        | Serial, estado, transport ID, model, product          |
| `DeviceState`       | `device`, `offline`, `unauthorized`, `recovery`, `unknown` |
| `ShellResult`       | Saída, returnCode, isSuccess                          |
| `ForwardItem`       | Serial, endereço local, endereço remoto               |
| `NetworkType`       | `tcp`, `unix`, `localAbstract`, `dev`, `jdwp`, …     |
| `AppInfo`           | packageName, versionName, versionCode, timestamps     |
| `ForegroundAppInfo` | packageName, activity, pid                            |

---

## Executar via linha de comando

```sh
# lista dispositivos conectados
dart run
```

---

## Desenvolvimento

```sh
dart analyze   # lint
dart format .  # formatar código

# Testes unitários (sem dependências externas)
dart test test/adb_utils_test.dart
dart test --name "nome do teste"   # teste único por nome

# Testes de integração — requer servidor ADB rodando (adb start-server)
dart test --tags integration

# Testes de dispositivo — requer device/emulator conectado
dart test --tags device

# Todos os testes (inclui integração e device)
dart test

# CI sem dispositivo
dart test --exclude-tags device
```

---

## Licença

[MIT](LICENSE)

