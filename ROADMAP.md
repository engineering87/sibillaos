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

## v0.5 (released)

The adoption release: trying SibillaOS no longer costs a reinstall, and walking away is provably clean. Shipped: the zero-reinstall path (`apt install llmd` plus `sibilla setup` on an existing Ubuntu 24.04 machine, staying a good guest: no firewall takeover, no source flips, appliance behavior kept behind the image marker), `sibilla remove` for a verified reversible teardown that takes only what SibillaOS installed and restores what it displaced, `sibilla doctor` for a paste-ready secret-free diagnostic report (every configured API key scrubbed by construction, asserted in CI), `sibilla connect --write` to place the Continue configuration with backup, and the README overhaul with the two-command quick start. The whole lifecycle, install through verified-clean removal, runs in CI on every push. Release notes in [docs/releases/v0.5.0.md](docs/releases/v0.5.0.md).

## v0.6 (released)

The release for three audiences: agent users, the network-less on-premise, and whoever runs more than one machine. Shipped: the MCP server (`sibilla mcp enable`, the local model as `chat` and `list_models` tools behind the gateway keys, stateless Python stdlib), air-gapped installs end to end (digest-gated `sibilla model import`, the companion payload builder, first-boot detection, proven in CI on a VM with outbound network dropped), configuration as code (declared profile plus idempotent `sibilla apply` and `apply export`, picked up by cloud-init and first boot), embeddings for local RAG (/v1/embeddings, an embedding role in the signed catalog that can never become the chat default, `sibilla model pull`), the developer kit (`connect --env/--mcp/--snippet`, aider written next to Continue), `sibilla bench` with a shareable result table, the kernel-level per-IP rate limit baseline (per-key fairness deferred with the Caddy-vs-nginx decision recorded in the architecture log), and the upgrade path turned into a CI assert: the published release is installed from the live repository, upgraded and required to survive on every push. Release notes in [docs/releases/v0.6.0.md](docs/releases/v0.6.0.md).

## v0.7 (the adoption cycle: found, believed, working on real hardware)

An honest reading of where the project stands: the feature depth already exceeds what an adopter needs, and what is missing is discovery, credibility and the hardware people actually own. This cycle optimizes for those three, in this order.

- Supply freshness, opening the cycle: the ollama pin moves to 0.32.1 and the vLLM container to v0.25.1 (the ":latest" that had survived from the PoC is gone), with the whole pipeline as the safety net; sha256 digests recorded for every entry of the catalog (tools/update-digests.sh); and one finding turned into policy - recent ollama can transparently offload ":cloud" models to ollama.com, so every SibillaOS install now pins OLLAMA_NO_CLOUD=1 in the hardened unit and CI asserts it on both the image and the apt path: nothing in a prompt or an answer leaves the machine, including via the engine's own cloud. In progress on the branch.
- Consumer GPUs, following the only real inbound signal the project has received (a question about Strix Halo/ROCm). AMD detection already existed in llmd-hw-detect; what was missing and now ships: first boot completes the ollama ROCm runtime on AMD hardware whose GPU was not visible at image bake time (cloud images are baked in a GPU-less VM, so AMD deployments silently ran on CPU), AMD visibility in `sibilla status`, `doctor` and `bench` (including a loud "ROCm runtime missing" instead of silence), a deterministic hardware-detection matrix in CI (PATH-stubbed nvidia-smi/lspci/rocm-smi: datacenter NVIDIA, consumer NVIDIA, AMD, APU, none), and docs/validation/gpu.md - the tester guide with the explicit call for NVIDIA/AMD/APU hands, HSA_OVERRIDE_GFX_VERSION collection for APUs included. Done; the physical validation now waits on tester hands, which is what the distribution push below recruits.
- Positioning and proof: a front-and-center "Why not just Ollama?" section in the README, because it is the question every single visitor silently asks and the answer (mandatory auth from first boot, verified artifacts, reversible trial, off-network, config as code - around the very same engine) deserves better than being deducible; and the terminal demo made authentic - the CI pipeline already runs the real session on every push, so it records it (asciinema) and the artifact replaces the hand-drawn representative SVG. A demo generated by the pipeline, not acted.
- vLLM on physical datacenter GPUs, with a plan instead of a hope: either a rented GPU instance for a few hours (full control, bounded cost) or a recruited tester armed with a dedicated validation guide. It is a v1.0 criterion that has floated in the debts section for three cycles; even a failed attempt produces information, the absence of one does not.
- Deeper developer integration, building on the v0.6 kit. `sibilla connect --remote` generates a self-contained, deliberately keyless script for the developer workstation: it prompts for the key on stdin there (never argv, never shell history), refuses to write a single file until the gateway accepts the key, then places Continue and aider configs with the backup-once rule plus an optional project-directory .env (the scaffolding). The Zed survey landed honestly: Zed takes an api_url override in settings.json but keeps keys in its own credential store, so it gets a print-only kit section rather than a pretend --write. Framework quickstarts shipped with the RAG stage. In progress on the branch.
- Configuration audit, the third piece of the config track: `sibilla apply check` verifies without changing - drift against the declared profile, a Caddyfile that differs from its render (hand edits, which the next toggle would silently overwrite), the served model against its catalog digest, key file permissions - and exits nonzero on findings, so it doubles as a cron or fleet health probe. CI proves it passes on a clean machine and catches a tampered Caddyfile and a drifted profile. Done.
- Local RAG quickstart on the embeddings endpoint: a zero-dependency worked example plus LangChain and LlamaIndex configurations, the CI running the example end to end. In progress on the branch, next.
- Manual validation of Open WebUI, carried since v0.2: the step-by-step checklist lives in [docs/validation/webui.md](docs/validation/webui.md); execute it on a real machine, record the result there. It is a v1.0 criterion and cannot be automated (the image is too heavy for CI).
- Distribution push, declared as work because otherwise it does not happen: the v0.6 story published (LinkedIn, Discord, r/LocalLLaMA or a Show HN) with `sibilla bench` as the call to action - try it for ten minutes, post your table. Feedback-driven cycles need feedback, and feedback needs users.
- First-run experience: clearer install-time messages and fast turnaround on issues reported against the published images; `sibilla doctor` gives reporters something precise to paste into the templates. First slice shipped as CLI polish: the long-form commands (status, doctor, bench, apply check) gain the emerald "oracle" style - dim labels, brand-green values, ASCII status glyphs, a header with version and host - with color emitted only on a TTY without NO_COLOR, so pipes, redirects and every CI grep get byte-identical plain text. The appliance images also gain the SSH login banner (the ASCII oracle eye, version, served model, where to start), gated behind the appliance marker because a guest install never redecorates someone else's login - asserted in CI on both paths. A plymouth boot splash was considered and deliberately deferred to the desktop variant: a headless appliance keeps the text console that diagnostics, the serial log and CI all read.

## Toward v1.0: open validation debts

Tracked here so they are not lost between feature cycles, because each is a v1.0 criterion that no amount of new code satisfies:

- vLLM on physical datacenter GPUs: implemented and gated in CI, but never run on real hardware. Needs a machine or an external tester.
- Open WebUI web interface: packaged and CI-exercised around the container, the login-and-chat flow never validated by hand (folded into v0.7 above; checklist in docs/validation/webui.md).
- A release cycle with external users and no critical install bugs: only starts counting once people install the published images.

## Security track (cross-version)

A dedicated track rather than a single milestone, because "your data stays on your machine" is the core promise and it has to hold at every release. What already holds today: engines bound to loopback with the gateway as the only entry point, a mandatory bearer token, systemd sandboxing on the Ollama unit, pinned engine versions, the upstream Host header rewritten by the proxy, and the Ubuntu base image verified against official checksums at build time.

Planned, in order of appearance:

- SECURITY.md with a private disclosure channel and a supported-versions table. Done in v0.2.
- Default firewall profile: ufw enabled at first boot with only SSH and the gateway port open; Open WebUI listens on all interfaces (host networking), so its port stays closed until the user opens it deliberately, and `sibilla tls --acme` opens 80/443 itself. Done in v0.3.
- Sandboxing extended to every llmd unit and the containers (NoNewPrivileges, kernel and realtime restrictions), with a CI check that asserts the directives on the installed system; capability drops on the containers deferred until their runtime can be exercised in CI. Done in v0.3.
- Automatic security updates: unattended-upgrades enabled by default for the security pocket, since an appliance that nobody patches must patch itself. Done in v0.3.
- API key lifecycle: `sibilla key` with add, revoke and rotate, multiple keys folded into the gateway matcher, structured JSON access logs. Done in v0.4 (rate limiting re-scoped in v0.6: see there for the packaging constraint).
- Supply chain: signed catalog, SBOM in SPDX and CycloneDX attached to releases, CVE scanning of the actually installed system with a written triage policy and expiring exceptions. Done in v0.4.
- Secure Boot: the repack keeps Ubuntu's signed shim and GRUB, and CI now boots every ISO under OVMF with Secure Boot enforced and Microsoft keys enrolled, asserting that the kernel itself reports Secure Boot active; validation on physical firmware from external users remains welcome. Done in v0.4.
- Model integrity: catalog entries carry per-quant sha256 digests (the ollama blob name after a pull); `sibilla model use` fails closed on a mismatch, first boot warns loudly. Done in v0.4.

## v1.0 (general availability)

The release where the "proof of concept" label comes off. Criteria, not features: the vLLM path validated on physical datacenter GPUs, at least one release cycle with external users and no critical install bugs, documented upgrade path between versions, and the desktop variant with a model selection screen in the installer (Calamares module or first-boot console menu, decision pending).

## Exploratory (no commitment)

Ideas that look promising but need a use case or a champion:

- Speech endpoints: whisper.cpp for transcription behind the same gateway.
- ds4 (DwarfStar) as a third engine for high-memory unified-RAM machines (DGX Spark, Strix Halo, 96 GB and up): a narrow native engine for DeepSeek V4 Flash/PRO with an HTTP API and SSD streaming for models larger than RAM. Philosophically close to this project, but explicitly beta today and with a deliberately volatile model-support policy (upstream may drop a model when a better one appears), which conflicts with our pinning discipline. Revisit when it stabilizes; track upstream at github.com/antirez/ds4.
- LDAP or OIDC authentication on the gateway for team deployments.
- A Debian stable base variant for shops that prefer it over Ubuntu.

## Non-goals

Things SibillaOS deliberately does not try to be: a Kubernetes distribution (use the engines' own charts), a model marketplace (the catalog stays small and curated), or a managed service.
