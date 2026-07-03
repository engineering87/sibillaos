<div align="center">

<img src="branding/logo.png" alt="SibillaOS logo" width="140"/>

# SibillaOS

**The oracle on your hardware.**

Install Linux, get a working LLM API. Nothing else to set up.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Base](https://img.shields.io/badge/base-Ubuntu%2024.04%20LTS-e95420.svg)](https://ubuntu.com)
[![Build](https://github.com/engineering87/sibillaos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/engineering87/sibillaos/actions/workflows/build-iso.yml)
[![Status](https://img.shields.io/badge/status-proof%20of%20concept-f5c542.svg)](docs/architecture.md)

</div>

---

Running a local LLM still means picking an engine, matching a model to your VRAM, choosing a quantization and wiring up a service. SibillaOS does all of that in the installer. Boot the ISO, answer the usual questions, and the first thing your machine does is serve an OpenAI-compatible API.

```
$ curl https://myserver:8080/v1/chat/completions \
    -H "Authorization: Bearer $(cat /etc/llmd/apikey)" \
    -d '{"model": "default", "messages": [{"role": "user", "content": "hello"}]}'
```

## What the installer does for you

| Step | Tool | Result |
|---|---|---|
| Reads GPU vendor and VRAM | `llmd-hw-detect` | picks the engine: vLLM on datacenter GPUs (24 GB VRAM and up, OCI container), Ollama everywhere else, CPU included |
| Sizes models to your machine | [llmfit](https://github.com/AlexsJones/llmfit) | suggests only models that actually fit, with the best quantization and a speed estimate |
| Filters the catalog | curated list | permissively licensed (Apache-2.0/MIT), non-gated Hugging Face repos only |
| Downloads the model | installer / first boot | pulled from Hugging Face, resumed at first boot if the network drops |
| Serves one endpoint | `llmd-gateway` (Caddy) | OpenAI-compatible API on :8080, TLS, bearer token; engines stay on loopback |

Two variants: headless server and desktop (GNOME, optional Open WebUI).

## Build the ISO

On an Ubuntu or Debian host with root and `debootstrap squashfs-tools xorriso mtools dosfstools grub-pc-bin grub-efi-amd64-bin grub-common`:

```bash
./packages/build-debs.sh       # build the llmd-* debs
sudo ./iso/build.sh            # out/sibillaos-<version>-amd64.iso
```

Or push to GitHub and let [the CI workflow](.github/workflows/build-iso.yml) build it for you: the ISO is attached to each run as an artifact.

## Repository layout

```
iso/                  ISO build (debootstrap + squashfs) and autoinstall config
packages/             Debian packages: hardware detection, engines, gateway, first boot
catalog/              curated model list (signed JSON)
branding/             logo and wallpaper
docs/                 architecture document
.github/workflows/    ISO build CI
```

## Status

Proof of concept, moving toward MVP. Known gaps before any real deployment:

- catalog repo ids and licenses are verified; gating status is checked at install time, a gated repo falls back to the next candidate
- the autoinstall user password is a placeholder, replace it
- the ISO has not been boot-tested in a VM yet (the CI build itself passes)

Design, decisions and roadmap live in [docs/architecture.md](docs/architecture.md).

## License

Apache-2.0, see [LICENSE](LICENSE). Bundled components keep their own licenses: vLLM (Apache-2.0), Ollama (MIT), llmfit (MIT). NVIDIA drivers are not redistributed by this repository; the ISO ins