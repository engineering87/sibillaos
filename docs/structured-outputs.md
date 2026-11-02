# Structured outputs

Both engines behind the gateway can be forced to answer in a shape
your code can parse, instead of prose you have to fish JSON out of.
The interface is the OpenAI `response_format` parameter with a JSON
schema, sent through the same authenticated endpoint as everything
else; nothing SibillaOS-specific is involved, which is the point - any
OpenAI SDK does this out of the box, aimed at this machine via
`sibilla connect --env`.

## The request shape

```json
{
  "model": "...",
  "messages": [{"role": "user", "content": "Extract the invoice data."}],
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "invoice",
      "schema": {
        "type": "object",
        "properties": {
          "total": {"type": "number"},
          "currency": {"type": "string"},
          "due_date": {"type": "string"}
        },
        "required": ["total", "currency"]
      }
    }
  }
}
```

With the Ollama engine, constrained decoding enforces the schema at
generation time (the model cannot emit tokens that violate it). With
the vLLM engine, the pinned v0.32 ships the stable structured-outputs
machinery (xgrammar) on by default in the OpenAI server, superseding
the old guided_* fields. Either way the gateway passes the parameter
through untouched.

## A worked example

`examples/structured-output.py` is a complete zero-dependency run:
environment from `sibilla connect --env`, one request, schema-shaped
answer parsed with plain `json.loads`. CI runs it on every push with
the usual policy: a failure of our plumbing is red, an engine
weakness on the runner's CPU is named and tolerated.

## Honest limits

A schema constrains syntax, not sense: the model can still put the
wrong number in `total`. Keep schemas small; a sprawling schema costs
tokens and correctness. And prefer `required` fields sparingly - a
model forced to invent a value it does not know will invent it.
