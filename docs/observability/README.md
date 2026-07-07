# Observability

SibillaOS exposes Prometheus metrics from the gateway, opt-in:

```console
$ sudo sibilla metrics enable
metrics enabled at /metrics/gateway (same API key as the API)
```

The endpoint lives on the gateway port, behind the same bearer token as
the API. It serves Caddy's HTTP metrics: request rate, latency
histograms, status codes, in-flight requests and upstream health, which
describe the API traffic whatever the engine underneath.

Engine-native metrics: with vLLM as the engine, its own Prometheus
metrics pass through the gateway at `/metrics` (same token). Ollama, at
the version pinned by this release (0.31.1), exposes no Prometheus
endpoint; this was verified against its source and will be revisited
when the pin moves.

## Prometheus scrape configuration

```yaml
scrape_configs:
  - job_name: sibillaos
    metrics_path: /metrics/gateway
    authorization:
      type: Bearer
      # copy /etc/llmd/apikey from the SibillaOS machine
      credentials_file: /etc/prometheus/sibilla-apikey
    static_configs:
      - targets: ["myserver.lan:8080"]
```

If the gateway runs in HTTPS mode with the local CA (`sibilla tls
enable HOSTNAME`), add:

```yaml
    scheme: https
    tls_config:
      # the CA certificate, from the SibillaOS machine:
      # /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
      ca_file: /etc/prometheus/sibilla-ca.crt
```

## Grafana

Import `grafana-dashboard.json` from this directory and point it at
your Prometheus datasource. The panels cover request rate, p95 latency,
error rate, in-flight requests and upstream health, all scoped to the
gateway's reverse proxy handler.

## Version note

The base system ships Caddy 2.6 (Ubuntu 24.04), where HTTP metrics are
always collected. Caddy 2.7 turned collection into an opt-in global
option; if a future base bump moves past 2.6, the renderer must start
emitting that option or the series will be empty.
