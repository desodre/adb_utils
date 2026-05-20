# Configuration

Configuração avançada para cenários de produção, CI e automação UI com Phantom.

## AdbClient Configuration

`AdbClient` permite customizar host, porta e timeout do socket para o servidor ADB:

```dart
import 'package:adb_utils/adb_utils.dart';

final adb = AdbClient(
  host: '127.0.0.1',
  port: 5037,
  socketTimeout: const Duration(seconds: 15),
);
```

### When to change defaults

- `host`: ambiente remoto/túnel (ex.: ADB exposto noutro host).
- `port`: server ADB não padrão.
- `socketTimeout`: links lentos, emuladores sobre VPN, CI instável.

## Device Selection Strategy

Evite ambiguidade em ambientes com múltiplos devices:

```dart
final target = await adb.device(serial: 'emulator-5554');
```

Ou por `transportId`:

```dart
final target = await adb.device(transportId: 7);
```

## Port Forwarding

Para comunicação TCP host <-> serviço dentro do device:

```dart
final phantom = target.phantom;
await phantom.startAgent(); // resolve e aplica forwards dinâmicos
print('Command port (host): ${phantom.hostCommandPort}');
print('Video port (host): ${phantom.hostVideoPort}');
```

Boas práticas:

1. Prefira o fluxo automático do `PhantomClient` para resolver portas dinâmicas publicadas no logcat.
2. Para serviços não-Phantom, remova forwarding no cleanup quando fizer sentido:

```dart
await target.forwardRemove('tcp:${phantom.hostCommandPort}');
await target.forwardRemove('tcp:${phantom.hostVideoPort}');
```

## Phantom Agent Configuration

`startAgent()` já utiliza APKs embutidos em Base64 no próprio package.
Não é necessário informar caminhos de ficheiros:

```dart
final phantom = target.phantom;
await phantom.startAgent();
```

Quando precisar atualizar os binários embutidos, gere novamente:

```bash
dart run tool/generate_base64_apks.dart
```

## Timeouts and Failure Behavior

Internamente, o `PhantomClient` usa:

- timeout de conexão TCP;
- timeout de resposta;
- limite máximo de bytes de resposta JSON.

Isto evita hangs silenciosos e respostas corrompidas em produção.

## Related Docs

- Arquitetura do fluxo Phantom: [../architecture/overview.md](../architecture/overview.md)
- Protocolo JSON e stream H.264: [../architecture/protocols.md](../architecture/protocols.md)
