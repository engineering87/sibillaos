# Embeddings for local RAG

Retrieval-augmented generation needs two models: one that embeds your
documents into vectors, one that chats over what retrieval finds.
SibillaOS serves both through the same authenticated gateway, so a
fully local RAG stack (your vector store of choice plus this machine)
never sends a document anywhere.

The curated catalog carries embedding models under a dedicated role:
they are listed separately by `sibilla model list`, are never picked
as the chat default (the selector skips them and `sibilla model use`
refuses them), and arrive with the same digest verification as every
other model:

```console
$ sudo sibilla model pull hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0
digest verified: ... is the reviewed artifact (sha256:3e2434...)
pulled: hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0 (the served chat model is unchanged: ...)
```

Then call the standard OpenAI embeddings endpoint:

```console
$ curl http://YOUR_HOST:8080/v1/embeddings \
    -H "Authorization: Bearer YOUR_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model": "hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0",
         "input": "text to embed"}'
```

Any OpenAI-compatible RAG framework (LangChain, LlamaIndex, a plain
client) works by pointing its embeddings backend at the same base URL
and key as the chat model. On air-gapped machines the embedding model
travels on the payload stick like any other GGUF (docs/airgap.md):
`sibilla model import` identifies it by digest and it serves from the
local store.

Current catalog entry: nomic-embed-text v1.5 (Apache-2.0, 768
dimensions, 2048-token context, ~146 MB at Q8_0). Additions follow
the usual catalog criteria: permissive license, non-gated repository,
recorded digests.
