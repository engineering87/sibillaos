# Post LinkedIn — SibillaOS (bilingue, immagine: sibillaos/branding/social-card.png)

🔮 Quanto ci vuole per passare da "voglio un LLM in locale" ad avere un'API funzionante?

Di solito: scegliere l'engine giusto, capire quale modello sta nella tua VRAM, azzeccare la quantizzazione, configurare servizi, chiavi, systemd. Ore, se sai già dove mettere le mani.

Ho provato un approccio diverso: spostare tutte queste decisioni dentro l'installer di una distro Linux. È nato SibillaOS, un proof of concept open source basato su Ubuntu 24.04:

🧠 rileva l'hardware e sceglie l'engine (vLLM su GPU datacenter, Ollama altrove, CPU comprese)
📏 propone solo modelli che stanno davvero in memoria, con la quantizzazione giusta (grazie a llmfit)
⬇️ scarica il modello da Hugging Face durante l'installazione
🔑 al primo avvio: API OpenAI-compatible autenticata, pronta sulla porta 8080

Perché insistere sul locale? Perché ci sono contesti in cui i dati non possono uscire: sanità, pubblica amministrazione, legale, industria. E perché un modello che gira sul tuo hardware ha costi prevedibili e zero dipendenze da servizi esterni. La barriera non è mai stata l'hardware, è il tempo di messa in opera: è quella che vale la pena abbattere.

Tutto open source (Apache 2.0), stato dichiarato: proof of concept, roadmap aperta.
🔗 https://github.com/engineering87/sibillaos
🤝 Aperto in tutti i sensi: issue, PR e idee sono benvenute.

E voi che lavorate con LLM on-premise: qual è il passaggio che vi costa più tempo, dal metallo al primo token?

---

🔮 How long does it take to go from "I want a local LLM" to a working API?

Usually: pick the right engine, figure out which model fits your VRAM, get the quantization right, wire up services, keys, systemd. Hours, if you already know your way around.

I tried a different approach: moving all of those decisions into a Linux distro installer. The result is SibillaOS, an open source proof of concept based on Ubuntu 24.04:

🧠 detects your hardware and picks the engine (vLLM on datacenter GPUs, Ollama everywhere else, CPUs included)
📏 suggests only models that actually fit in memory, with the right quantization (thanks to llmfit)
⬇️ downloads the model from Hugging Face during installation
🔑 on first boot: an authenticated OpenAI-compatible API, ready on port 8080

Why insist on local? Because in some contexts data simply cannot leave: healthcare, public sector, legal, manufacturing. And because a model running on your own hardware has predictable costs and no external dependencies. The barrier was never the hardware, it is the setup time: that is the one worth tearing down.

Fully open source (Apache 2.0), honestly labeled: proof of concept, open roadmap.
🔗 https://github.com/engineering87/sibillaos
🤝 Open in every sense: issues, PRs and ideas are welcome.

If you run LLMs on-premise: which step costs you the most time, from bare metal to first token?

#opensource #linux #llm #selfhosting #ai #devops #ubuntu
