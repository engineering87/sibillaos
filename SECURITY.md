# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through
[GitHub Security Advisories](https://github.com/engineering87/sibillaos/security/advisories/new)
rather than in a public issue. You can expect an acknowledgement within a week.
Please include the SibillaOS version, the component involved (installer,
gateway, engine packaging, CLI tools) and steps to reproduce.

## Supported versions

SibillaOS is a proof of concept. Only the latest release receives fixes;
there are no backports. The version under development lives on the current
`release/*` branch.

## Scope

The security surface this project owns:

- the `llmd-*` Debian packages and their systemd units,
- the gateway configuration rendered for Caddy (authentication, TLS),
- the CLI tools (`sibilla-model`, `sibilla-tls`, `sibilla-webui`, `sibilla-connect`),
- the ISO build and autoinstall configuration.

Vulnerabilities in the bundled upstream components (Ollama, vLLM, Caddy,
Open WebUI, llmfit, Ubuntu packages) should be reported upstream; reports
about how SibillaOS configures or exposes them are in scope here.

## Current posture

Inference engines listen on loopback only; the gateway is the single entry
point and requires a bearer token generated at first boot. Engine versions
are pinned and the Ubuntu base image is verified against official checksums
during the build. The hardening roadmap (firewall profile, unit sandboxing,
automatic security updates, signed catalog, SBOM) is tracked in
[ROADMAP.md](ROADMAP.md).
