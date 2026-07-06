#!/usr/bin/env bash
# Builds the llmd-* .deb packages into packages/dist/
# Requires: dpkg-deb
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$DIR/dist"
VERSION="${LLMD_VERSION:-0.2.0}"
LLMFIT_VERSION="0.9.36"
mkdir -p "$DIST"

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
  # executable bit for the scripts
  find "$staging/usr/lib/llmd" "$staging/usr/bin" -type f -exec chmod 755 {} + 2>/dev/null || true
  # the curated model catalog ships with llmd-hw
  if [[ "$name" == "llmd-hw" ]]; then
    install -D -m644 "$DIR/../catalog/models.json" "$staging/usr/share/llmd/models.json"
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

build_pkg llmd-hw            "Hardware detection and engine selection for SibillaOS" "pciutils, jq"
build_pkg llmd-engine-ollama "Hardened systemd drop-in for Ollama"                    "systemd"
build_pkg llmd-engine-vllm   "vLLM OCI container (podman Quadlet)"                    "podman (>= 4.4)"
build_pkg llmd-gateway       "Unified OpenAI-compatible gateway (Caddy)"              "caddy"
build_pkg llmd-firstboot     "First boot model download and service setup"            "llmd-hw, jq"
build_pkg llmd-webui         "Open WebUI chat interface (opt-in container)"           "podman (>= 4.4)"

# llmfit is repackaged from the pinned upstream release so the ISO does
# not depend on external installers at install time
build_llmfit() {
  local staging tgz
  staging=$(mktemp -d)
  tgz="$DIST/.llmfit-v$LLMFIT_VERSION.tgz"
  if [[ ! -f "$tgz" ]]; then
    curl -fL --retry 3 -o "$tgz" \
      "https://github.com/AlexsJones/llmfit/releases/download/v$LLMFIT_VERSION/llmfit-v$LLMFIT_VERSION-x86_64-unknown-linux-musl.tar.gz"
  fi
  mkdir -p "$staging/usr/bin" "$staging/DEBIAN" "$staging/tmp-extract"
  tar -xzf "$tgz" -C "$staging/tmp-extract"
  install -m755 "$(find "$staging/tmp-extract" -type f -name llmfit | head -1)" \
    "$staging/usr/bin/llmfit"
  rm -rf "$staging/tmp-extract"
  cat > "$staging/DEBIAN/control" <<EOF
Package: llmd-llmfit
Version: $LLMFIT_VERSION
Section: admin
Priority: optional
Architecture: amd64
Maintainer: SibillaOS contributors
Description: llmfit model recommender (repackaged upstream MIT binary)
EOF
  dpkg-deb --build --root-owner-group "$staging" "$DIST/llmd-llmfit_${LLMFIT_VERSION}_amd64.deb"
  rm -rf "$staging"
  echo "OK llmd-llmfit"
}
build_llmfit

# The curated catalog ships with llmd-hw
echo "packages in $DIST"
