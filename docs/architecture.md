# SibillaOS - Architecture v0.5

Date: 2026-07-03. Status: consolidated draft.
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
- llmd-gateway: single OpenAI-compatible endpoint whatever the engine ([Ollama docs](https://docs.ollama.com/api/openai-compatibility), [vLLM docs](https://docs.vllm.ai/en/latest/)): routing and API key. PoC serves plain HTTP; TLS termination lands in v1.x together with a hostname setup step, since certificates need a subject.
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
- API protected by a mandatory bearer token through the gateway. PoC serves plain HTTP (do not expose beyond the LAN); TLS termination is a v1.x item, tied to a hostname setup step.
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
