# Vision: which models see images, and why most do not

An OpenAI-compatible vision request works out of the box: send an
image in the standard `content` array and the gateway passes it to
the engine untouched.

```console
$ curl -s https://my-llm-server:8080/v1/chat/completions \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d '{
      "model": "qwen3.5:9b",
      "messages": [{"role": "user", "content": [
        {"type": "text", "text": "What is on this invoice?"},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}
      ]}]
    }'
```

What decides whether the model actually sees the image is where it
came from, and the catalog is explicit about it.

## The hf.co limit, stated honestly

A vision model is two files: the language model GGUF and a projector
(`mmproj`) that turns image patches into tokens the model reads.
ollama's `hf.co/...` pull fetches the model GGUF and nothing else, so
every hf.co catalog entry is text-only by construction, including the
Qwen3.5 defaults. Sending an image to one does not fail loudly; the
model simply never receives it. This is an upstream pull-path
limitation, not a SibillaOS choice, and it is why the catalog does
not pretend otherwise.

## Registry entries carry their eyes with them

The ollama.com registry ships the projector as a manifest layer next
to the model, digest-pinned like everything else, so registry-sourced
catalog entries are the ones that see. The catalog marks them with
`"capabilities": ["vision"]`:

- `qwen3.5:9b` (consumer-gpu): the additive vision option beside the
  text-only hf.co defaults, which stay the defaults
- `qwen3.5:122b` (large tier): RAM floor rules apply as usual, see
  [Large models](large-models.md)

Enable one deliberately:

```console
$ sudo sibilla model use qwen3.5:9b
```

The digest recorded in the catalog is the model layer's sha256 read
from the registry manifest, and `sibilla model use` verifies it
fail-closed before serving, exactly as on the hf path.

## The rule behind the exception

The catalog's source policy is hf.co-first (architecture changelog
v0.13 and the v0.17 amendment): a registry entry exists only where
the hf path cannot deliver, originally the large tier's sharded
GGUFs, now also a capability the entry states. Registry entries are
never defaults; first boot keeps serving what the machine honestly
runs, and seeing images stays an opt-in with its cost visible.
