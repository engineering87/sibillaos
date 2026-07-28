# SibillaOS — Discord showcase post

> Read #rules first and post in the server's showcase/projects channel.
> Discord strips Markdown headings; the version below is written to
> paste as-is (bold and backticks render, headings do not).

---

**SibillaOS — install Linux, get a working local LLM API on first boot**

How long does it take you to go from "I want a local LLM" to a working OpenAI-compatible endpoint? Picking the engine, matching a model to your VRAM, getting the quantization right, wiring up services and keys… it adds up.

I tried moving all of that into a Linux installer. SibillaOS is an open-source proof of concept (Apache-2.0, Ubuntu 24.04 based):

- detects the hardware and picks the engine — **Ollama** everywhere, vLLM on datacenter GPUs, CPU included
- uses llmfit to suggest only models that actually fit your memory, then pulls the pick from Hugging Face during install
- first boot serves an authenticated OpenAI-compatible API on :8080, behind a gateway (multi-key, TLS optional, Prometheus metrics)
- ships as an ISO (amd64) and a cloud-init qcow2 image (amd64 + arm64)

Everything runs through CI on every commit: it builds the image, installs it in a VM, downloads a model and gets a real chat completion — plus Secure Boot, signed model catalog and an SBOM/CVE scan, if that's your thing.

It's honestly labeled a PoC and the roadmap is open. Not selling anything — I'd genuinely like feedback from people who run models locally: what's the step that costs *you* the most time, from bare metal to first token?

Repo: <https://github.com/engineering87/sibillaos>
