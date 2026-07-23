#!/usr/bin/env python3
"""Local RAG against a SibillaOS machine, in one file, standard
library only: no framework required, nothing to pip install. The same
two endpoints any framework would use - /v1/embeddings to index,
/v1/chat/completions to answer - both behind the machine's API key,
so no document and no question ever leaves the box.

Setup (the env comes straight from the machine):

    sudo sibilla model pull hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0
    sudo sibilla connect --env > sibilla.env
    set -a; . ./sibilla.env; set +a
    python3 rag-quickstart.py "What port does SibillaOS serve on?"

Swap DOCS for your own corpus and this is a working pipeline; for
LangChain and LlamaIndex configurations, see docs/embeddings.md.
"""

import json
import math
import os
import sys
import urllib.request

BASE = os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8080/v1")
KEY = os.environ.get("OPENAI_API_KEY", "")
CHAT_MODEL = os.environ.get("OPENAI_MODEL", "")
EMBED_MODEL = os.environ.get(
    "SIBILLA_EMBED_MODEL", "hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0"
)

DOCS = [
    "The Lighthouse of Alexandria was completed around 280 BC on the "
    "island of Pharos and stood over one hundred meters tall.",
    "SibillaOS serves an OpenAI-compatible API on port 8080, behind "
    "mandatory bearer keys, from the first boot of the machine.",
    "Traditional basil pesto originates from Genoa and is ground in a "
    "marble mortar with a wooden pestle.",
]


def call(path, payload):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + KEY,
        },
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.load(resp)


def embed(text):
    reply = call("/embeddings", {"model": EMBED_MODEL, "input": text})
    return reply["data"][0]["embedding"]


def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    norm = math.sqrt(sum(x * x for x in a)) * math.sqrt(sum(y * y for y in b))
    return dot / norm if norm else 0.0


def main():
    if not KEY or not CHAT_MODEL:
        sys.exit("set the environment first: sudo sibilla connect --env")
    question = sys.argv[1] if len(sys.argv) > 1 else "What port does SibillaOS serve on?"

    # index: one vector per document (a real corpus would chunk and
    # persist these; three sentences do not need a vector database)
    doc_vectors = [embed(d) for d in DOCS]
    q_vector = embed(question)

    ranked = sorted(
        zip(DOCS, doc_vectors), key=lambda p: cosine(q_vector, p[1]), reverse=True
    )
    context = ranked[0][0]
    print("retrieved: " + context)

    reply = call(
        "/chat/completions",
        {
            "model": CHAT_MODEL,
            "max_tokens": 200,
            "messages": [
                {
                    "role": "system",
                    "content": "Answer strictly from the provided context, "
                    "in one sentence.",
                },
                {
                    "role": "user",
                    "content": "Context: " + context + "\n\nQuestion: " + question,
                },
            ],
        },
    )
    message = reply["choices"][0]["message"]
    print("answer:    " + (message.get("content") or message.get("reasoning") or ""))


if __name__ == "__main__":
    main()
