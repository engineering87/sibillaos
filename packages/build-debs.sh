#!/usr/bin/env bash
# Builds the llmd-* .deb packages into packages/dist/
# Requires: dpkg-deb
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$DIR/dist"
VERSION="${LLMD_VERSION:-0.1.0}"
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
  find "$staging/usr/lib/llmd" -type f -exec chmod 755 {} + 2>/dev/null || true
  # the curated model catalog ships with llmd-hw
  if [[ "$name" == "llmd-hw" ]]; then
    install -D -m644 "$DIR/../catalog/models.json" "$staging/usr/share/llmd/models.json"
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

# The curated catalog ships with llmd-hw
echo "packages in $DIST"
