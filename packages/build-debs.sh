#!/usr/bin/env bash
# Builds the llmd-* .deb packages into packages/dist/
# Requires: dpkg-deb
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$DIR/dist"
VERSION="${LLMD_VERSION:-0.2.0}"
LLMFIT_VERSION="0.9.36"
mkdir -p "$DIST"

# Target architecture: native by default (the arm64 CI jobs run on
# arm64 runners), overridable for local cross-builds. Only llmfit is
# architecture-specific; every other package is Architecture: all.
DEB_ARCH="${SIBILLA_DEB_ARCH:-$(dpkg --print-architecture)}"
case "$DEB_ARCH" in
  amd64) LLMFIT_TRIPLE="x86_64-unknown-linux-musl" ;;
  arm64) LLMFIT_TRIPLE="aarch64-unknown-linux-musl" ;;
  *) echo "unsupported architecture: $DEB_ARCH" >&2; exit 1 ;;
esac

build_pkg() {
  local name="$1" desc="$2" deps="$3"
  local staging
  staging=$(mktemp -d)
  cp -a "$DIR/$name/." "$staging/"
  mkdir -p "$staging/DEBIAN"
  cat > "$staging/DEBIAN/control" <<EOF
Package: $name
Version: $VERSION
Section: admin
Priority: optional
Architecture: all
Depends: $deps
Maintainer: SibillaOS contributors
Description: $desc
EOF
  # executable bit for the scripts (update-motd.d scripts must be
  # executable or pam_motd silently skips them)
  find "$staging/usr/lib/llmd" "$staging/usr/bin" "$staging/etc/update-motd.d" \
    -type f -exec chmod 755 {} + 2>/dev/null || true
  # a local py_compile (the lint job runs one) must never ship
  find "$staging" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
  # the curated model catalog ships with llmd-hw, with its detached
  # signature when the maintainer has signed it; if both the project
  # key and the signature exist, the build refuses a catalog that
  # does not verify
  if [[ "$name" == "llmd-hw" ]]; then
    install -D -m644 "$DIR/../catalog/models.json" "$staging/usr/share/llmd/models.json"
    if [[ -f "$DIR/../catalog/models.json.asc" ]]; then
      if [[ -f "$DIR/../apt/sibillaos-archive-key.asc" ]]; then
        local kr
        kr=$(mktemp)
        # --batch --yes: mktemp pre-creates the file and gpg would
        # otherwise ask for overwrite confirmation on /dev/tty
        gpg --batch --yes --dearmor -o "$kr" < "$DIR/../apt/sibillaos-archive-key.asc"
        gpgv --keyring "$kr" "$DIR/../catalog/models.json.asc" "$DIR/../catalog/models.json" \
          || { echo "catalog signature does not verify, refusing to build" >&2; exit 1; }
        rm -f "$kr"
      fi
      install -D -m644 "$DIR/../catalog/models.json.asc" "$staging/usr/share/llmd/models.json.asc"
    fi
  fi
  # APT repo trust: once the project public key is committed, llmd-hw
  # ships the keyring and the sources entry, so installed systems get
  # llmd updates through plain apt
  if [[ "$name" == "llmd-hw" && -f "$DIR/../apt/sibillaos-archive-key.asc" ]]; then
    mkdir -p "$staging/usr/share/keyrings" "$staging/etc/apt/sources.list.d"
    gpg --batch --yes --dearmor -o "$staging/usr/share/keyrings/sibillaos-archive-keyring.gpg" \
      < "$DIR/../apt/sibillaos-archive-key.asc"
    # shipped DISABLED: the repository goes live with the first tagged
    # release, and an unreachable source would fail the installer's
    # final apt-get update; llmd-firstboot enables it after checking
    # that the repository answers
    cat > "$staging/etc/apt/sources.list.d/sibillaos.sources" <<'SRC'
Types: deb
URIs: https://engineering87.github.io/sibillaos/apt/
Suites: ./
Signed-By: /usr/share/keyrings/sibillaos-archive-keyring.gpg
Enabled: no
SRC
  fi
  # the hardened ollama unit lists this path in ReadWritePaths: it must
  # exist at unit start or systemd fails the namespace and ollama
  # crash-loops until firstboot creates it
  if [[ "$name" == "llmd-engine-ollama" ]]; then
    mkdir -p "$staging/var/lib/llmd/models/ollama"
  fi
  dpkg-deb --build --root-owner-group "$staging" "$DIST/${name}_${VERSION}_all.deb"
  rm -rf "$staging"
  echo "OK $name"
}

# curl is a real runtime dependency (llmd-firstboot waits on the engine
# API, sibilla-status probes the gateway); it was inherited from the
# base images so far, but a dependency that works by luck is a bug
build_pkg llmd-hw            "Hardware detection and engine selection for SibillaOS" "pciutils, jq, curl"
build_pkg llmd-engine-ollama "Hardened systemd drop-in for Ollama"                    "systemd"
build_pkg llmd-engine-vllm   "vLLM OCI container (podman Quadlet)"                    "podman (>= 4.4)"
build_pkg llmd-gateway       "Unified OpenAI-compatible gateway (Caddy)"              "caddy"
build_pkg llmd-firstboot     "First boot model download and service setup"            "llmd-hw, jq, curl"
build_pkg llmd-webui         "Open WebUI chat interface (opt-in container)"           "podman (>= 4.4)"
build_pkg llmd-mcp           "Model Context Protocol server (opt-in, sibilla mcp)"    "python3, llmd-gateway"

# llmfit is repackaged from the pinned upstream release so the ISO does
# not depend on external installers at install time; the tarball is
# verified against the sha256 file published with the release
build_llmfit() {
  local staging asset base
  base="https://github.com/AlexsJones/llmfit/releases/download/v$LLMFIT_VERSION"
  asset="llmfit-v$LLMFIT_VERSION-$LLMFIT_TRIPLE.tar.gz"
  if [[ ! -f "$DIST/$asset" ]]; then
    curl -fL --retry 3 -o "$DIST/$asset" "$base/$asset"
    curl -fL --retry 3 -o "$DIST/$asset.sha256" "$base/$asset.sha256"
  fi
  (cd "$DIST" && sha256sum -c "$asset.sha256")
  staging=$(mktemp -d)
  mkdir -p "$staging/usr/bin" "$staging/DEBIAN" "$staging/tmp-extract"
  tar -xzf "$DIST/$asset" -C "$staging/tmp-extract"
  install -m755 "$(find "$staging/tmp-extract" -type f -name llmfit | head -1)" \
    "$staging/usr/bin/llmfit"
  rm -rf "$staging/tmp-extract"
  cat > "$staging/DEBIAN/control" <<EOF
Package: llmd-llmfit
Version: $LLMFIT_VERSION
Section: admin
Priority: optional
Architecture: $DEB_ARCH
Maintainer: SibillaOS contributors
Description: llmfit model recommender (repackaged upstream MIT binary)
EOF
  dpkg-deb --build --root-owner-group "$staging" "$DIST/llmd-llmfit_${LLMFIT_VERSION}_${DEB_ARCH}.deb"
  rm -rf "$staging"
  echo "OK llmd-llmfit ($DEB_ARCH)"
}
build_llmfit

# llmd: metapackage so "apt install llmd" pulls the whole stack onto an
# existing Ubuntu; `sibilla setup` then turns it into an appliance
build_meta() {
  local staging
  staging=$(mktemp -d)
  mkdir -p "$staging/DEBIAN"
  cat > "$staging/DEBIAN/control" <<EOF
Package: llmd
Version: $VERSION
Section: admin
Priority: optional
Architecture: all
Depends: llmd-hw, llmd-engine-ollama, llmd-engine-vllm, llmd-gateway, llmd-firstboot, llmd-webui, llmd-mcp, llmd-llmfit
Maintainer: SibillaOS contributors
Description: SibillaOS LLM stack (metapackage)
 Pulls the SibillaOS components onto an existing Ubuntu system. After
 installing, run 'sudo sibilla setup' to detect the hardware, install
 the inference engine and serve an OpenAI-compatible API.
EOF
  dpkg-deb --build --root-owner-group "$staging" "$DIST/llmd_${VERSION}_all.deb"
  rm -rf "$staging"
  echo "OK llmd (metapackage)"
}
build_meta

echo "packages in $DIST"
