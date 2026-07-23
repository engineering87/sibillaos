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

## Quickstart: RAG in one file, no framework

[examples/rag-quickstart.py](../examples/rag-quickstart.py) is a
complete pipeline in ~100 lines of Python standard library: index
three documents through `/v1/embeddings`, retrieve by cosine
similarity, answer through `/v1/chat/completions` with the retrieved
context. CI runs it end to end on every push. The environment comes
straight from the machine:

```console
$ sudo sibilla model pull hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0
$ sudo sibilla connect --env > sibilla.env
$ set -a; . ./sibilla.env; set +a
$ python3 examples/rag-quickstart.py "What port does SibillaOS serve on?"
retrieved: SibillaOS serves an OpenAI-compatible API on port 8080, ...
answer:    SibillaOS serves its API on port 8080.
```

Swap `DOCS` for your corpus and it is a working pipeline; past a few
hundred chunks, add a vector store.

## Framework configurations

Both sketches assume the `sibilla connect --env` variables are set.

LangChain:

```python
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
import os

embeddings = OpenAIEmbeddings(
    model="hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0",
    # gotcha: without this, LangChain pre-tokenizes with OpenAI's
    # tiktoken, which does not match local models
    check_embedding_ctx_length=False,
)
llm = ChatOpenAI(model=os.environ["OPENAI_MODEL"])
```

LlamaIndex:

```python
from llama_index.embeddings.openai import OpenAIEmbedding
from llama_index.llms.openai_like import OpenAILike
import os

embed_model = OpenAIEmbedding(
    model_name="hf.co/nomic-ai/nomic-embed-text-v1.5-GGUF:Q8_0",
    api_base=os.environ["OPENAI_BASE_URL"],
    api_key=os.environ["OPENAI_API_KEY"],
)
llm = OpenAILike(
    model=os.environ["OPENAI_MODEL"],
    api_base=os.environ["OPENAI_BASE_URL"],
    api_key=os.environ["OPENAI_API_KEY"],
    is_chat_model=True,
)
```

Both read the base URL and key from the standard OpenAI environment
variables where noted; treat these as configuration sketches and pin
your framework versions as you would anything else.

Current catalog entry: nomic-embed-text v1.5 (Apache-2.0, 768
dimensions, 2048-token context, ~146 MB at Q8_0). Additions follow
the usual catalog criteria: permissive license, non-gated repository,
recorded digests.
