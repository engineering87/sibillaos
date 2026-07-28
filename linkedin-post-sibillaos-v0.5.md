# Post LinkedIn — SibillaOS v0.5.0 (maturità del progetto)

Testo pronto da incollare. Sotto, le note sulle immagini.

---

SibillaOS started with a simple pitch: install Linux, get a working LLM API. Nothing else to set up.

Five releases later the pitch is unchanged. What changed is everything around it: the parts that do not show up in a screenshot.

Every push to the repository builds the ISO, boots it under BIOS, UEFI and UEFI Secure Boot, runs the unattended install in a VM and gets a real chat completion through the authenticated gateway. On amd64 and arm64, on every single change.

The supply chain is reviewable end to end: a GPG-signed APT repository, a signed model catalog with per-artifact sha256 digests verified after every download, an SBOM attached to every release, CVE scanning of the actually-installed system with a written triage policy.

And with v0.5.0, trying it no longer costs you a machine. On any Ubuntu 24.04 box:

sudo apt install llmd
sudo sibilla setup

That is it: hardware detected, engine installed (Ollama or vLLM, picked for your hardware), a model that actually fits your RAM and VRAM downloaded, and an OpenAI-compatible API served on port 8080 behind mandatory API keys. It behaves as a guest: your firewall and your package sources stay yours.

Changed your mind? sudo sibilla remove takes out exactly what it installed, restores what it displaced and leaves the machine as it found it. That is not a claim, it is a test: CI installs the stack, uses it, removes it and asserts the machine is clean, on every push.

Local LLM serving is not hard because inference is hard. It is hard because of the choices: which engine, which model, which quantization, how to expose it without leaving it wide open. SibillaOS makes those choices for you and keeps your data on your machine.

Everything is open source, Apache 2.0: https://github.com/engineering87/sibillaos

Feedback, issues and testers are very welcome, especially if you have datacenter GPUs or physical Secure Boot machines to try it on.

#opensource #llm #selfhosted #linux #ubuntu #ai #ollama #vllm #privacy

---

## Immagini (in questa cartella)

LinkedIn non accetta SVG, quindi le grafiche del README sono state
convertite in PNG:

1. linkedin-demo-quickstart.png (1600x783) — la sessione terminale.
   Consigliata come immagine principale: mostra il prodotto in azione,
   formato orizzontale ideale per il feed.
2. linkedin-architecture.png (1600x1179) — il diagramma architetturale.
   Ottima come seconda immagine (LinkedIn supporta post multi-immagine).
3. linkedin-social-card.png (1200x627) — la social card del brand,
   nel formato esatto delle link preview.

Suggerimento: post con le prime due in coppia (terminale, poi
architettura). In alternativa, solo la demo del terminale.

Nota tempistica: pubblicare dopo il tag v0.5.0, quando il repo APT su
Pages serve i pacchetti 0.5.0 e i due comandi del post funzionano
davvero per chiunque li provi.
