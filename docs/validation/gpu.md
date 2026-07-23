# GPU validation guide (call for testers)

CI has no GPUs, so this is where external hands matter most. If you
own an NVIDIA card, an AMD card or a Ryzen APU and can spare thirty
minutes, this checklist turns your machine into exactly the data the
project needs. Open an issue titled "GPU validation: <your hardware>"
with the results; the tools below produce paste-ready output with no
secrets in it.

## Prerequisites

Any SibillaOS install: ISO, cloud image, or `apt install llmd` plus
`sudo sibilla setup` on an existing Ubuntu 24.04 (reversible with
`sudo sibilla remove`).

## NVIDIA checklist

1. Driver: `nvidia-smi` must answer. On ISO installs the installer
   offers the Ubuntu restricted driver; on your own Ubuntu install it
   with `sudo ubuntu-drivers install`.
2. Detection: `sudo /usr/lib/llmd/llmd-hw-detect --json`. Expected:
   `"vendor":"nvidia"`, your VRAM, and `"engine":"vllm"` at 24 GB and
   above, `"engine":"ollama"` below.
3. Engine sees the GPU: `journalctl -u ollama | grep "inference compute"`.
   Expected: a line with `library=cuda` and your card, not `library=cpu`.
4. Proof by numbers: `sudo sibilla bench`. A GPU run is unmistakable
   (tens to hundreds of tok/s against single digits on CPU). Paste
   the table in the issue.
5. `sudo sibilla doctor` and paste the report (secrets are scrubbed
   by construction).

## AMD checklist (discrete cards and APUs)

1. Detection: `sudo /usr/lib/llmd/llmd-hw-detect --json`. Expected:
   `"vendor":"amd"`, `"engine":"ollama"`.
2. ROCm runtime: `sibilla status` reports it. On machines whose GPU
   was visible at install time the ollama installer bundles it; cloud
   images are baked without a GPU, so first boot completes the
   install on the real hardware (needs network; air-gapped AMD is a
   known limit for now). "ROCm runtime missing" in `sibilla status`
   after a completed first boot is a bug: report it.
3. Engine sees the GPU: `journalctl -u ollama | grep "inference compute"`.
   Expected: `library=rocm` and your card.
4. APUs (Strix Halo and friends): ROCm may not recognize the gfx
   version out of the box. The known workaround is setting
   `HSA_OVERRIDE_GFX_VERSION` (value depends on the chip) via
   `sudo systemctl edit ollama` - we deliberately do not set it
   automatically, wrong values crash the runtime. If an override made
   your APU work, say WHICH value in the issue: collecting these
   pairs is half the reason this guide exists.
5. `sudo sibilla bench` and `sudo sibilla doctor`, paste both.

## What to report

Open a "GPU validation report" issue: the repository ships a
structured form (.github/ISSUE_TEMPLATE/gpu-validation.yml) with a
field for each item above - hardware, install path, detect JSON,
inference-compute journal line, bench table, the APU override value
when one was needed, the doctor report. Negative results are as
valuable as positive ones.

## Result record

| Date | Hardware | Path | Detect | Engine sees GPU | Bench tok/s | Notes |
|------|----------|------|--------|-----------------|-------------|-------|
| (pending first report) | | | | | | |
