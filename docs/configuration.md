# Configuration as a profile

Every knob SibillaOS exposes can be driven one command at a time
(`sibilla model`, `sibilla tls`, `sibilla metrics`, `sibilla mcp`,
`sibilla webui`). The profile is the declarative layer on top: one
file that states what the machine should look like, and one command
that makes it so.

```console
$ sudo sibilla apply /path/to/profile
model:   ok (hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M)
tls:     off -> internal:llm.lan
metrics: off -> on
mcp:     ok (on)
profile applied: 2 change(s), 2 already in place
```

`sibilla apply` is idempotent: it compares each declared key with the
machine's state and only runs the commands that close a gap. Applying
a profile the machine already matches does nothing.

## The profile format

A plain `KEY=value` file. Every key is optional: absent means "leave
it as it is", so partial profiles compose.

```
MODEL=hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M
TLS=off                      # or internal:HOSTNAME, or acme:HOSTNAME:EMAIL
METRICS=on
MCP=on
WEBUI=off
```

API keys are deliberately not part of a profile: they are per-machine
secrets with their own lifecycle (`sibilla key`). A profile can be
committed to a repository or passed around without a second thought.

## Where the profile comes from

By hand: write the file anywhere and `sudo sibilla apply FILE`.

From another machine: `sibilla apply export` prints the profile
matching the current state; move it and apply.

```console
$ sibilla apply export > llm-fleet.profile   # on the reference machine
$ sudo sibilla apply llm-fleet.profile       # on every other machine
```

At first boot (fleet provisioning): place the file at
`/etc/llmd/profile` before `llmd-firstboot` runs and the machine
converges on it by itself: the declared MODEL wins over hardware
auto-selection, the rest applies once the stack is up. With the cloud
image that is one cloud-init stanza:

```yaml
#cloud-config
write_files:
  - path: /etc/llmd/profile
    content: |
      MODEL=hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M
      METRICS=on
      MCP=on
```

On an existing Ubuntu machine the same file works with the apt path:
`apt install llmd`, write `/etc/llmd/profile`, then `sudo sibilla
setup` (firstboot picks the profile up exactly as on the images).

## Auditing: `sibilla apply check`

The read-only counterpart: nothing changes, everything the machine
claims about itself is verified. Drift against the declared profile
(if one exists), a Caddyfile that differs from what the renderer
would produce (a hand edit, which the next `sibilla tls` or
`sibilla metrics` run would silently overwrite), a served model that
no longer matches its catalog digest, key files that lost their
permissions. Exit code is nonzero on any finding, so it slots into
cron or a fleet health probe as is:

```console
$ sudo sibilla apply check
profile:  MODEL ok (hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M)
gateway:  Caddyfile matches its render
model:    digest verified (hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M)
keys:     /etc/llmd/apikey is 600
keys:     /etc/llmd/apikeys.d is 700
check passed: the machine matches its declarations
```

## What apply refuses to do

Change the engine: switching between ollama and vLLM is a hardware
decision (`sibilla setup --engine` re-runs the detection path).
Manage keys, as above. Guess: an invalid value aborts before anything
is touched, and a profile that asks for a component that is not
installed is an error, not a silent skip.
