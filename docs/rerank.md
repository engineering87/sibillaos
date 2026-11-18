# Reranking: the missing middle of RAG

Embedding search retrieves what is similar; a reranker decides what
is relevant. The standard RAG failure is feeding the chat model ten
similar-looking chunks where only two answer the question. The fix is
a cross-encoder that reads the query against each candidate and
scores them together: retrieve wide with embeddings, rerank the
candidates, hand the model the best few.

```console
$ sudo sibilla rerank enable
```

downloads Qwen3-Reranker-0.6B (Apache-2.0, ~640 MB, digest-verified
against the signed catalog, fail closed) and serves it from a
loopback llama.cpp server behind the gateway:

```console
$ curl -s https://my-llm-server:8080/v1/rerank \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d '{
      "query": "What is the capital of France?",
      "documents": [
        "Paris is the capital and largest city of France.",
        "Bananas are yellow and rich in potassium."
      ]
    }'
```

The response scores every document (`results[].relevance_score`,
higher is more relevant), same bearer keys as the rest of the API.
`top_n` limits how many come back.

## In a RAG pipeline

With [embeddings](embeddings.md) already in place, reranking is one
extra call between retrieval and generation:

1. embed the query, take the top 20 chunks by cosine similarity
2. POST query + those 20 chunks to `/v1/rerank`
3. keep the top 3 by relevance score, build the prompt from them

The 0.6B reranker reads every query-document pair in full, which is
exactly the work embeddings skip, and why it catches what they miss.

## What runs underneath

A pinned llama.cpp server (build recorded in
`packages/build-debs.sh`, sha256-verified at deb build) in reranking
mode, loopback only, same systemd sandbox as every other sidecar:
dynamic user, no access to the API keys, the gateway's 401 is the
whole authentication story. The GGUF is a community conversion
chosen because the official weights ship no GGUF and most community
conversions are broken for llama.cpp's rerank endpoint (missing
rerank template, null scores); the pinned one is verified by digest
and exercised by CI on every push with a relevance assertion, so a
bad conversion cannot ship silently.

Disable it any time with `sudo sibilla rerank disable`; the route
disappears from the gateway and the service stops.
