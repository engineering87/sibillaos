# Large models: bigger than your GPU, honestly

The large tier carries models whose weights do not fit in your GPU's
VRAM but do fit in system RAM. The engine loads as many layers as the
GPU holds and spills the rest to RAM, where the CPU computes them.
This works, it is real, and it is slower than a model that fits the
GPU - this page states by how much, how to measure it on your machine,
and when a smaller model is the better call.

Large models are strictly opt-in. First boot never selects one, and
nothing in SibillaOS will ever switch you to one silently. The machine
you get by default serves what it honestly runs at full speed.

## What the tier promises, and what it does not

The shipped engine does layer offload: whole transformer layers move
to RAM when VRAM runs out. It does NOT stream mixture-of-experts
weights from disk - that capability is an open feature request
upstream, and models bigger than your RAM remain out of reach (the
[roadmap](../ROADMAP.md) tracks the projects working on that). So the
honest claim is "larger than VRAM", never "larger than RAM".

Below the RAM floor there is no degraded mode, only a frozen machine:
a model that exceeds physical memory pushes the system into swap
thrashing. That is why `sibilla model use` refuses - fail closed,
before a byte is downloaded, with no `--force`:

```console
$ sudo sibilla model use qwen3:235b
REFUSING: qwen3:235b needs ~170 GB of RAM and this machine has 32 GB.
A model past the RAM floor does not run slowly, it freezes the box in swap.
See 'sibilla model list' for what fits this machine.
```

On a machine above the floor, the same command states the cost and
proceeds:

```console
$ sudo sibilla model use gpt-oss:120b
large model: ~80 GB RAM needed, 128 GB present; layers beyond the GPU spill to RAM
generation will be slower than a model that fits the GPU; the real split shows in: sibilla status
```

## Seeing the real placement

`sibilla status` prints where the loaded model actually sits. The
placement line comes from the engine itself, not from an estimate:

```
placement: 18%/82% CPU/GPU
```

100% GPU means no spill (the model fits after all); a growing CPU
share means more layers run on the CPU, and generation speed falls
with it. If you expected GPU and see 100% CPU, check the GPU section
of `sibilla status` first - on AMD machines a missing ROCm runtime is
the usual cause (see [validation/gpu.md](validation/gpu.md)).

## Measuring the cost instead of guessing it

`sibilla bench` measures through the authenticated gateway, so its
numbers are what a client experiences: time to first token and
generation speed, median of three runs. Run it once on the large model
and once on your tier's default, and the trade is in front of you:

```console
$ sibilla bench                      # against the served model
$ sudo sibilla model use gpt-oss:120b
$ sibilla bench
```

The output is a markdown table made for pasting into an issue or a
team chat. There is no universal number worth printing here: the split
depends on your VRAM, your RAM bandwidth and the model, which is
exactly why the tooling measures instead of promising.

## When the giant is the wrong call

A large MoE model activates only a fraction of its parameters per
token, and its strength is knowledge breadth and reasoning depth, not
speed. Prefer the smaller default when:

- the workload is interactive chat and latency dominates the
  experience: a 14B model that answers at full GPU speed feels better
  than a 120B model that makes you wait;
- the machine also serves embeddings or several clients: layers
  spilled to RAM compete with everything else for memory bandwidth;
- the task is retrieval-heavy RAG, where answer quality often hinges
  more on retrieval than on model size (see
  [embeddings.md](embeddings.md)).

Reach for the large tier when the task is hard enough that the default
model visibly fails at it, and the wait is acceptable. `sibilla model
list` shows what your machine can hold, with the RAM each large entry
needs; switching back is one `sibilla model use` away.

## Supply chain, same rules

Large-tier entries come from the ollama.com registry rather than
Hugging Face - the only source exception in the catalog, made because
large models ship as sharded GGUF that the hf.co pull path does not
support. Verification does not change: the registry manifests carry
sha256 layer digests, recorded in the signed catalog and checked after
every pull, and a mismatched artifact is refused exactly like any
other model. Air-gapped delivery through `sibilla model import` works
for large models too, RAM floor included - only the download size
makes the USB stick less convenient.
