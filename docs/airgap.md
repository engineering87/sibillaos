# Air-gapped installs

Some machines are not allowed to reach the internet, and those are
exactly the machines the on-premise pitch is about. SibillaOS supports
them with a companion payload: a second volume carrying the model
files, prepared on a machine that does have network, verified on the
machine that does not.

Trust does not travel on the stick. Every file entering the payload is
verified against the per-quant sha256 digests of the GPG-signed model
catalog at build time, and verified again by the machine at import
time, with the catalog copy it already carries. A file the catalog
does not know is refused on both ends.

## Prepare the payload (connected machine)

```console
$ git clone https://github.com/engineering87/sibillaos && cd sibillaos
$ ./tools/build-airgap-payload.sh --out /media/usb \
    --model hf.co/bartowski/Qwen_Qwen3-4B-GGUF:Q4_K_M
```

The tool resolves each model on Hugging Face by its catalog digest,
downloads it, verifies the sha256 and writes `models/`, `SHA256SUMS`,
`MANIFEST.txt` and a `profile` declaring the first model (pass
`--profile FILE` to provide your own; the whole
[profile format](configuration.md) works, so TLS or MCP can be
declared on the same stick). Only catalog entries with recorded
digests are eligible; run the tool without arguments to list them.
With `HF_TOKEN` set in the environment the Hugging Face requests are
authenticated, which matters behind shared IPs (CI runners, corporate
NAT) that anonymous rate limits hit first. A file already present in
the output that matches its digest is reused without any network.

The volume must carry the filesystem label `SIBILLA-AIRGAP`:

```console
$ sudo mkfs.ext4 -L SIBILLA-AIRGAP /dev/sdX1   # once, when formatting
```

## Install (air-gapped machine)

Attach the payload volume before the machine's first boot, then
install from the ISO or boot the cloud image as usual. At first boot
llmd-firstboot detects the payload, imports every model file through
the digest gate, applies the profile, and serves - no outbound
network involved. The imported model skips the download entirely.

On a machine that is already running, the same files import by hand:

```console
$ sudo mount -o ro /dev/disk/by-label/SIBILLA-AIRGAP /mnt
$ sudo sibilla model import /mnt/models/MODEL.gguf --use
```

## Scope and limits

The offline path covers the Ollama engine (GGUF files). vLLM machines
(datacenter GPUs) typically sit behind a local registry and artifact
store; bringing the vLLM container image and safetensors in by stick
is not supported yet. The engine itself ships inside the SibillaOS
images, so only the model needs to travel. Package updates still
require a reachable mirror or a local one; unattended-upgrades simply
stays idle without network.

## What CI proves

On every push, a VM boots the cloud image with the payload disk
attached and every outbound packet dropped (QEMU user networking in
restricted mode). The test asserts that the payload is detected, the
model arrives through the digest gate and not through a pull, the
guest really cannot reach the internet, and a chat completion comes
back through the authenticated gateway.
