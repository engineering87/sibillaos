# Fleet: one profile, many machines

`sibilla fleet` is the smallest orchestration that the existing pieces
allow: the declarative profile (docs/configuration.md), the idempotent
`sibilla apply` and the auditing `apply check`, driven over SSH across
every machine you list. There is deliberately nothing new underneath -
no agent, no database, no credential store. If you can `ssh` to a
machine, the fleet can manage it.

## The fleet file

One SSH destination per line in `/etc/llmd/fleet` (comments with `#`):

```
# lab machines
llm-lab-1
admin@10.0.0.12
strix-halo          # an alias from ~/.ssh/config
```

Anything your `ssh` accepts works, because your `ssh` is what runs:
config, agent, jump hosts, keys - the fleet tool manages none of it,
by design. Remote hosts need the llmd packages and passwordless sudo
(or connect as `root@`); a host where sudo wants a password fails
instantly and says so, it never hangs a batch run.

## Commands

```console
$ sudo tee /etc/llmd/profile <<'EOF'
MODEL=hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M
METRICS=on
MCP=on
EOF
$ sibilla fleet apply
```

Every host receives the profile and converges onto it; a host already
matching reports zero changes, which is the idempotence of `apply`
doing its job. Partial profiles compose: declare only what you want
uniform.

`sibilla fleet check` aggregates every host's `apply check` - drift
against the declared profile, hand-edited gateway config, served-model
digest, key file permissions - and exits nonzero if any host has
findings, so a cron line makes it a fleet probe:

```
0 7 * * * sibilla fleet check || mail-me-somehow
```

`sibilla fleet status` reports each host's health (engine, model,
gateway) and exits nonzero if any host is down.

## What it deliberately does not do

No API keys travel (they are per-machine secrets: `sibilla key` on
each host owns them; profiles exclude them by design, which is exactly
what makes pushing profiles safe). No parallel execution yet: hosts
run in order and the output stays readable. No engine switching (a
hardware decision, refused by `apply` itself).
