# Pacchetto distribuzione SibillaOS (post-v0.7.0)

Quattro testi pronti, in ordine di priorita'. **Tempistica: pubblicare
dopo il tag v0.7.0** — i link alla guida GPU e alla sezione
"Why not just Ollama?" funzionano solo quando release/0.7 e' su main.
Immagini disponibili nella cartella: linkedin-demo-quickstart.png,
linkedin-architecture.png, linkedin-social-card.png (dopo la release,
scaricabile anche demo.svg autentica dall'artifact terminal-demo).

---

## 1. Reddit r/LocalLLaMA (priorita' massima: il pubblico giusto)

**Titolo:**

I built an Ubuntu-based distro that boots straight into an authenticated local LLM API - looking for GPU testers (NVIDIA / AMD / Ryzen APU)

**Body:**

Over the past months I have been building SibillaOS: install Linux, get a working OpenAI-compatible API on port 8080 at first boot. Engine (Ollama or vLLM) and model picked for your hardware, downloaded during install, served behind mandatory API keys.

Before you say "that's just ollama with extra steps" - fair, and the README answers it head on. The short version of what the distro adds around the engine: auth is on from the first second (per-client keys, one-command TLS), every model artifact is verified against a GPG-signed catalog with sha256 digests and refused on mismatch, the whole thing installs and serves fully air-gapped from a verified USB payload, configuration is one declared file any machine converges on, agents get MCP tools and RAG gets /v1/embeddings behind the same keys, and if you want out, `sudo sibilla remove` returns the machine as it found it - CI proves that on every push. Also: the engine's cloud offload is hard-disabled, nothing in a prompt leaves the box, including via ollama's own cloud routing.

You do not need to reinstall anything to try it - on any Ubuntu 24.04 box it is two commands (apt install llmd, sibilla setup) and one to leave.

**The ask:** my CI proves everything except silicon - it has no GPUs. If you own an NVIDIA card, an AMD card or a Ryzen APU and can spare thirty minutes, there is a validation guide (docs/validation/gpu.md in the repo) and two commands (`sibilla bench`, `sibilla doctor`) that produce paste-ready, secret-free results. APU owners: I am specifically collecting working HSA_OVERRIDE_GFX_VERSION values. Negative results are as valuable as positive ones.

Honest status: working proof of concept, sixteen-ish CI jobs green on every push (unattended install, real inference, Secure Boot, air-gapped deploy in a network-cut VM, live upgrade test), zero external validation on real GPUs yet. That last part is where you come in.

Repo: https://github.com/engineering87/sibillaos

**Note di stile:** niente immagini nel post (r/LocalLLaMA preferisce testo);
rispondere ai commenti tecnici rapidamente le prime ore; se qualcuno
posta una tabella bench, ringraziare e aggiungerla al result record.

---

## 2. LinkedIn (inglese, aggiorna la storia alla v0.6/v0.7)

SibillaOS started with one pitch: install Linux, get a working LLM API. Nothing else to set up.

Seven releases later the pitch has not changed - what changed is what surrounds it.

Your agents can use it: the machine exposes its local model to Claude Code and any MCP client as tools, behind the same API keys as the API. Work on sensitive material gets delegated to a model that cannot exfiltrate it - the engine's own cloud routing is hard-disabled, verified in CI on every install path.

It works with the network cable unplugged: models travel on a USB payload, verified on both ends against a GPG-signed catalog. CI proves it by booting the image in a VM where every outbound packet is dropped, and requiring a real completion.

It scales past one machine: the whole configuration is a single declared file. cloud-init writes it, first boot converges on it, `sibilla apply export` clones a configured box.

And it can prove itself on your hardware: `sudo sibilla bench` measures first-token latency and tokens/second through the authenticated gateway and prints a table worth sharing.

One thing CI cannot prove is silicon: the pipeline has no GPUs. If you own an NVIDIA card, an AMD card or a Ryzen APU, there is a thirty-minute validation guide in the repo and I would genuinely value the results - the tooling produces paste-ready, secret-free reports.

Everything is open, Apache-2.0: https://github.com/engineering87/sibillaos

#opensource #llm #selfhosted #linux #ubuntu #ai #ollama #vllm #privacy #rag

**Immagini:** linkedin-demo-quickstart.png + linkedin-architecture.png
(coppia), o la demo.svg autentica post-release convertita in PNG.

---

## 3. Show HN (se vuoi tentare Hacker News)

**Titolo:**

Show HN: SibillaOS - Ubuntu-based distro that boots into an authenticated local LLM API

**Testo:**

I kept seeing the same gap: running a local LLM is easy, running it as something a team or a compliance review can live with is not. SibillaOS is an Ubuntu 24.04 derivative that makes the decisions at install time: engine picked for the hardware (Ollama/vLLM), model sized to RAM/VRAM, and from first boot an OpenAI-compatible API behind mandatory keys. Model artifacts verify against a GPG-signed catalog; it installs fully air-gapped from a verified USB payload; configuration is one declared file; MCP tools and /v1/embeddings come out of the same gateway; `sibilla remove` provably returns the machine as found. CI builds the ISO, installs it unattended, runs real inference, boots it with Secure Boot enforced and with the network cut, and upgrade-tests against the published repo on every push. What CI cannot do is validate real GPUs - there is a tester guide in the repo and I would value results from NVIDIA/AMD/APU owners. AMA about the design decisions, the decision log in docs/architecture.md is unusually honest.

**Note:** postare in orario US-mattina; primo commento tuo con i
dettagli tecnici piu' controversi (repack ISO, Caddy vs nginx ADR,
niente k8s) per innescare la discussione giusta.

---

## 4. Discord (server Ollama / LocalLLaMA / self-hosting, breve)

SibillaOS v0.7: Ubuntu-based distro that boots into an authenticated local LLM API (Ollama/vLLM auto-picked, model sized to your hardware). New this cycle: CI-recorded demo (not acted), engine cloud routing hard-disabled, and proper AMD/ROCm support - which is where I need help: CI has no GPUs. If you have an NVIDIA card, AMD card or Ryzen APU, 30 minutes + the guide in docs/validation/gpu.md = exactly the data the project needs. `sibilla bench` gives you a shareable table, `sibilla doctor` a secret-free report. https://github.com/engineering87/sibillaos

---

## Sequenza consigliata

1. Tag v0.7.0 (i link diventano veri).
2. Reddit r/LocalLLaMA (il pubblico che possiede l'hardware).
3. Discord lo stesso giorno.
4. LinkedIn il giorno dopo (pubblico diverso, nessuna fretta).
5. Show HN solo quando puoi presidiare i commenti per qualche ora.
6. Ogni tabella bench ricevuta va nel result record di
   docs/validation/gpu.md: il file che si riempie E' la social proof.
