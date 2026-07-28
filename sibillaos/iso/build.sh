#!/usr/bin/env bash
# SibillaOS ISO builder
# Repacks the official Ubuntu 24.04 live-server ISO with the SibillaOS
# autoinstall, llmd packages, model catalog and branding. The official
# installer stack (subiquity, cloud-init, casper) is reused as is.
# Requires: xorriso curl (no root needed)
set -euo pipefail

VERSION="${SIBILLA_VERSION:-0.1.0}"
ARCH="amd64"
UBUNTU_SERIES="24.04"
MIRROR="${SIBILLA_UBUNTU_MIRROR:-https://releases.ubuntu.com/${UBUNTU_SERIES}}"
WORK="$(pwd)/work"
OUT="$(pwd)/out"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[sibilla] $*"; }
mkdir -p "$WORK" "$OUT"

# 1. Fetch the current point-release live-server ISO, verified by checksum
fetch_iso() {
  log "resolving the current ${UBUNTU_SERIES} live-server ISO"
  curl -fsSL "$MIRROR/SHA256SUMS" -o "$WORK/SHA256SUMS"
  ISO_NAME=$(awk '/live-server-amd64.iso/ {print $2}' "$WORK/SHA256SUMS" | tr -d '*' | head -1)
  [[ -n "$ISO_NAME" ]] || { echo "live-server ISO not found in SHA256SUMS" >&2; exit 1; }
  log "source ISO: $ISO_NAME"
  if [[ ! -f "$WORK/$ISO_NAME" ]]; then
    curl -fL --retry 3 -o "$WORK/$ISO_NAME" "$MIRROR/$ISO_NAME"
  fi
  if ! (cd "$WORK" && grep "$ISO_NAME" SHA256SUMS | sha256sum -c -); then
    log "checksum mismatch (stale cache?), downloading again"
    rm -f "$WORK/$ISO_NAME"
    curl -fL --retry 3 -o "$WORK/$ISO_NAME" "$MIRROR/$ISO_NAME"
    (cd "$WORK" && grep "$ISO_NAME" SHA256SUMS | sha256sum -c -)
  fi
  SRC_ISO="$WORK/$ISO_NAME"
}

# 2. Payload: autoinstall seed, llmd debs, catalog, branding, boot menu
prepare_payload() {
  log "preparing payload"
  rm -rf "$WORK/nocloud" "$WORK/sibilla"
  mkdir -p "$WORK/nocloud" "$WORK/sibilla/debs"
  cp "$SCRIPT_DIR/autoinstall/user-data" "$SCRIPT_DIR/autoinstall/meta-data" "$WORK/nocloud/"
  cp "$SCRIPT_DIR"/../packages/dist/*.deb "$WORK/sibilla/debs/"
  cp "$SCRIPT_DIR"/../branding/wallpaper.png "$WORK/sibilla/" 2>/dev/null || true

  if [[ -n "${SIBILLA_TEST_MODEL:-}" ]]; then
    # CI build: fully unattended install, small model override
    echo "$SIBILLA_TEST_MODEL" > "$WORK/sibilla/ci-model"
    log "CI build: unattended install, test model $SIBILLA_TEST_MODEL"
  else
    # release build: the standard installer screens are interactive, so
    # the user picks locale, network, disk and their own credentials;
    # the llmd steps stay automated in the late-commands
    sed -i 's/^  version: 1$/  version: 1\n  interactive-sections: [locale, keyboard, network, storage, identity]/' \
      "$WORK/nocloud/user-data"
    log "release build: standard installer sections are interactive"
  fi

  # boot menu: replaces the stock grub.cfg on the ISO. The serial setup is
  # guarded so machines without a serial port fall through to VGA only.
  cat > "$WORK/grub.cfg" <<'GRUBCFG'
set timeout=5

# SibillaOS theme: emerald on black
set color_normal=light-green/black
set color_highlight=black/light-green
set menu_color_normal=light-green/black
set menu_color_highlight=black/light-green

if serial --unit=0 --speed=115200; then
  terminal_input --append serial
  terminal_output --append serial
fi

menuentry "Install SibillaOS (automated)" {
    echo "Loading SibillaOS kernel..."
    linux /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ console=tty0 console=ttyS0,115200n8 ---
    initrd /casper/initrd
}

menuentry "Ubuntu Server installer (interactive)" {
    linux /casper/vmlinuz ---
    initrd /casper/initrd
}
GRUBCFG
}

# 3. Repack: overlay our files onto the official ISO; xorriso replays the
# original boot setup (El Torito + hybrid MBR/GPT) unchanged
repack() {
  local out_iso="$OUT/sibillaos-$VERSION-$ARCH.iso"
  rm -f "$out_iso"
  log "repacking into $out_iso"
  xorriso -indev "$SRC_ISO" -outdev "$out_iso" \
    -boot_image any replay \
    -volid "SIBILLAOS" \
    -map "$WORK/nocloud" /nocloud \
    -map "$WORK/sibilla" /sibilla \
    -map "$WORK/grub.cfg" /boot/grub/grub.cfg
  log "ISO ready: $out_iso"
}

fetch_iso
prepare_payload
repack
