#!/usr/bin/env bash
# SibillaOS ISO builder (proof of concept)
# Builds an installable ISO based on Ubuntu 24.04 (noble) with autoinstall.
# Requires: debootstrap squashfs-tools xorriso mtools wget gpg (run as root)
set -euo pipefail

RELEASE="noble"
VERSION="${SIBILLA_VERSION:-0.1.0}"
ARCH="amd64"
MIRROR="${SIBILLA_MIRROR:-http://archive.ubuntu.com/ubuntu}"
WORK="$(pwd)/work"
OUT="$(pwd)/out"
CHROOT="$WORK/chroot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

log() { echo "[sibilla] $*"; }

# 1. Base system
bootstrap() {
  log "debootstrap $RELEASE into $CHROOT"
  mkdir -p "$CHROOT" "$OUT"
  debootstrap --arch="$ARCH" --components=main,restricted,universe \
    "$RELEASE" "$CHROOT" "$MIRROR"
}

# 2. Packages inside the live squashfs
customize() {
  log "installing packages in the chroot"
  cat > "$CHROOT/etc/apt/sources.list" <<EOF
deb $MIRROR $RELEASE main restricted universe
deb $MIRROR $RELEASE-updates main restricted universe
deb $MIRROR $RELEASE-security main restricted universe
EOF
  chroot "$CHROOT" apt-get update
  DEBIAN_FRONTEND=noninteractive chroot "$CHROOT" apt-get install -y \
    linux-generic casper ubuntu-standard \
    network-manager curl jq gpg pciutils \
    subiquity 2>/dev/null || \
  DEBIAN_FRONTEND=noninteractive chroot "$CHROOT" apt-get install -y \
    linux-generic casper ubuntu-standard network-manager curl jq gpg pciutils

  # llmd-* packages (built locally, see packages/)
  log "installing llmd-* packages"
  for deb in "$SCRIPT_DIR"/../packages/dist/*.deb; do
    [[ -e "$deb" ]] || { log "WARNING: no .deb in packages/dist (run packages/build-debs.sh)"; break; }
    cp "$deb" "$CHROOT/tmp/" && chroot "$CHROOT" dpkg -i "/tmp/$(basename "$deb")" || \
      chroot "$CHROOT" apt-get -f install -y
  done

  # Ollama (official script, inside the chroot)
  chroot "$CHROOT" bash -c 'curl -fsSL https://ollama.com/install.sh | sh'

  # llmfit (release binary; will be repackaged as a .deb for the MVP)
  chroot "$CHROOT" bash -c 'curl -fsSL https://llmfit.axjns.dev/install.sh | sh'

  # Branding
  install -D -m644 "$SCRIPT_DIR/../branding/wallpaper.png" \
    "$CHROOT/usr/share/backgrounds/sibillaos/wallpaper.png" 2>/dev/null || true
}

# 3. squashfs + ISO layout
build_iso() {
  log "creating squashfs"
  mkdir -p "$WORK/iso/casper" "$WORK/iso/nocloud"
  mksquashfs "$CHROOT" "$WORK/iso/casper/filesystem.squashfs" -noappend -comp xz

  cp "$CHROOT"/boot/vmlinuz-* "$WORK/iso/casper/vmlinuz"
  cp "$CHROOT"/boot/initrd.img-* "$WORK/iso/casper/initrd"

  # Autoinstall (NoCloud datasource)
  cp "$SCRIPT_DIR/autoinstall/user-data" "$SCRIPT_DIR/autoinstall/meta-data" "$WORK/iso/nocloud/"

  log "generating ISO"
  xorriso -as mkisofs -r -V "SibillaOS $VERSION" \
    -o "$OUT/sibillaos-$VERSION-$ARCH.iso" \
    -J -l -iso-level 3 \
    "$WORK/iso"
  log "ISO ready: $OUT/sibillaos-$VERSION-$ARCH.iso"
}

bootstrap
customize
build_iso
