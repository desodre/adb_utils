# Architecture Overview

`adb_utils` implementa comunicação direta com o servidor ADB via socket TCP (`127.0.0.1:5037`) e abstrações de alto nível para operações de dispositivo, transferência de ficheiros e automação UI.

## High-Level Components

1. **AdbTransport**  
   Camada de baixo nível do protocolo ADB (wire format `XXXX<payload>`).
2. **AdbClient**  
   Ponto de entrada para operações host-scoped: listagem de devices, connect/disconnect, tracking.
3. **AdbDevice**  
   Operações device-scoped: shell, input, screenshots, app management, forwarding.
4. **AdbSync**  
   Transferência de ficheiros pelo protocolo SYNC (push/pull/read/stat).
5. **PhantomClient**  
   Orquestra instalação/start do agent UIAutomator e executa comandos JSON via TCP.
6. **Reporting**  
   Geração de relatórios HTML para execuções de testes.

## Design Principles

### 1) One transport per command

Cada operação abre um novo `AdbTransport`, executa o comando e fecha o socket no `finally`.  
Isto reduz efeitos colaterais entre comandos e melhora isolamento de erro.

### 2) Explicit host vs device context

- Host-scoped: usa `AdbClient.openTransport()`.
- Device-scoped: usa `AdbClient.transportFor(serial)`.

### 3) Fail-fast with typed exceptions

Erros de protocolo e timeout são propagados com tipos explícitos (`AdbError`, `AdbTimeout`, `AdbInstallError`), evitando fallback silencioso.

## Phantom Flow (UI Automation)

`PhantomClient.startAgent()` executa:

1. Push dos APKs para `/data/local/tmp`.
2. Instalação via `pm install -t -r`.
3. `force-stop` do agente.
4. Limpeza do logcat (`logcat -c`).
5. Start da instrumentação (`am instrument`) com classe explícita (`PhantomServer#startServer`) em background.
6. Polling do ficheiro `files/phantom_ports.json` (no `context.filesDir` da app), lido via `run-as com.example.phantom_agent cat files/phantom_ports.json`, para capturar `command_port` e `video_port`.
7. Reserva de portas livres no host e aplicação de `adb forward` host↔device para comando e vídeo.

Depois disso, comandos como `dumpWindow()` e `clickByText()` usam payload JSON via TCP.

## Video Streaming Path

`PhantomClient.startVideoStream()`:

1. reutiliza o mapeamento dinâmico criado em `startAgent()`;
2. conecta socket local em `127.0.0.1:<hostVideoPort>`;
3. retorna `Stream<List<int>>` com bytes H.264 brutos (NAL units).

## Documentation Links

- Protocolo detalhado: [protocols.md](protocols.md)
- Guias avançados: [../guides/advanced_features.md](../guides/advanced_features.md)
