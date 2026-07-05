<div align="center">

<img src="branding/banner.png" alt="SibillaOS" width="820"/>

<br/>

**Install Linux, get a working LLM API. Nothing else to set up.**

[![License](https://img.shields.io/badge/license-Apache--2.0-2e9e63.svg)](LICENSE)
[![Base](https://img.shields.io/badge/base-Ubuntu%2024.04%20LTS-e95420.svg)](https://ubuntu.com)
[![Build](https://github.com/engineering87/sibillaos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/engineering87/sibillaos/actions/workflows/build-iso.yml)
[![Status](https://img.shields.io/badge/status-proof%20of%20concept-3ddc84.svg)](docs/architecture.md)

</div>

<br/>

Running a local LLM still means picking an engine, matching a model to your VRAM, choosing a quantization and wiring up a service. SibillaOS does all of that for you. Boot the ISO, walk through the standard Ubuntu screens (locale, network, disk, your user), and the first thing your machine does after installing is serve an OpenAI-compatible API.

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
| **Model management** | `sibilla-model list` shows what fits your machine, `sibilla-model use ID` downloads and switches the served model. |

Two variants: headless server and desktop (GNOME, optional Open WebUI).

## Getting started

The easiest path is a prebuilt ISO from [Releases](https://github.com/engineering87/sibillaos/releases), verified against its `SHA256SUMS`. GitHub caps release assets at 2 GiB, so the ISO ships in parts: `cat sibillaos-*.iso.part* > sibillaos.iso` reassembles it.

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

Working proof of concept: on every push, CI builds the ISO, boots it under BIOS and UEFI, runs the install end to end and gets a real chat completion through the gateway on first boot. Engine versions are pinned in the installer. Release ISOs walk you through the standard installer screens and you choose your own credentials; only the fully unattended CI images use a fixed test user. The full design, decision log and roadmap live in [docs/architecture.md](docs/architecture.md).

## Contributing

Contributions are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the build setup, the CI test suite your change has to pass, and the criteria for model catalog additions.

## License

Apache-2.0, see [LICENSE](LICENSE). Bundled components keep their own licenses: vLLM (Apache-2.0), Ollama (MIT), llmfit (MIT). NVIDIA drivers are not redistributed by this repository; the ISO installs them from the Ubuntu `restricted` component.
