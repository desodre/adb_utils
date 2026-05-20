# Protocols

Esta secção descreve os protocolos usados pelo `adb_utils` em dois planos: protocolo ADB wire e protocolo TCP do Phantom.

## ADB Wire Protocol

### Request format

Cada mensagem cliente -> servidor ADB:

```text
XXXX<payload>
```

- `XXXX`: tamanho do payload em hexadecimal ASCII, 4 caracteres, uppercase.
- `<payload>`: comando UTF-8 (`host:devices-l`, `shell:...`, etc).

### Response format

Servidor responde com:

1. `OKAY` para sucesso, ou
2. `FAIL` seguido de mensagem de erro com tamanho prefixado.

### Typical device-scoped sequence

```text
client -> host:transport:<serial>
server <- OKAY
client -> shell:getprop ro.product.model
server <- OKAY + stream output
```

## SYNC Protocol (File Transfer)

Canal dedicado para transferência de ficheiros (push/pull/read/stat) sobre ADB transport já selecionado.

Operações principais:

- `SEND` + blocos `DATA` + `DONE`
- `RECV` + blocos `DATA` + `DONE`
- `STAT` para metadata (`mode`, `size`, `mtime`)

## Phantom JSON Command Protocol

Após `startAgent`, comandos de controlo usam JSON sobre TCP em porta dinâmica no host (`hostCommandPort`) mapeada por `adb forward`.

### Request payloads

`dumpWindow`:

```json
{
  "action": "dumpWindow"
}
```

`clickByText`:

```json
{
  "action": "clickByText",
  "text": "Entrar"
}
```

### Response shape

```json
{
  "status": "success",
  "xml": "<hierarchy ...>...</hierarchy>"
}
```

Falha:

```json
{
  "status": "error",
  "message": "Element not found"
}
```

## Phantom Video TCP Flow (H.264)

`startVideoStream()` usa TCP puro na porta dinâmica `hostVideoPort` e retorna stream binário:

```text
host socket(127.0.0.1:<hostVideoPort>) <- adb forward <- device socket(<deviceVideoPort>)
```

Cada chunk contém bytes H.264 (NAL units). O consumidor deve encaminhar para decoder/player próprio.

## Operational Notes

- Limites de timeout e tamanho de resposta JSON protegem contra hangs e payloads inválidos.
- Respostas JSON vazias ou malformadas são tratadas como erro explícito.
