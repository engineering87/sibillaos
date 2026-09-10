# OIDC login for the WebUI

`sudo sibilla oidc enable` puts the chat interface behind your
organization's identity provider. Browsers hitting port 3000 are sent
to the provider's login; API clients are untouched and keep their
bearer keys, because the boundary between human and machine access
should be a clean one.

The appliance bundles no identity provider: the provider is yours
(Microsoft Entra, Keycloak, Google Workspace, any OIDC-compliant
issuer). In between sits oauth2-proxy, repackaged from its pinned
upstream release and verified against the checksums upstream
publishes, running sandboxed on loopback like every other SibillaOS
component.

## Setup

Register an application at your provider with this redirect URI:

```
http://YOUR_HOST:3000/oauth2/callback
```

Then, on the machine:

```console
$ sudo sibilla oidc enable https://login.example.com/realms/team my-client-id
client secret (not echoed): ****
OIDC enabled: browsers on http://YOUR_HOST:3000 authenticate against https://login.example.com/realms/team
```

The client secret is read from the terminal (or from stdin in
automation), never from arguments: arguments land in shell history and
process listings. Configuration lives in /etc/llmd/oidc.env, root-only.

`sudo sibilla oidc disable` returns the WebUI to its own login.

## How it fits

Since v0.9 the WebUI container itself listens on loopback only and the
gateway fronts it on port 3000 in every configuration. With OIDC off,
requests pass straight through and nothing changes for the user. With
OIDC on, oauth2-proxy sits in the middle in proxy mode: unauthenticated
browsers are redirected to the provider, authenticated sessions ride a
signed cookie. Port 3000 stays closed by the firewall on appliance
installs until you open it deliberately, exactly as before.

## Limits stated plainly

This protects the WebUI, not the API: /v1/* on port 8080 answers to
bearer keys, with or without OIDC. The secret and the cookie key are
per-machine and never enter declarative profiles (`sibilla apply`
manages neither; the toggles it owns are listed in
docs/configuration.md). Port 3000 speaks plain HTTP: on a network you
do not trust end to end, put the gateway in TLS mode and keep the
WebUI on localhost or a trusted segment - HTTPS for the WebUI listener
is tracked for a later cycle.
