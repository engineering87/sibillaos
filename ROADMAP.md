# SibillaOS roadmap

This document lists where the project is going and why. Versions are scoped by outcome, not by date. Items move between versions when reality disagrees with the plan; the architecture document records the decisions once they are made. Suggestions are welcome as issues.

## v0.2 (released)

The operability release: everything needed to run SibillaOS beyond the first demo. Shipped: llmfit as a Debian package built from the pinned upstream release, Open WebUI as an opt-in container managed by `sibilla-webui` (container plumbing exercised in CI, the web interface itself still pending a manual pass), HTTPS on the gateway via `sibilla-tls` (local CA for LAN hostnames, ACME for public ones), multi-model serving through the gateway, and the `sibilla-connect` kit with ready-to-paste configuration for VS Code (Continue and Cline), aider and any OpenAI-compatible client. Release notes in [docs/releases/v0.2.0.md](docs/releases/v0.2.0.md).

## v0.3 (in progress, branch release/0.3)

The release for people who run SibillaOS on real infrastructure.

- A unified `sibilla` CLI as the single entry point (`sibilla status`, `sibilla model`, `sibilla tls`, `sibilla webui`, `sibilla connect`), with the current commands kept as aliases. Done.
- `sibilla status` grown into a real health view: engine state, served models, disk usage of the model store, GPU utilization when present, gateway reachability; exits nonzero on failure so scripts can use it as a check. Done.
- Observability opt-in: `sibilla metrics enable` serves gateway-level Prometheus metrics (request rate, latency histograms, status codes, upstream health) at an authenticated /metrics/gateway endpoint, with a ready-made Grafana dashboard and scrape config in docs/observability/. vLLM's native /metrics passes through the gateway; Ollama at the pinned 0.31.1 exposes no Prometheus endpoint (verified in its source, revisit on engine bumps). Done.
- Model store management: `sibilla model rm` and `sibilla model prune`, with disk usage reporting. Done.
- A cloud image alongside the ISO: the same stack published as a qcow2 with cloud-init, for Proxmox, libvirt and cloud providers. Built by baking the official Ubuntu cloud image in one QEMU boot and resealing cloud-init; engine and model detection moved into llmd-firstboot so it happens on the deployed hardware. CI deploys the image with a real user seed and gets a chat completion. Done.
- arm64 build: delivered as the cloud image (qcow2 for Ampere, Graviton and other arm64 VMs), built and deployed in CI on native arm64 runners with the llmfit deb repackaged from the aarch64 musl release. GitHub's arm64 runners have no KVM, so the CI deploy runs under TCG emulation: the API surface is asserted, token generation is exercised but not asserted (documented in the test). The arm64 ISO is deferred: the unattended-install test that guards every ISO change is impractical under pure emulation; revisit if arm64 KVM runners appear, and note Raspberry Pi needs its own image flavor anyway (not the generic cloudimg). Done for the cloud image.

## v0.4 (supply chain and enterprise)

The release that makes a security review pleasant.

- GPG-signed model catalog, verified by llmd-model-select before use; project key in CI secrets.
- APT repository (GitHub Pages is enough) so installed systems receive llmd package updates through the normal apt flow instead of reinstalling.
- SBOM generated at build time and attached to releases; CVE scan of the ISO packages in CI with a documented triage policy.
- Gateway hardening: multiple API keys with per-key revocation, optional rate limiting, structured access logs.
- Air-gapped install profile: a companion payload (model files plus engine images on a second USB drive) for environments with no outbound network, which is where the on-premise pitch matters most.

## Security track (cross-version)

A dedicated track rather than a single milestone, because "your data stays on your machine" is the core promise and it has to hold at every release. What already holds today: engines bound to loopback with the gateway as the only entry point, a mandatory bearer token, systemd sandboxing on the Ollama unit, pinned engine versions, the upstream Host header rewritten by the proxy, and the Ubuntu base image verified against official checksums at build time.

Planned, in order of appearance:

- SECURITY.md with a private disclosure channel and a supported-versions table. Done in v0.2.
- Default firewall profile: ufw enabled at first boot with only SSH and the gateway port open; Open WebUI listens on all interfaces (host networking), so its port stays closed until the user opens it deliberately, and `sibilla tls --acme` opens 80/443 itself. Done in v0.3.
- Sandboxing extended to every llmd unit and the containers (NoNewPrivileges, kernel and realtime restrictions), with a CI check that asserts the directives on the installed system; capability drops on the containers deferred until their runtime can be exercised in CI. Done in v0.3.
- Automatic security updates: unattended-upgrades enabled by default for the security pocket, since an appliance that nobody patches must patch itself. Done in v0.3.
- API key lifecycle: `sibilla key rotate`, multiple keys with per-key revocation, structured access logs; covered by the v0.4 gateway hardening item.
- Supply chain: signed catalog, SBOM, CVE scanning with a triage policy; covered by v0.4.
- Secure Boot: the repack keeps Ubuntu's signed shim and GRUB, but the chain has never been verified end to end on real firmware; test it and document the result (v0.4).
- Model integrity: Ollama already verifies blob digests on pull; extend the catalog with expected digests so the model being served is provably the one that was reviewed (v0.4).

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
