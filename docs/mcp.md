# The local model as an MCP server

SibillaOS can expose the model it serves to agent frameworks through
the Model Context Protocol. Enabling it gives every MCP client on your
network two tools, behind the same API keys as the API itself:

- `chat`: run a prompt on the locally hosted model. Nothing in the
  prompt or the answer leaves the machine, which is the point: an
  agent can delegate work over sensitive material to a model that
  cannot exfiltrate it.
- `list_models`: what this machine serves and which model answers
  `chat` by default.

## Enable it

```console
$ sudo sibilla mcp enable
MCP endpoint enabled at /mcp (same API keys as the API)
```

The endpoint is `http://YOUR_HOST:8080/mcp` (or `https://` after
`sibilla tls`). `sudo sibilla connect` shows the address and the key.
`sudo sibilla mcp disable` closes the endpoint again.

## Connect a client

Claude Code:

```console
$ claude mcp add --transport http sibillaos \
    http://YOUR_HOST:8080/mcp \
    --header "Authorization: Bearer YOUR_KEY"
```

Any other MCP client that speaks Streamable HTTP works the same way:
point it at `/mcp` and send the key as a bearer token. Consider a
dedicated key per client (`sudo sibilla key add NAME`) so revoking one
agent does not touch the others.

## Design notes

The server (`llmd-mcp.service`) is ~250 lines of Python standard
library: the appliance pins every component it ships, and a
dependency-free server is the one kind that never needs pinning. It
listens on loopback only and never reads the API keys; authentication
happens at the gateway, which is the only network entry point, exactly
as for the API. The systemd unit runs under a dynamic user with the
standard SibillaOS sandbox.

The transport is Streamable HTTP, stateless: no sessions, one JSON
response per request, protocol revisions 2025-03-26 through 2025-11-25
negotiated at `initialize`. Statelessness is deliberate: the protocol
itself is heading there (the 2026-07-28 revision removes
protocol-level sessions), and a stateless server sits happily behind
any proxy.

CI exercises the endpoint on every push: `initialize`, `tools/list`
and a `list_models` call are asserted through the gateway with a valid
key, an unauthenticated request must be refused with a 401 before
reaching the server, and `sibilla mcp disable` must close the endpoint
again. The `chat` tool is exercised with real inference on a
best-effort basis (CI runners have no GPU).
