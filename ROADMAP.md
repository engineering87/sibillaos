# SibillaOS roadmap

This document lists where the project is going and why. Versions are scoped by outcome, not by date. Items move between versions when reality disagrees with the plan; the architecture document records the decisions once they are made. Suggestions are welcome as issues.

## v0.2 (released)

The operability release: everything needed to run SibillaOS beyond the first demo. Shipped: llmfit as a Debian package built from the pinned upstream release, Open WebUI as an opt-in container managed by `sibilla-webui` (container plumbing exercised in CI, the web interface itself still pending a manual pass), HTTPS on the gateway via `sibilla-tls` (local CA for LAN hostnames, ACME for public ones), multi-model serving through the gateway, and the `sibilla-connect` kit with ready-to-paste configuration for VS Code (Continue and Cline), aider and any OpenAI-compatible client. Release notes in [docs/releases/v0.2.0.md](docs/releases/v0.2.0.md).

## v0.3 (released)

The release for people who run SibillaOS on real infrastructure. Release notes in [docs/releases/v0.3.0.md](docs/releases/v0.3.0.md).

- A unified `sibilla` CLI as the single entry point (`sibilla status`, `sibilla model`, `sibilla tls`, `sibilla webui`, `sibilla connect`), with the current commands kept as aliases. Done.
- `sibilla status` grown into a real health view: engine state, served models, disk usage of the model store, GPU utilization when present, gateway reachability; exits nonzero on failure so scripts can use it as a check. Done.
- Observability opt-in: `sibilla metrics enable` serves gateway-level Prometheus metrics (request rate, latency histograms, status codes, upstream health) at an authenticated /metrics/gateway endpoint, with a ready-made Grafana dashboard and scrape config in docs/observability/. vLLM's native /metrics passes through the gateway; Ollama at the pinned 0.31.1 exposes no Prometheus endpoint (verified in its source, revisit on engine bumps). Done.
- Model store management: `sibilla model rm` and `sibilla model prune`, with disk usage reporting. Done.
- A cloud image alongside the ISO: the same stack published as a qcow2 with cloud-init, for Proxmox, libvirt and cloud providers. Built by baking the official Ubuntu cloud image in one QEMU boot and resealing cloud-init; engine and model detection moved into llmd-firstboot so it happens on the deployed hardware. CI deploys the image with a real user seed and gets a chat completion. Done.
- arm64 build: delivered as the cloud image (qcow2 for Ampere, Graviton and other arm64 VMs), built and deployed in CI on native arm64 runners with the llmfit deb repackaged from the aarch64 musl release. GitHub's arm64 runners have no KVM, so the CI deploy runs under TCG emulation: the API surface is asserted, token generation is exercised but not asserted (documented in the test). The arm64 ISO is deferred: the unattended-install test that guards every ISO change is impractical under pure emulation; revisit if arm64 KVM runners appear, and note Raspberry Pi needs its own image flavor anyway (not the generic cloudimg). Done for the cloud image.

## v0.4 (released)

The release that makes a security review pleasant. Shipped: multiple gateway API keys with per-key revocation and structured access logs (`sibilla key`; rate limiting deferred), the signed APT repository on GitHub Pages with installed systems preconfigured for plain apt upgrades, the GPG-signed model catalog with per-quant artifact digests verified after every pull, SBOM generation and CVE scanning with a written triage policy (docs/supply-chain.md), and Secure Boot verified in CI on every ISO. Release notes in [docs/releases/v0.4.0.md](docs/releases/v0.4.0.md).

## v0.5 (adoption and feedback)

Four cycles added features; the remaining distance to v1.0 is validation with real users, not more surface. With v0.4 published and the project being shared, this cycle is deliberately lighter and driven by what early users hit.

- First-run experience: a sharper quick start (from download to first token in the README), clearer install-time messages, and fast turnaround on issues reported against the published images. The issue templates are already in place.
- Manual validation of Open WebUI, carried since v0.2: actually install, `sibilla webui enable`, log in and chat, then record the result. It is a v1.0 criterion and cannot be automated (the image is too heavy for CI).
- Air-gapped install profile, moved from v0.4: a companion payload (model files plus engine images on a second USB drive) for environments with no outbound network, which is where the on-premise pitch matters most.
- Gateway rate limiting, the one piece of the v0.4 gateway hardening item deliberately left out.

## Toward v1.0: open validation debts

Tracked here so they are not lost between feature cycles, because each is a v1.0 criterion that no amount of new code satisfies:

- vLLM on physical datacenter GPUs: implemented and gated in CI, but never run on real hardware. Needs a machine or an external tester.
- Open WebUI web interface: packaged and CI-exercised around the container, the login-and-chat flow never validated by hand (folded into v0.5 above).
- A release cycle with external users and no critical install bugs: only starts counting once people install the published images.

## Security track (cross-version)

A dedicated track rather than a single milestone, because "your data stays on your machine" is the core promise and it has to hold at every release. What already holds today: engines bound to loopback with the gateway as the only entry point, a mandatory bearer token, systemd sandboxing on the Ollama unit, pinned engine versions, the upstream Host header rewritten by the proxy, and the Ubuntu base image verified against official checksums at build time.

Planned, in order of appearance:

- SECURITY.md with a private disclosure channel and a supported-versions table. Done in v0.2.
- Default firewall profile: ufw enabled at first boot with only SSH and the gateway port open; Open WebUI listens on all interfaces (host networking), so its port stays closed until the user opens it deliberately, and `sibilla tls --acme` opens 80/443 itself. Done in v0.3.
- Sandboxing extended to every llmd unit and the containers (NoNewPrivileges, kernel and realtime restrictions), with a CI check that asserts the directives on the installed system; capability drops on the containers deferred until their runtime can be exercised in CI. Done in v0.3.
- Automatic security updates: unattended-upgrades enabled by default for the security pocket, since an appliance that nobody patches must patch itself. Done in v0.3.
- API key lifecycle: `sibilla key` with add, revoke and rotate, multiple keys folded into the gateway matcher, structured JSON access logs. Done in v0.4 (rate limiting deferred to v0.5).
- Supply chain: signed catalog, SBOM in SPDX and CycloneDX attached to releases, CVE scanning of the actually installed system with a written triage policy and expiring exceptions. Done in v0.4.
- Secure Boot: the repack keeps Ubuntu's signed shim and GRUB, and CI now boots every ISO under OVMF with Secure Boot enforced and Microsoft keys enrolled, asserting that the kernel itself reports Secure Boot active; validation on physical firmware from external users remains welcome. Done in v0.4.
- Model integrity: catalog entries carry per-quant sha256 digests (the ollama blob name after a pull); `sibilla model use` fails closed on a mismatch, first boot warns loudly. Done in v0.4.

## v1.0 (general availability)

The release where the "proof of concept" label comes off. Criteria, not features: the vLLM path validated on physical datacenter GPUs, at least one release cycle with external users and no critical install bugs, documented upgrade path between versions, and the desktop variant with a model selection screen in the installer (Calamares module or first-boot console menu, decision pending).

## Exploratory (no commitment)

Ideas that look promising but need a use case or a champion:

- Speech endpoints: whisper.cpp for transcription behind the same gateway.
- ds4 (DwarfStar) as a third engine for high-memory unified-RAM machines (DGX Spark, Strix Halo, 96 GB and up): a narrow native engine for DeepSeek V4 Flash/PRO with an HTTP API and SSD streaming for models larger than RAM. Philosophically close to this project, but explicitly beta today and with a deliberately volatile model-support policy (upstream may drop a model when a better one appears), which conflicts with our pinning discipline. Revisit when it stabilizes; track upstream at github.com/antirez/ds4.
- MCP server exposure, so agent frameworks can discover the local models as tools. Increasingly requested as the Model Context Protocol becomes a common integration point; a strong candidate for promotion out of exploratory in a future cycle.
- LDAP or OIDC authentication on the gateway for team deployments.
- A Debian stable base variant for shops that prefer it over Ubuntu.

## Non-goals

Things SibillaOS deliberately does not try to be: a Kubernetes distribution (use the engines' own charts), a model marketplace (the catalog stays small and curated), or a managed service.
