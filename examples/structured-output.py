#!/usr/bin/env python3
"""Structured outputs through the SibillaOS gateway, stdlib only.

Environment comes straight from the machine:

    eval "$(sudo sibilla connect --env)"
    python3 examples/structured-output.py

The request forces a JSON-schema-shaped answer via the standard
OpenAI response_format parameter; both engines enforce it at
generation time. Exit codes: 0 schema-shaped answer, 3 engine failure
(named), 1 anything that is our own fault.
"""

import json
import os
import sys
import urllib.request

BASE = os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8080/v1")
KEY = os.environ.get("OPENAI_API_KEY", "")
MODEL = os.environ.get("OPENAI_MODEL", "")

SCHEMA = {
    "name": "weather_report",
    "schema": {
        "type": "object",
        "properties": {
            "city": {"type": "string"},
            "condition": {"type": "string"},
            "temperature_c": {"type": "number"},
        },
        "required": ["city", "condition"],
    },
}

body = {
    "model": MODEL,
    "messages": [
        {
            "role": "user",
            "content": "Invent a plausible weather report for Rome.",
        }
    ],
    "response_format": {"type": "json_schema", "json_schema": SCHEMA},
    "max_tokens": 1500,
}

req = urllib.request.Request(
    f"{BASE}/chat/completions",
    data=json.dumps(body).encode(),
    headers={
        "Authorization": f"Bearer {KEY}",
        "Content-Type": "application/json",
    },
)

try:
    with urllib.request.urlopen(req, timeout=300) as r:
        answer = json.load(r)
except urllib.error.HTTPError as e:
    # 5xx is the engine struggling, not our plumbing: name it
    print(f"engine answered {e.code}: {e.read()[:200]!r}", file=sys.stderr)
    sys.exit(3 if e.code >= 500 else 1)

content = answer["choices"][0]["message"]["content"]
print(content)

parsed = json.loads(content)  # a non-JSON answer fails loudly here
for field in SCHEMA["schema"]["required"]:
    if field not in parsed:
        print(f"missing required field: {field}", file=sys.stderr)
        sys.exit(1)

print("schema-shaped answer verified", file=sys.stderr)
