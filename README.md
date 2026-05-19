# adb_utils

[![pub.dev](https://img.shields.io/pub/v/adb_utils.svg)](https://pub.dev/packages/adb_utils)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.11-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Biblioteca Dart para interagir com o servidor ADB (Android Debug Bridge) e dispositivos Android via protocolo socket nativo. Inspirada na biblioteca [openatx/adbutils](https://github.com/openatx/adbutils) do Python.

Esta biblioteca se comunica diretamente com o servidor ADB local via TCP (`127.0.0.1:5037`), eliminando a necessidade de invocar processos shell (executáveis `adb`) de forma ineficiente a todo momento.

---

## Recursos (Features)

- **Gestão de Dispositivos**: Listar, conectar, desconectar e monitorar estado de dispositivos.
- **Execução Shell**: Executar comandos, com captura de saída e códigos de erro (`returnCode`).
- **Instalação e Aplicativos**: Instalar/desinstalar APKs (via streaming de bytes) e obter informações avançadas de apps (`dumpsys`).
- **Interação**: Capturar tela (screenshot) em bytes nativos, simular toques, deslizes e teclas (keyevents).
- **Socket & Forwarding**: Criar port forwards locais/reversos e até obter conexões Socket raw nativas para serviços dentro do dispositivo Android.
- **SYNC Nativo (Transferência de Arquivos)**: Enviar (`push`), ler (`readBytes`, `readText`) e consultar (`stat`) arquivos diretamente usando o protocolo ADB SYNC.
- **Phantom (UiAutomator Agent)**: Orquestrar instalação/start do agente de teste instrumentado e enviar ações JSON via TCP (`dumpWindow`, `clickByText`).
- **Phantom Video Stream (H.264)**: Consumir stream bruto de vídeo (NAL units) via `startVideoStream()` na porta `9009`.
- **Relatório HTML de Testes**: Gerar `report.html` automaticamente após `dart test`, com evidências detalhadas de falha.

---

## Primeiros Passos (Getting Started)

### Requisitos

- Dart SDK `^3.11.4`
- ADB (Android Debug Bridge) instalado no sistema e o servidor em execução (`adb start-server`).

### Instalação

Adicione o pacote `adb_utils` ao seu arquivo `pubspec.yaml`:

```yaml
dependencies:
  adb_utils: ^0.4.0
```

E instale rodando:

```sh
dart pub get
```

---

## Uso (Usage)

Aqui está um exemplo rápido de como se conectar ao ADB e ler o modelo de um dispositivo:

```dart
import 'package:adb_utils/adb_utils.dart';

void main() async {
  final adb = AdbClient();

  // Listar todos os dispositivos conectados
  for (final d in await adb.deviceList()) {
    print('${d.serial} - ${d.state.name} - ${d.model ?? ''}');
  }

  // Obter um dispositivo (Lança erro se houver mais de um ou nenhum)
  final device = await adb.device();
  
  // Ler propriedades via `getprop` com cache nativo opcional
  print(await device.prop.model);        // ex: "Pixel 7"
  
  // Executar um comando shell
  print(await device.shell('uname -r')); // versão do kernel
}
```

---

## API Detalhada

### `AdbClient`

O `AdbClient` é a porta de entrada da biblioteca. Representa a conexão com o servidor do ADB na sua máquina.

```dart
final adb = AdbClient(
  host: '127.0.0.1',
  port: 5037,
  socketTimeout: Duration(seconds: 10),
);

// Obter dispositivo via serial ou ID de transporte
final d1 = await adb.device(serial: '8d1f93be');
final d2 = await adb.device(transportId: 24);

// Conectar via TCP (ex: adb connect)
await adb.connect('192.168.1.100:5555');

// Monitorar eventos de conexão/desconexão em tempo real
await for (final event in adb.trackDevices()) {
  print('${event.serial} conectado? ${event.present}');
}
```

### `AdbDevice`

A classe `AdbDevice` representa um Android específico.

**Shell & Propriedades**
```dart
String out = await d.shell('ls -l /sdcard');

// O shell2 retorna um ShellResult com o código de saída (returnCode) e sucesso.
ShellResult result = await d.shell2('ls /root');
print(result.returnCode); // 0 = sucesso, outro = erro.

// Atalhos rápidos para propriedades (getprop)
print(await d.prop.sdkVersion); // ex: "33"
```

**Informação de Tela e Screenshots**
```dart
var (width, height) = await d.windowSize();
bool isScreenOn = await d.isScreenOn();

// Pega um print da tela diretamente em binário (sem salvar num arquivo no celular)
Uint8List png = await d.screenshot();
```

**Toques e Teclas**
```dart
await d.click(540, 960);
await d.swipe(100, 500, 100, 200, 0.3); // X,Y inicio -> X,Y fim em 0.3s
await d.sendKeys('Olá Mundo!');
await d.keyEvent('KEYCODE_HOME');
```

**Gerenciamento de APK e Pacotes**
```dart
// Instala APK por streaming de Socket (não precisa dar push no arquivo)
await d.install(
  apkPath: 'build/app.apk',
  replace: true, 
  grantAllPermissions: true,
);

await d.uninstall(packageName: 'com.example.app');

// Obter App ativo na tela
ForegroundAppInfo app = await d.appCurrent();
```

### Transferência de Arquivos (`AdbSync`)

Operações via protocolo nativo de transferência ADB SYNC (`adb.sync`).

```dart
// PUSH (Local -> Android)
await d.sync.push('/caminho/local/file.txt', '/sdcard/file.txt');
await d.sync.push(Uint8List.fromList([...]), '/sdcard/data.bin'); // direto da memoria

// PULL (Android -> Local)
await d.sync.pull('/sdcard/config.json', '/caminho/local/config.json'); // salva direto no disco (streaming)

// READ (Android -> Memória Local)
Uint8List bytes = await d.sync.readBytes('/sdcard/config.json');
String texto    = await d.sync.readText('/sdcard/config.json');

// STAT (Ler informações de tamanho e modificação)
Map<String, int> info = await d.sync.stat('/sdcard/file.txt');
// retorna algo como: {'mode': 33188, 'size': 1024, 'mtime': 16843453}
```

### UiAutomator Agent (`PhantomClient`)

Para automações de UI via agente instrumentado:

```dart
import 'package:adb_utils/adb_utils.dart';
import 'package:adb_utils/src/phantom/phantom_client.dart';

final adb = AdbClient();
final d = await adb.device();

final phantom = PhantomClient(device: d, port: 9008);

await phantom.startAgent(
  'lib/src/phantom/apks/target.apk',
  'lib/src/phantom/apks/agent.apk',
);

final xml = await phantom.dumpWindow();
final hierarchy = await phantom.dumpWindowHierarchy();
final clicked = await phantom.clickByText('Entrar');
final videoStream = await phantom.startVideoStream();

await for (final nalChunk in videoStream) {
  // `nalChunk` contém bytes H.264 brutos (NAL units).
  // Encaminhe para o seu decoder/player.
}

print(xml);
print('rotation => ${hierarchy.rotation}');
print('clickByText => $clicked');
```

`startAgent` realiza, em sequência: push dos APKs para `/data/local/tmp`, instalação (`pm install -t -r`), `force-stop` do agente antigo, start do instrumented test em background (`nohup ... &`) e `adb forward tcp:<port>`.

`startVideoStream` cria automaticamente o `adb forward tcp:9009 -> tcp:9009` e retorna um `Stream<List<int>>` contínuo com o vídeo H.264 bruto (NAL units).

---

## Relatório HTML automático após `dart test`

Ao executar:

```sh
dart test
```

o projeto gera automaticamente um ficheiro `report.html` na raiz com:

- painel de resumo (Total, Passaram, Falharam, Tempo Total);
- tabela com todos os testes executados;
- evidências de falha destacadas com fundo vermelho escuro, bloco monoespaçado (`<pre><code>`) e scroll horizontal para leitura de mensagens longas.

### APIs de reporting disponíveis

As APIs de reporting também estão exportadas no barrel principal:

```dart
import 'package:adb_utils/adb_utils.dart';

final result = TestResult(
  nome: 'Conectar via Socket',
  categoria: 'Conectividade',
  duracao: const Duration(milliseconds: 120),
  passou: true,
);

final reporter = HtmlReporter(outputPath: 'report.html');
await reporter.writeReport([result]);
```

### Wrapper de execução sequencial (`TestRunner`)

Para cenários customizados fora do `package:test`, use:

```dart
final runner = TestRunner();
await runner.runTest('Nome', 'Categoria', () async {
  // lógica assíncrona do teste
});
await HtmlReporter(outputPath: 'report.html').writeReport(runner.resultados);
```

> Nota: arquivos temporários de agregação do relatório são escritos em `logs/test-report/`.

---

## Tratamento de Erros

A biblioteca encapsula retornos malsucedidos em três exceções baseadas em `Exception` no arquivo `exceptions.dart`:

| Exceção | Descrição |
| --- | --- |
| `AdbError` | O servidor ADB retornou um status `FAIL` ou uma resposta malformada de protocolo. |
| `AdbTimeout` | O socket atingiu o timeout limite ou uma conexão de shell perdeu acesso. |
| `AdbInstallError` | Erro específico reportado por sessão de instalação (`install`). |

---

## Licença

Este projeto é distribuído sob a licença [MIT](LICENSE).
