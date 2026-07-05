# SibillaOS roadmap

This document lists where the project is going and why. Versions are scoped by outcome, not by date. Items move between versions when reality disagrees with the plan; the architecture document records the decisions once they are made. Suggestions are welcome as issues.

## v0.2 (in progress, branch release/0.2)

The operability release: everything needed to run SibillaOS beyond the first demo.

- llmfit shipped as a Debian package built from the pinned upstream release, removing the install-time network dependency. Done.
- Open WebUI as an opt-in container managed by `sibilla-webui`. Done, pending manual validation.
- HTTPS on the gateway via `sibilla-tls`: local CA for LAN hostnames, ACME for public ones. Done, exercised in CI.
- Multi-model serving documented and tested: the gateway already passes the model field through, so `sibilla-model pull` for additional models and per-request model selection should be verified in CI rather than built.

## v0.3 (operations and platforms)

The release for people who run SibillaOS on real infrastructure.

- A unified `sibilla` CLI as the single entry point (`sibilla status`, `sibilla model`, `sibilla tls`, `sibilla webui`), with the current commands kept as aliases.
- `sibilla status` grown into a real health view: engine state, served models, disk usage of the model store, GPU utilization when present, gateway reachability.
- Observability opt-in: expose the native Prometheus metrics of the engines (vLLM has /metrics, Ollama gained them in recent releases; verify) through an authenticated endpoint, plus a ready-made Grafana dashboard in the repo.
- Model store management: `sibilla model rm` and `sibilla model prune`, with disk usage reporting.
- A cloud image alongside the ISO: the same stack published as a qcow2 with cloud-init, for Proxmox, libvirt and cloud providers. Likely the cheapest way to widen adoption, since the whole late-commands flow already lives in cloud-init territory.
- arm64 build: Ubuntu, Ollama and llmfit all ship arm64 binaries; the repack pipeline should port with modest effort. Raspberry Pi 5 and Ampere servers are real targets for small local models.
- Editor and agent connection kit: `sibilla connect` emits ready-to-paste configuration for coding tools on the user's workstation, wired to the gateway endpoint and API key. First targets: VS Code via Continue and Cline, aider, and a generic OpenAI-compatible snippet; includes the CA certificate note when TLS runs in local-CA mode.

## v0.4 (supply chain and enterprise)

The release that makes a security review pleasant.

- GPG-signed model catalog, verified by llmd-model-select before use; project key in CI secrets.
- APT repository (GitHub Pages is enough) so installed systems receive llmd package updates through the normal apt flow instead of reinstalling.
- SBOM generated at build time and attached to releases; CVE scan of the ISO packages in CI with a documented triage policy.
- Gateway hardening: multiple API keys with per-key revocation, optional rate limiting, structured access logs.
- Air-gapped install profile: a companion payload (model files plus engine images on a second USB drive) for environments with no outbound network, which is where the on-premise pitch matters most.

## v1.0 (general availability)

The release where the "proof of concept" label comes off. Criteria, not features: the vLLM path validated on physical datacenter GPUs, at least one release cycle with external users and no critical install bugs, documented upgrade path between versions, and the desktop variant with a model selection screen in the installer (Calamares module or first-boot console menu, decision pending).

## Exploratory (no commitment)

Ideas that look promising but need a use case or a champion:

- Speech endpoints: whisper.cpp for transcription behind the same gateway.
- ds4 (DwarfStar) as a third engine for high-memory unified-RAM machines (DGX Spark, Strix Halo, 96 GB and up): a narrow native engine for DeepSeek V4 Flash/PRO with an HTTP API and SSD streaming for models larger than RAM. Philosophically close to this project, but explicitly beta today and with a deliberately volatile model-support policy (upstream may drop a model when a better one appears), which conflicts with our pinning discipline. Revisit when it stabilizes; track upstream at github.com/antirez/ds4.
- MCP server exposure, so agent frameworks can discover the local models as tools.
- LDAP or OIDC authentication on the gateway for team deployments.
- A Debian stable base variant for shops that prefer it over Ubuntu.

## Non-goals

Things SibillaOS deliberately does not try to be: a Kubernetes distribution (use the engines' own charts), a model marketplace (the catalog stays small and curated), or a managed service.
