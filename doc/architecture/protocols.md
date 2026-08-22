# Protocols

This section describes the two protocol layers used by `adb_utils`: the ADB wire protocol and the Phantom TCP protocol.

## ADB Wire Protocol

### Request format

Every client -> ADB server message:

```text
XXXX<payload>
```

- `XXXX`: payload size in ASCII hexadecimal, four uppercase characters.
- `<payload>`: UTF-8 command (`host:devices-l`, `shell:...`, and so on).

### Response format

The server responds with:

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

A dedicated channel for file transfer (push/pull/read/stat) over an already selected ADB transport.

Main operations:

- `SEND` + blocos `DATA` + `DONE`
- `RECV` + blocos `DATA` + `DONE`
- `STAT` para metadata (`mode`, `size`, `mtime`)

## Phantom JSON Command Protocol

After `startAgent`, control commands use JSON over TCP on a dynamic host port (`hostCommandPort`) mapped by `adb forward`.

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

Failure:

```json
{
  "status": "error",
  "message": "Element not found"
}
```

## Phantom Video TCP Flow (H.264)

`startVideoStream()` uses plain TCP on the dynamic `hostVideoPort` and returns a binary stream:

```text
host socket(127.0.0.1:<hostVideoPort>) <- adb forward <- device socket(<deviceVideoPort>)
```

Each chunk contains H.264 bytes (NAL units). The consumer must send them to its own decoder/player.

## Operational Notes

- Timeout and JSON response-size limits protect against hangs and invalid payloads.
- Empty or malformed JSON responses are treated as explicit errors.
