# SibillaOS — Documento di architettura v0.4

Data: 2026-07-03 · Stato: bozza consolidata
Changelog v0.2: rimosso target DGX; integrato llmfit per il suggerimento modelli.
Changelog v0.3: Hugging Face come unica fonte modelli; aggiunta sezione licenze.
Changelog v0.4: nome **SibillaOS**; vLLM in container OCI; lista modelli curata con candidati al lancio.
Changelog v0.5: la ISO è ora un **repack della live-server Ubuntu ufficiale** (subiquity/cloud-init riusati così come sono). La ISO costruita da zero con debootstrap bootava ma non aveva un installer funzionante — verificato dall'install test in CI. Dettagli in sibillaos/docs/architecture.md.

## 1. Obiettivo

Distribuzione Linux minimale con motore di inferenza LLM integrato (Ollama o vLLM, selezionato automaticamente in base all'hardware), dove il modello viene consigliato, scelto e scaricato durante l'installazione. Al primo avvio il sistema espone un'API OpenAI-compatible pronta all'uso.

Target: server headless e workstation desktop.

## 2. Decisioni prese

| Ambito | Decisione |
|---|---|
| Nome | **SibillaOS** (verificato libero il 2026-07-03; unico omonimo: un ORM Python "sibilla") |
| Base | Ubuntu 24.04 LTS |
| Engine | Rilevazione automatica: vLLM o Ollama in base all'hardware |
| Deploy vLLM | **Container OCI** (immagine ufficiale, podman + systemd/Quadlet) |
| Target | Server headless e desktop |
| Modelli | Download da **Hugging Face** durante l'install, suggerimento via **llmfit** |
| Catalogo | **Lista curata** firmata (sottoinsieme del catalogo llmfit) |
| Licenza progetto | **Apache-2.0** per i componenti llmd-* |

## 3. Scelta della base

Raccomandazione: **Ubuntu 24.04 LTS** (server: ISO minimal; desktop: variante con GNOME).

Motivazioni: driver NVIDIA e runtime CUDA disponibili nei repository ufficiali e ben mantenuti, autoinstall (Subiquity) maturo per install automatizzate, 5 anni di supporto. Alternativa valida se si vuole una base più "pulita" e community-driven: Debian 13 "trixie" (stable attuale, kernel 6.12 LTS, supporto fino al 2028 + LTS 2030 — [debian.org/releases](https://www.debian.org/releases/stable/)); svantaggio: driver NVIDIA meno aggiornati. Ubuntu 26.04 LTS è più recente ma da valutare quando l'ecosistema NVIDIA sarà allineato.

## 4. Architettura dello stack

```
┌─────────────────────────────────────────────┐
│  (opzionale) Open WebUI — interfaccia web   │
├─────────────────────────────────────────────┤
│  llmd-gateway: reverse proxy (Caddy/nginx)  │
│  API unica OpenAI-compatible su :8080       │
├──────────────────────┬──────────────────────┤
│  Ollama (:11434)     │  vLLM (:8000)        │
│  systemd service     │  systemd service     │
├──────────────────────┴──────────────────────┤
│  llmd-hw: rilevamento hardware + llmfit     │
│  (suggerimento modelli), driver NVIDIA/     │
│  CUDA o ROCm, fallback CPU                  │
├─────────────────────────────────────────────┤
│  Ubuntu 24.04 LTS minimal (server)          │
│  + desktop opzionale (GNOME minimal)        │
└─────────────────────────────────────────────┘
```

Componenti nostri (pacchetti .deb):

- **llmd-hw**: rilevamento GPU (VRAM, vendor, compute capability) per la scelta engine; delega a llmfit il suggerimento modelli.
- **llmfit** (pacchettizzato da noi come .deb): tool esistente in Rust, licenza MIT, che rileva l'hardware e raccomanda modelli con quantizzazione ottimale e stima di velocità. Espone output JSON per scripting: `llmfit recommend --json --limit 5`, con override hardware (`--memory=24G --ram=64G`) e filtro per use-case (`--use-case coding`). Supporta multi-GPU, modelli MoE e i runtime Ollama, vLLM e llama.cpp. Fonti: [GitHub](https://github.com/AlexsJones/llmfit), [llmfit.org](https://www.llmfit.org/).
- **llmd-engine-ollama / llmd-engine-vllm**: engine pacchettizzati con unit systemd hardened.
- **llmd-gateway**: endpoint unico OpenAI-compatible qualunque sia l'engine ([Ollama docs](https://docs.ollama.com/api/openai-compatibility), [vLLM docs](https://docs.vllm.ai/en/latest/)): routing, TLS, API key.
- **llmd-firstboot**: completa/riprende il download del modello al primo avvio se interrotto in fase di install.

## 5. Logica di scelta engine (nell'installer)

| Hardware rilevato | Proposta default |
|---|---|
| GPU NVIDIA datacenter / ≥24 GB VRAM | vLLM |
| GPU NVIDIA consumer / AMD con VRAM limitata | Ollama |
| Solo CPU | Ollama (backend llama.cpp) |

L'utente può sempre forzare la scelta. Requisiti verificati: vLLM supporta NVIDIA (primario), AMD MI200/MI300/MI350 e RX 7900/9000, CPU x86/ARM ([vLLM GPU installation](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/)); Ollama rileva automaticamente CUDA/ROCm e scala i layer sulla VRAM disponibile ([ollama.com/blog](https://ollama.com/blog)).

## 6. Installer: engine + suggerimento modelli con llmfit

Base: **Ubuntu autoinstall (Subiquity)** per la ISO server; variante desktop con lo stesso backend. Per massimo controllo UI: Calamares con modulo custom.

Flusso aggiuntivo rispetto a un install standard:

1. **Rilevamento hardware** (llmd-hw) → proposta engine (tabella §5).
2. **Suggerimento modelli**: l'installer esegue `llmfit recommend --json` nell'ambiente live e mostra i top N modelli che girano bene sull'hardware rilevato, con quantizzazione consigliata, occupazione memoria stimata e velocità attesa (fit: GPU / GPU+CPU offload / CPU). Filtro opzionale per use-case (chat, coding...). L'utente sceglie uno o più modelli.
3. **Download** nella partizione target (`/var/lib/llmd/models`), con resume. Se la rete manca o il download fallisce, l'install completa comunque e llmd-firstboot riprende al primo boot (rieseguendo llmfit se serve).
4. **Configurazione**: porta API, API key generata, Open WebUI (sì/no), esposizione in LAN (sì/no).

### Fonte modelli: Hugging Face (unica)

Hugging Face funziona come fonte unica per entrambi gli engine:

- **Ollama**: pull diretto di GGUF da HF senza Modelfile: `ollama run hf.co/{utente}/{repo}:{quant}` (es. `hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:IQ3_M`) — [documentazione HF](https://huggingface.co/docs/hub/ollama). Limite noto: i GGUF shardati non sono supportati direttamente e vanno prima uniti con `llama-gguf-split --merge`; la lista curata deve includere solo repo a file singolo.
- **vLLM**: carica nativamente i repo HF in formato safetensors.

Attenzione ai **repo gated** (Llama, Gemma e simili richiedono accettazione dei termini e token HF): l'installer di default propone solo modelli non-gated; il supporto ai gated (inserimento token HF) può arrivare in v1.x.

Punto di attenzione: llmfit al momento è distribuito via script/brew/scoop/cargo/pip, non come .deb ([GitHub — Install](https://github.com/AlexsJones/llmfit)); va pacchettizzato da noi (binario statico Rust, operazione semplice). Il suo catalogo modelli va inoltre validato/limitato a una lista curata per l'uso in installer.

## 7. Build della ISO

- Tooling: **live-build** o **debootstrap + squashfs** con pipeline CI (GitLab/GitHub Actions).
- ISO stimata: 3–4 GB (senza modelli) includendo driver NVIDIA e runtime CUDA.
- Repository APT proprio per i pacchetti llmd-* e gli engine. **vLLM gira in container OCI** (immagine ufficiale vllm/vllm-openai) gestito da podman con unit systemd generate via Quadlet: dipendenze CUDA isolate dal sistema, aggiornamenti atomici, rollback immediato. L'immagine non è inclusa nella ISO (diversi GB): viene scaricata all'install solo se l'hardware giustifica vLLM.
- Firma dei pacchetti e della lista modelli (GPG). Secure Boot: kernel/shim firmati Ubuntu, driver NVIDIA con MOK.

## 8. Sicurezza

- Servizi systemd con sandboxing (DynamicUser, ProtectSystem, NoNewPrivileges).
- API non esposta in LAN di default; se abilitata, TLS + API key obbligatoria via gateway.
- Aggiornamenti automatici unattended-upgrades per la base; canale separato per engine e modelli.
- Nessuna telemetria.

## 9. Licenze

*(Nota: questa è un'analisi tecnica, non un parere legale; per la release pubblica serve una verifica legale.)*

**Licenza del progetto (componenti llmd-*, installer, script di build): Apache-2.0.** Motivazioni: permissiva (adozione facile anche in contesti enterprise), include una concessione esplicita di brevetti (che MIT non ha, rilevante in ambito AI), ed è coerente con l'ecosistema che integriamo. Compatibilità verificata dei componenti:

| Componente | Licenza | Fonte |
|---|---|---|
| vLLM | Apache-2.0 | [github.com/vllm-project/vllm/LICENSE](https://github.com/vllm-project/vllm/blob/main/LICENSE) |
| Ollama | MIT | [tech-insider (verifica su repo)](https://github.com/ollama/ollama) |
| llmfit | MIT | [github.com/AlexsJones/llmfit](https://github.com/AlexsJones/llmfit) |
| Base Ubuntu | licenze varie, ridistribuzione gestita da Canonical | — |

Tutte permissive e compatibili con Apache-2.0: possiamo ridistribuirle nella ISO mantenendo i file di licenza originali.

**Driver NVIDIA**: il punto legalmente più delicato. Il [License For Customer Use of NVIDIA Software (Linux)](https://www.nvidia.com/en-us/drivers/nvidia-license/linux/) consente la ridistribuzione dei driver Linux non modificati, ma con condizioni; le distro li gestiscono in componenti separate (Ubuntu "restricted"). Strategia a rischio minimo: **non ridistribuire file NVIDIA direttamente, ma includere nella ISO i pacchetti driver già pacchettizzati da Ubuntu** (come fa la ISO Ubuntu stessa), oppure scaricarli dai repo Ubuntu in fase di install. In più i kernel module NVIDIA moderni (serie open, default per GPU Turing+) sono dual MIT/GPL-2.0 ([github.com/NVIDIA/open-gpu-kernel-modules](https://github.com/NVIDIA/open-gpu-kernel-modules)); restano proprietarie le librerie userspace/CUDA. In caso di dubbio: nvidia-compute-license-questions@nvidia.com.

**Modelli**: la lista curata di default include solo modelli con licenza permissiva e repo non-gated su HF. I modelli con licenze community (Llama, Gemma) non vengono ridistribuiti da noi: l'utente li scarica direttamente da HF accettandone i termini (v1.x, con token HF). llmfit ha già un filtro per licenza integrato.

### Lista curata: candidati al lancio

Selezione basata su fonti di metà 2026 (famiglie con licenza permissiva e disponibilità HF/vLLM/Ollama — [HF blog](https://huggingface.co/blog/daya-shankar/open-source-llms), [PocketLLM license-ranked](https://pocketllm.app/blog/best-open-source-llm-2026/)):

| Fascia hardware | Engine | Candidati (licenza) |
|---|---|---|
| CPU-only / VRAM ≤ 8 GB | Ollama (GGUF quant.) | Qwen3 4B (Apache-2.0), Phi-4-mini (MIT) |
| GPU consumer 8–24 GB | Ollama (GGUF quant.) | Qwen3 14B / 30B-A3B (Apache-2.0), Phi-4 14B (MIT), Mistral Small (Apache-2.0), DeepSeek-R1-Distill (MIT) |
| GPU datacenter ≥ 24 GB | vLLM (safetensors, FP8 dove disponibile) | Qwen3.5-35B-A3B (Apache-2.0), Mistral Small 4 (Apache-2.0), Mistral Large 3 (Apache-2.0, multi-GPU) |

Da verificare in fase di implementazione (non ho potuto confermarli da fonti primarie): gli ID esatti dei repo HF, l'assenza di gating per ciascun repo e le versioni correnti delle famiglie (le fonti citano anche DeepSeek V4 e GLM-5, entrambi MIT, ma sono modelli molto grandi, fuori fascia per il lancio). La quantizzazione ottimale per fascia la calcola llmfit a runtime: la lista fissa le famiglie ammesse, non i file.

## 10. Roadmap proposta

| Fase | Contenuto | Durata indicativa |
|---|---|---|
| PoC | ISO Ubuntu 24.04 minimal + Ollama preinstallato + autoinstall con download modello hardcoded | 2–3 settimane |
| MVP | Integrazione llmfit nell'installer (recommend --json), llmd-hw, gateway, firstboot resume | 4–6 settimane |
| v1.0 | vLLM come seconda opzione con auto-detect, variante desktop + Open WebUI, CI di build ISO | 6–8 settimane |

## 11. Stato decisioni

Tutte le decisioni di progetto sono prese (v. tabella §2). Restano attività di verifica, non di design:

1. Conferma ID repo HF e gating per i modelli candidati (§9) in fase di implementazione.
2. Verifica legale prima della release pubblica (driver NVIDIA in particolare).
3. Branding: logo e dominio per SibillaOS (nome verificato libero, dominio da registrare).

## Fonti verificate (2026-07-03)

- [llmfit — GitHub (MIT, CLI/TUI, recommend --json, provider Ollama/vLLM/llama.cpp)](https://github.com/AlexsJones/llmfit) · [llmfit.org](https://www.llmfit.org/)
- [Debian 13 "trixie" — release information](https://www.debian.org/releases/stable/)
- [vLLM — installazione GPU e hardware supportato](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/) · [vLLM docs](https://docs.vllm.ai/en/latest/)
- [Ollama — OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility) · [Ollama blog](https://ollama.com/blog)
- [Hugging Face — Use Ollama with any GGUF model](https://huggingface.co/docs/hub/ollama)
- [vLLM LICENSE (Apache-2.0)](https://github.com/vllm-project/vllm/blob/main/LICENSE)
- [NVIDIA — License For Customer Use of NVIDIA Software (Linux)](https://www.nvidia.com/en-us/drivers/nvidia-license/linux/) · [NVIDIA open-gpu-kernel-modules (MIT/GPL-2.0)](https://github.com/NVIDIA/open-gpu-kernel-modules)
- Modelli permissivi 2026: [HF blog — Best open-source LLMs 2026](https://huggingface.co/blog/daya-shankar/open-source-llms) · [PocketLLM — license-ranked](https://pocketllm.app/blog/best-open-source-llm-2026/) (fonti secondarie: ID repo da confermare)
- Verifica nome (2026-07-03): nessuna distro "SibillaOS"/"InferOS"/"LemmaOS" trovata; "GenioOS" scartato per collisioni (MediaTek Genio, Quidgest Genio, Semvox geni:OS)
