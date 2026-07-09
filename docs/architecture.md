# SibillaOS - Architecture v0.5

Date: 2026-07-03. Status: consolidated draft.
Changelog v0.9 (v0.4 cycle): gateway hardening. Multiple API keys: the default stays in /etc/llmd/apikey (compatibility with sibilla-connect and the docs), extra keys live one-per-file in /etc/llmd/apikeys.d, and llmd-keys-render folds them into a regex alternation handed to the Caddy matcher through the LLMD_KEYS_ALT environment variable (the matcher moved from an equality check to header_regexp; generated keys are alphanumeric, and llmd-keys-render refuses anything that is not, so the regex cannot be corrupted). sibilla key list/add/revoke/rotate manages the lifecycle; every change re-renders the env and restarts caddy, so revocation is immediate. The gateway now writes structured JSON access logs to /var/log/caddy/sibilla-access.log (directory created at first boot: the caddy user does not exist at deb build time). CI exercises the whole lifecycle: added key accepted, revoked key rejected, default rotation invalidating the old key, access log populated. The workflow token dropped to contents: read by default after CodeQL flagged the permissionless jobs. APT repository: flat layout built by apt-ftparchive and signed with the project GPG key (private half in CI secrets, public half committed under apt/ and embedded into llmd-hw as keyring plus sources entry, so installed systems upgrade the llmd packages through plain apt). The publish-apt workflow verifies the repository with apt itself against a local source on every push, signs with a throwaway key on branches, refuses to run on tags without the project secret, and deploys to GitHub Pages on releases. Deb versions follow the release tag on tag builds so upgrades are visible to apt. Catalog trust (schema 2): the maintainer signs catalog/models.json with the project key (detached armored signature committed next to it); the build refuses to embed a catalog that does not verify, and at runtime llmd-catalog-verify gates every consumer (model-select, sibilla model list/use) with a three-state policy: valid proceeds, invalid always aborts, unsigned transitional builds warn and continue. Model integrity: catalog entries optionally record per-quant sha256 digests (the HF LFS oid, which is also the ollama blob name after a pull, verified against a live CI pull); llmd-model-verify checks the pulled blob, sibilla model use fails closed on mismatch, first boot warns loudly but completes (availability over lockout when the upstream repo re-uploads a file). tools/update-digests.sh refreshes the digests from the HF API; the 0.6B CI model joined the catalog so the whole chain is exercised on every install test.
Changelog v0.8 (v0.3 cycle): unified `sibilla` CLI as the single entry point (status, model, tls, webui, connect), with the sibilla-* commands kept as aliases. `sibilla status` is a real health view (engine unit state, models served by the engine API, model store disk usage, GPU utilization via nvidia-smi, gateway reachability honoring the configured mode) and exits nonzero when the engine or gateway is down, so it doubles as a machine check. `sibilla model rm` and `prune` reclaim disk; both refuse to touch the served model. CI covers status output and the prune surviving-model invariant. Security baseline: ufw enabled at first boot with only SSH and the gateway port open (webui's 3000 stays closed until the admin opens it; sibilla-tls --acme opens 80/443 itself), unattended security updates configured via an apt.conf.d file shipped in llmd-hw, hardening drop-ins extended to caddy and the firstboot unit, no-new-privileges on both containers. CI asserts the firewall state and the hardening directives with systemctl show (deterministic, no score thresholds) and logs the systemd-analyze security exposure scores for the record. Observability: sibilla metrics enable adds an authenticated /metrics/gateway endpoint (Caddy metrics handler; the site body moved into a route block because Caddy's directive order runs handle-like directives before respond, which would have served metrics without auth). Findings recorded: Ollama 0.31.1 has no Prometheus endpoint (checked in server/routes.go), and Caddy's HTTP instrumentation is opt-in per server even in the 2.6.2 that noble ships (wrapMiddleware only instruments when server metrics are configured; checked in modules/caddyhttp/routes.go after CI caught an exposition with no caddy_http_ series): the renderer emits the servers-metrics global option whenever METRICS=on. vLLM's native /metrics passes through the proxy. Grafana dashboard and scrape config in docs/observability/. Cloud image: cloud/build-cloud.sh bakes the official noble cloud image in a single QEMU boot with a NoCloud seed (llmd debs + pinned ollama installer), then reseals with cloud-init clean --logs --machine-id so the deployer's user-data applies at the real first boot; no libguestfs, same toolchain as the ISO pipeline. Engine and model selection moved into llmd-firstboot as a fallback (runs on the deployed hardware, where the GPU is visible; no-op on ISO installs). The CI cloud-test deploys the qcow2 with a plain user seed and requires a real chat completion plus a clean sibilla status. arm64: the cloud image and the llmfit deb (aarch64 musl release asset, sha256-verified like the amd64 one) build and deploy in CI as a matrix on GitHub's native arm64 runners; those runners expose no /dev/kvm, so QEMU runs under TCG (machine virt, AAVMF firmware) with wider timeouts, and the deploy test asserts the API surface (gateway auth, served model, sibilla status) while token generation stays informational. The arm64 ISO is deferred: the install test would run under pure emulation. curl added to the llmd-hw and llmd-firstboot dependencies: the scripts always needed it and only worked because the base images ship it.
Changelog v0.7 (post v0.1.0): llmfit now ships as a deb built from the pinned upstream release, removing the install-time dependency on its installer. Open WebUI is available as an opt-in Quadlet container (sibilla-webui enable, port 3000, host networking to reach the loopback-only ollama, own login). The gateway config is rendered by llmd-gateway-render from /etc/llmd/gateway.conf, and sibilla-tls switches between plain HTTP, HTTPS with Caddy's local CA for a hostname, and public ACME; the TLS path is exercised in CI. The proxy rewrites the upstream Host header to the upstream address: ollama's DNS-rebinding guard (allowedHostsMiddleware in server/routes.go) rejects non-local Host values on a loopback listener with an empty 403, which silently broke every authenticated request as soon as the gateway served a hostname. CI got stricter in return: the lint job validates all three rendered Caddyfiles with caddy validate and dry-runs the Quadlet generator on the .container files, and the install test checks the wrong-key 401, the webui flag gating (enable/disable without waiting for the image pull), the vllm condition staying off on ollama machines, and the sibilla-tls disable path back to plain HTTP.
Changelog v0.6: release ISOs make the standard installer sections interactive (locale, keyboard, network, storage, identity) while the llmd steps stay automated; CI images remain fully unattended. Model choice happens after install with the sibilla-model CLI (list/use); a boot-time selection menu was considered and deferred, since subiquity cannot host custom screens without a fork. The forced password change is superseded: release users set their own credentials in the installer.
Changelog v0.5: the ISO is now a repack of the official Ubuntu live-server image. The from-scratch debootstrap ISO booted (verified in CI) but had no working installer: subiquity is shipped as a snap in official images and the autoinstall trigger needs cloud-init, neither of which were in our squashfs. Repacking reuses the proven installer stack as is.

## 1. Goal

A minimal Linux distribution with an integrated LLM inference engine (vLLM or Ollama, selected automatically from the detected hardware). The model is recommended, chosen and downloaded during installation. At first boot the system serves an OpenAI-compatible API.

Targets: headless servers and desktop workstations.

## 2. Decisions

| Area | Decision |
|---|---|
| Name | SibillaOS (checked available on 2026-07-03; only namesake found: a Python ORM called "sibilla") |
| Base | Ubuntu 24.04 LTS |
| Engine | Automatic detection: vLLM or Ollama depending on hardware |
| vLLM deployment | OCI container (official image, podman + systemd/Quadlet) |
| Targets | Headless server and desktop |
| Models | Downloaded from Hugging Face during install, recommended by llmfit |
| Catalog | Curated, signed list (subset of the llmfit catalog) |
| Project license | Apache-2.0 for the llmd-* components |
| Visual identity | Emerald serpent eye: lens with a vertical slit pupil, orbiting rune diamonds, golden glint. Palette: forest #0e2a1c, emerald #3ddc84, light green #a8e063, gold accent #f5c542 |

## 3. Base distribution

Ubuntu 24.04 LTS (server: minimal ISO; desktop: GNOME variant).

Reasons: NVIDIA drivers and the CUDA runtime are available and well maintained in the official repositories, autoinstall (Subiquity) is mature for automated installs, and the release has five years of support. A valid alternative for a leaner, community-driven base is Debian 13 "trixie" (current stable, 6.12 LTS kernel, supported until 2028 plus LTS until 2030, see [debian.org/releases](https://www.debian.org/releases/stable/)); its drawback is older NVIDIA drivers. Ubuntu 26.04 LTS is newer but worth adopting only once the NVIDIA ecosystem catches up.

## 4. Stack

```
+---------------------------------------------+
|  (optional) Open WebUI                      |
+---------------------------------------------+
|  llmd-gateway: reverse proxy (Caddy)        |
|  single OpenAI-compatible API on :8080      |
+----------------------+----------------------+
|  Ollama (:11434)     |  vLLM (:8000)        |
|  systemd service     |  container (Quadlet) |
+----------------------+----------------------+
|  llmd-hw: hardware detection + llmfit       |
|  (model recommendation), NVIDIA/CUDA or     |
|  ROCm drivers, CPU fallback                 |
+---------------------------------------------+
|  Ubuntu 24.04 LTS minimal (server)          |
|  + optional desktop (GNOME minimal)         |
+---------------------------------------------+
```

Our components (Debian packages):

- llmd-hw: GPU detection (VRAM, vendor, compute capability) for the engine choice; delegates model recommendation to llmfit.
- llmfit (packaged by us as a .deb): existing Rust tool, MIT licensed, that detects the hardware and recommends models with the best quantization and a speed estimate. Scriptable JSON output (`llmfit recommend --json --limit 5`), hardware overrides (`--memory=24G --ram=64G`), use-case filter (`--use-case coding`). Supports multi-GPU, MoE models, and the Ollama, vLLM and llama.cpp runtimes. Sources: [GitHub](https://github.com/AlexsJones/llmfit), [llmfit.org](https://www.llmfit.org/).
- llmd-engine-ollama / llmd-engine-vllm: packaged engines with hardened systemd units.
- llmd-gateway: single OpenAI-compatible endpoint whatever the engine ([Ollama docs](https://docs.ollama.com/api/openai-compatibility), [vLLM docs](https://docs.vllm.ai/en/latest/)): routing and API key. Defaults to plain HTTP on 8080; sibilla-tls switches to HTTPS with the local CA for a hostname, or to public ACME. The config is rendered by llmd-gateway-render from /etc/llmd/gateway.conf.
- llmd-firstboot: completes or resumes the model download at first boot if it was interrupted during install.

## 5. Engine selection (in the installer)

| Detected hardware | Default |
|---|---|
| NVIDIA datacenter GPU / >= 24 GB VRAM | vLLM |
| NVIDIA consumer GPU / AMD with limited VRAM | Ollama |
| CPU only | Ollama (llama.cpp backend) |

The user can always override the choice. Verified requirements: vLLM supports NVIDIA (primary), AMD MI200/MI300/MI350 and RX 7900/9000, x86/ARM CPUs ([vLLM GPU installation](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/)); Ollama detects CUDA/ROCm automatically and scales layers to the available VRAM ([ollama.com/blog](https://ollama.com/blog)).

## 6. Installer: engine plus model recommendation via llmfit

Base: Ubuntu autoinstall (Subiquity) for the server ISO; the desktop variant uses the same backend. For full UI control: Calamares with a custom module.

Current flow (v0.6): release ISOs show the standard subiquity screens (locale, keyboard, network, storage, identity) via interactive-sections; everything llmd-specific runs automated in the late-commands: hardware detection picks the engine, llmfit picks the default model, firstboot downloads it and brings up the gateway. After install, `sibilla-model list` shows the curated models that fit the machine plus the llmfit recommendations, and `sibilla-model use ID` downloads and switches the served model.

Deferred to v1.x: a model selection screen inside the installer itself (subiquity cannot host custom screens without a fork; candidates are a Calamares module for the desktop variant or a first-boot console menu), plus install-time configuration of API port, Open WebUI and LAN exposure.

### Model source: Hugging Face (single source)

Hugging Face works as the single source for both engines:

- Ollama: direct GGUF pull from HF without a Modelfile: `ollama run hf.co/{user}/{repo}:{quant}` (e.g. `hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:IQ3_M`), see the [HF documentation](https://huggingface.co/docs/hub/ollama). Known limit: sharded GGUF files are not supported directly and must be merged first with `llama-gguf-split --merge`; the curated list must only include single-file repos.
- vLLM: loads HF repos in safetensors format natively.

Gated repos (Llama, Gemma and similar require accepting terms and an HF token): by default the installer only offers non-gated models; gated support (HF token input) can land in v1.x.

Note: llmfit is currently distributed via script/brew/scoop/cargo/pip, not as a .deb ([GitHub, Install section](https://github.com/AlexsJones/llmfit)); we package it ourselves (static Rust binary, straightforward). Its model catalog must also be validated and narrowed to a curated list for installer use.

## 7. ISO build

- Tooling: repack of the official Ubuntu 24.04 live-server ISO with xorriso (`-boot_image any replay` keeps the original hybrid BIOS+UEFI boot setup). The build overlays the autoinstall seed (/nocloud), the llmd packages and branding (/sibilla) and a custom GRUB menu. No root required.
- The llmd packages, engines and llmfit are installed by autoinstall late-commands; NVIDIA drivers come from the Ubuntu restricted component via the installer's own driver handling.
- ISO size: close to the upstream live-server image (about 3 GB).
- Own APT repository for the llmd-* packages and the engines. vLLM runs in an OCI container (official vllm/vllm-openai image) managed by podman with systemd units generated via Quadlet: CUDA dependencies isolated from the system, atomic updates, instant rollback. The image is not shipped in the ISO (several GB); it is downloaded at install time only when the hardware justifies vLLM.
- Package and model-list signing (GPG). Secure Boot: Ubuntu signed kernel/shim, NVIDIA drivers with MOK.

## 8. Security

- systemd services with sandboxing (DynamicUser, ProtectSystem, NoNewPrivileges).
- API protected by a mandatory bearer token through the gateway. Plain HTTP by default (do not expose beyond the LAN); sibilla-tls enables HTTPS with a hostname (local CA or ACME).
- unattended-upgrades for the base system; separate channel for engines and models.
- Engine versions are pinned in the installer (OLLAMA_VERSION for the ollama install script, a fixed release asset for llmfit) and bumped deliberately; the CI install test validates every bump.
- The default user password must be changed at first login (chage -d 0). CI images skip this through the CI marker file, since the ssh automation needs the known password.
- No telemetry.

## 9. Licensing

(Technical analysis, not legal advice; a legal review is needed before the public release.)

Project license (llmd-* components, installer, build scripts): Apache-2.0. Permissive, easy to adopt in enterprise contexts, includes an explicit patent grant (which MIT lacks, relevant in AI), and consistent with the ecosystem we integrate. Verified component compatibility:

| Component | License | Source |
|---|---|---|
| vLLM | Apache-2.0 | [github.com/vllm-project/vllm/LICENSE](https://github.com/vllm-project/vllm/blob/main/LICENSE) |
| Ollama | MIT | [github.com/ollama/ollama](https://github.com/ollama/ollama) |
| llmfit | MIT | [github.com/AlexsJones/llmfit](https://github.com/AlexsJones/llmfit) |
| Ubuntu base | various, redistribution handled by Canonical | - |

All permissive and compatible with Apache-2.0: we can redistribute them in the ISO keeping the original license files.

NVIDIA drivers: the legally delicate part. The [License For Customer Use of NVIDIA Software (Linux)](https://www.nvidia.com/en-us/drivers/nvidia-license/linux/) allows redistribution of unmodified Linux drivers, with conditions; distributions handle them in separate components (Ubuntu "restricted"). Lowest-risk strategy: do not redistribute NVIDIA files directly, ship the driver packages already packaged by Ubuntu (as the Ubuntu ISO itself does), or fetch them from the Ubuntu repos at install time. Modern NVIDIA kernel modules (the open series, default for Turing and later) are dual MIT/GPL-2.0 ([github.com/NVIDIA/open-gpu-kernel-modules](https://github.com/NVIDIA/open-gpu-kernel-modules)); the userspace/CUDA libraries remain proprietary. When in doubt: nvidia-compute-license-questions@nvidia.com.

Models: the default curated list only includes permissively licensed, non-gated HF models. Models under community licenses (Llama, Gemma) are not redistributed by us: the user downloads them directly from HF accepting their terms (v1.x, with an HF token). llmfit already has a built-in license filter.

### Curated list: launch candidates

Selection based on mid-2026 sources (permissively licensed families available on HF/vLLM/Ollama, see the [HF blog](https://huggingface.co/blog/daya-shankar/open-source-llms) and [PocketLLM license-ranked](https://pocketllm.app/blog/best-open-source-llm-2026/)):

| Hardware tier | Engine | Candidates (license) |
|---|---|---|
| CPU only / VRAM <= 8 GB | Ollama (quantized GGUF) | Qwen3 4B (Apache-2.0), Phi-4-mini (MIT) |
| Consumer GPU 8-24 GB | Ollama (quantized GGUF) | Qwen3 14B / 30B-A3B (Apache-2.0), Phi-4 14B (MIT), Mistral Small (Apache-2.0), DeepSeek-R1-Distill (MIT) |
| Datacenter GPU >= 24 GB | vLLM (safetensors, FP8 where available) | Qwen3.5-35B-A3B (Apache-2.0), Mistral Small 4 (Apache-2.0), Mistral Large 3 (Apache-2.0, multi-GPU) |

To verify during implementation (not confirmed from primary sources): the exact HF repo ids, the absence of gating for each repo, and the current versions of each family (the sources also mention DeepSeek V4 and GLM-5, both MIT, but they are very large models, out of scope for launch). The optimal quantization per tier is computed by llmfit at runtime: the list pins the allowed families, not the files.

## 10. Roadmap

| Phase | Scope | Rough duration |
|---|---|---|
| PoC | Minimal Ubuntu 24.04 ISO + preinstalled Ollama + autoinstall with hardcoded model download | 2-3 weeks |
| MVP | llmfit in the installer (recommend --json), llmd-hw, gateway, firstboot resume | 4-6 weeks |
| v1.0 | vLLM as second option with auto-detect, desktop variant + Open WebUI, ISO build CI | 6-8 weeks |

## 11. Decision status

All design decisions are made (see the table in section 2). What remains is verification work, not design:

1. Confirm HF repo ids and gating for the candidate models (section 9) during implementation.
2. Legal review before the public release (NVIDIA drivers in particular).
3. Branding: logo and domain for SibillaOS (name checked available, domain to register).

## Verified sources (2026-07-03)

- [llmfit on GitHub (MIT, CLI/TUI, recommend --json, Ollama/vLLM/llama.cpp providers)](https://github.com/AlexsJones/llmfit) and [llmfit.org](https://www.llmfit.org/)
- [Debian 13 "trixie" release information](https://www.debian.org/releases/stable/)
- [vLLM GPU installation and supported hardware](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/) and [vLLM docs](https://docs.vllm.ai/en/latest/)
- [Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility) and [Ollama blog](https://ollama.com/blog)
- [Hugging Face: use Ollama with any GGUF model](https://huggingface.co/docs/hub/ollama)
- [vLLM LICENSE (Apache-2.0)](https://github.com/vllm-project/vllm/blob/main/LICENSE)
- [NVIDIA License For Customer Use of NVIDIA Software (Linux)](https://www.nvidia.com/en-us/drivers/nvidia-license/linux/) and [NVIDIA open-gpu-kernel-modules (MIT/GPL-2.0)](https://github.com/NVIDIA/open-gpu-kernel-modules)
- Permissive models 2026: [HF blog, best open-source LLMs 2026](https://huggingface.co/blog/daya-shankar/open-source-llms) and [PocketLLM license-ranked](https://pocketllm.app/blog/best-open-source-llm-2026/) (secondary sources: repo ids to confirm)
- Name check (2026-07-03): no distribution named "SibillaOS"/"InferOS"/"LemmaOS" found; "GenioOS" discarded for collisions (MediaTek Genio, Quidgest Genio, Semvox geni:OS)
