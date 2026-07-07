#!/usr/bin/env bash
# SibillaOS cloud image builder
# Bakes the official Ubuntu 24.04 cloud image into a SibillaOS qcow2:
# boots the image once under QEMU with a NoCloud seed that installs the
# llmd packages and the pinned engine, then reseals cloud-init so the
# deployer's own user-data applies at the real first boot. Engine and
# model selection happen on the deployed machine (llmd-firstboot runs
# the hardware detection when the installer did not).
# Builds for the native architecture (amd64 or arm64) by default.
# Requires: qemu-system qemu-img xorriso curl (no root needed); on
# arm64 also qemu-efi-aarch64 for the AAVMF UEFI firmware.
set -euo pipefail

VERSION="${SIBILLA_VERSION:-0.1.0}"
ARCH="${SIBILLA_ARCH:-$(dpkg --print-architecture)}"
UBUNTU_SERIES="noble"
MIRROR="${SIBILLA_CLOUDIMG_MIRROR:-https://cloud-images.ubuntu.com/${UBUNTU_SERIES}/current}"
IMG_NAME="${UBUNTU_SERIES}-server-cloudimg-${ARCH}.img"
DISK_SIZE="${SIBILLA_CLOUD_DISK:-10G}"
WORK="$(pwd)/work-cloud"
OUT="$(pwd)/out"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Architecture-specific QEMU setup. Without KVM (GitHub's arm64
# runners have none) TCG emulation is used: slower, hence the wider
# bake timeout.
BAKE_TIMEOUT=1800
case "$ARCH" in
  amd64)
    QEMU_BIN=qemu-system-x86_64
    QEMU_ARGS=(-m 2048 -smp 2)
    if [[ -w /dev/kvm ]]; then
      QEMU_ARGS+=(-enable-kvm -cpu host)
    fi
    ;;
  arm64)
    QEMU_BIN=qemu-system-aarch64
    QEMU_ARGS=(-machine virt -m 2048 -smp 4)
    if [[ -w /dev/kvm ]]; then
      QEMU_ARGS+=(-enable-kvm -cpu host)
    else
      QEMU_ARGS+=(-cpu max)
      BAKE_TIMEOUT=5400
    fi
    QEMU_ARGS+=(-bios /usr/share/AAVMF/AAVMF_CODE.fd)
    ;;
  *) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

log() { echo "[sibilla-cloud] $*"; }
mkdir -p "$WORK" "$OUT"

# 1. Fetch the current cloud image, verified by checksum
fetch_image() {
  log "resolving the current ${UBUNTU_SERIES} $ARCH cloud image"
  curl -fsSL "$MIRROR/SHA256SUMS" -o "$WORK/SHA256SUMS"
  if [[ ! -f "$WORK/$IMG_NAME" ]]; then
    curl -fL --retry 3 -o "$WORK/$IMG_NAME" "$MIRROR/$IMG_NAME"
  fi
  if ! (cd "$WORK" && grep "$IMG_NAME" SHA256SUMS | sha256sum -c -); then
    log "checksum mismatch (stale cache?), downloading again"
    rm -f "$WORK/$IMG_NAME"
    curl -fL --retry 3 -o "$WORK/$IMG_NAME" "$MIRROR/$IMG_NAME"
    (cd "$WORK" && grep "$IMG_NAME" SHA256SUMS | sha256sum -c -)
  fi
}

# 2. Seed: bake-phase cloud-init config plus the llmd debs
prepare_seed() {
  log "preparing bake seed"
  rm -rf "$WORK/seed"
  mkdir -p "$WORK/seed/debs"
  cp "$SCRIPT_DIR/bake/user-data" "$SCRIPT_DIR/bake/meta-data" "$WORK/seed/"
  cp "$SCRIPT_DIR"/../packages/dist/*.deb "$WORK/seed/debs/"
  if [[ -n "${SIBILLA_TEST_MODEL:-}" ]]; then
    echo "$SIBILLA_TEST_MODEL" > "$WORK/seed/ci-model"
    log "CI build: test model $SIBILLA_TEST_MODEL"
  fi
  xorriso -as mkisofs -volid CIDATA -joliet -rock \
    -o "$WORK/seed.iso" "$WORK/seed" >/dev/null 2>&1
}

# 3. Bake: one boot against the seed, QEMU exits at the final poweroff
bake() {
  local disk="$WORK/sibillaos-cloud.qcow2"
  rm -f "$disk" "$WORK/bake.log"
  qemu-img create -f qcow2 -b "$WORK/$IMG_NAME" -F qcow2 "$disk" "$DISK_SIZE" >/dev/null
  log "baking with $QEMU_BIN (single boot, log in work-cloud/bake.log)"
  timeout "$BAKE_TIMEOUT" "$QEMU_BIN" "${QEMU_ARGS[@]}" \
    -display none -serial "file:$WORK/bake.log" \
    -drive "file=$disk,format=qcow2,if=virtio" \
    -drive "file=$WORK/seed.iso,format=raw,if=virtio,readonly=on" \
    -netdev user,id=n0 -device virtio-net,netdev=n0 \
    -no-reboot
  if grep -q "SIBILLA_BAKE_FAILED" "$WORK/bake.log"; then
    echo "bake failed; output before the failure marker (systemd noise filtered):" >&2
    grep -B 80 "SIBILLA_BAKE_FAILED" "$WORK/bake.log" \
      | grep -vE '^\[ +OK|^ +(Stopping|Starting|Unmounting|Mounting)' \
      | tail -60 >&2
    exit 1
  fi
  if ! grep -q "SIBILLA_BAKE_OK" "$WORK/bake.log"; then
    echo "bake did not complete (no marker); log tail:" >&2
    tail -80 "$WORK/bake.log" >&2
    exit 1
  fi
}

# 4. Flatten and compress into the release artifact
finalize() {
  local out_img="$OUT/sibillaos-$VERSION-cloud-$ARCH.qcow2"
  rm -f "$out_img"
  log "compressing into $out_img"
  qemu-img convert -c -O qcow2 "$WORK/sibillaos-cloud.qcow2" "$out_img"
  log "cloud image ready: $out_img"
}

fetch_image
prepare_seed
bake
finalize
