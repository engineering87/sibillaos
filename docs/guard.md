# The guard: a verdict before the engine

An appliance that serves third parties through API keys eventually
faces the question every serving stack faces: what happens when a
request asks for something the operator does not want answered?
`sibilla guard enable` puts a guard model in front of chat:

```console
$ sudo sibilla guard enable
```

downloads Qwen3Guard-Gen-0.6B (Apache-2.0, ~805 MB, digest-verified
against the signed catalog, fail closed) and routes
`/v1/chat/completions` through a loopback guard stage. For every
request, the last user message is classified by the verdict model;
requests judged Unsafe are refused with an explicit, machine-readable
error:

```json
{"error": {"message": "blocked by the guard model (safety: Unsafe; categories: Violent.)",
           "type": "sibilla_guard", "code": "content_blocked"}}
```

Everything else reaches the engine untouched - same body, streaming
included - and every other endpoint (embeddings, rerank, audio) keeps
its straight path. Requests judged Controversial are forwarded and
logged; set `LLMD_GUARD_STRICT=1` on `llmd-guard-proxy.service` to
block them too.

## What runs underneath

Two loopback services behind the gateway's 401, in the standard
sandbox: the verdict model on a second llama-server (the same pinned
binary the reranker ships - one llama.cpp serves both sidecars), and
a dependency-free Python stdlib proxy that asks it for the verdict
and forwards or refuses. The official Qwen3Guard safety template
travels inside the GGUF itself, so the verdict prompt is the vendor's
own, not ours.

## The honest edges

The guard fails closed: if the verdict model does not answer, the
request does not pass (the error says so, and how to disable). The
verdict covers the text of the last user message; images in vision
requests are not classified. A 0.6B classifier is a filter, not a
guarantee: pair it with `sibilla doctor --redteam` to see how your
configuration actually behaves under adversarial prompts. And as
always, every verdict happens on loopback: nothing leaves the
machine, including the prompts someone tried.

Disable any time with `sudo sibilla guard disable`; the chat route
returns to the engine directly.
