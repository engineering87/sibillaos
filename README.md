<div align="center">

<img src="branding/banner.png" alt="SibillaOS" width="820"/>

<br/>

**Install Linux, get a working LLM API. Nothing else to set up.**

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Base](https://img.shields.io/badge/base-Ubuntu%2024.04%20LTS-e95420.svg)](https://ubuntu.com)
[![Build](https://github.com/engineering87/sibillaos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/engineering87/sibillaos/actions/workflows/build-iso.yml)
[![Status](https://img.shields.io/badge/status-proof%20of%20concept-f5c542.svg)](docs/architecture.md)

</div>

<br/>

Running a local LLM still means picking an engine, matching a model to your VRAM, choosing a quantization and wiring up a service. SibillaOS does all of that in the installer. Boot the ISO, answer the usual questions, and the first thing your machine does is serve an OpenAI-compatible API.

```console
$ curl http://myserver:8080/v1/chat/completions \
    -H "Authorization: Bearer $(cat /etc/llmd/apikey)" \
    -d '{"model": "default", "messages": [{"role": "user", "content": "hello"}]}'
```

<br/>

## How it works

The installer detects your hardware and makes the decisions a human would otherwise have to research.

| | |
|---|---|
| **Engine selection** | vLLM in an OCI container on datacenter GPUs (24 GB VRAM and up), Ollama everywhere else, CPU-only machines included. |
| **Model sizing** | [llmfit](https://github.com/AlexsJones/llmfit) recommends only models that actually fit your VRAM and RAM, with the best quantization and a speed estimate. |
| **Curated catalog** | Permissively licensed (Apache-2.0/MIT), non-gated Hugging Face repos only. Verified ids, signed list. |
| **Resilient download** | The model is pulled from Hugging Face during install and resumed at first boot if the connection drops. |
| **Single endpoint** | One OpenAI-compatible API on port 8080 with a mandatory bearer token. Engines stay on loopback. TLS termination is planned for v1.x (needs a hostname); do not expose the port beyond the LAN. |

Two variants: headless server and desktop (GNOME, optional Open WebUI).

## Getting started

The easiest path is a prebuilt ISO from [Releases](https://github.com/engineering87/sibillaos/releases), verified against its `SHA256SUMS`.

To build from source you only need `xorriso` and `curl` (no root). The build downloads the official Ubuntu 24.04 live-server ISO, verifies its checksum and repacks it with the SibillaOS autoinstall, packages and branding:

```bash
sudo apt-get install xorriso
./packages/build-debs.sh       # build the llmd-* debs
./iso/build.sh                 # out/sibillaos-<version>-amd64.iso
```

Every push to `main` also builds the ISO in CI, boots it in QEMU and runs the automated install end to end; the image is attached to each run as an artifact.

## Repository layout

```
iso/          ISO repack (official Ubuntu live-server + payload) and autoinstall
packages/     Debian packages: hardware detection, engines, gateway, first boot
catalog/      curated model list (signed JSON)
branding/     logo, banner and wallpaper
docs/         architecture document
```

## Status

Working proof of concept: CI builds the ISO, boots it, runs the automated install end to end and verifies the gateway answers on first boot. Before any real deployment be aware that the autoinstall user password is a placeholder and must be replaced, and that engine versions are not yet pinned in the ISO build. The full design, decision log and roadmap live in [docs/architecture.md](docs/architecture.md).

## License

Apache-2.0, see [LICENSE](LICENSE). Bundled components keep their own licenses: vLLM (Apache-2.0), Ollama (MIT), llmfit (MIT). NVIDIA drivers are not redistributed by this repository; the ISO installs them from the Ubuntu `restricted` component.
