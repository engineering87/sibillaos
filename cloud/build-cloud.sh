#!/usr/bin/env bash
# SibillaOS cloud image builder
# Bakes the official Ubuntu 24.04 cloud image into a SibillaOS qcow2:
# boots the image once under QEMU with a NoCloud seed that installs the
# llmd packages and the pinned engine, then reseals cloud-init so the
# deployer's own user-data applies at the real first boot. Engine and
# model selection happen on the deployed machine (llmd-firstboot runs
# the hardware detection when the installer did not).
# Requires: qemu-system-x86_64 qemu-img xorriso curl (no root needed)
set -euo pipefail

VERSION="${SIBILLA_VERSION:-0.1.0}"
ARCH="amd64"
UBUNTU_SERIES="noble"
MIRROR="${SIBILLA_CLOUDIMG_MIRROR:-https://cloud-images.ubuntu.com/${UBUNTU_SERIES}/current}"
IMG_NAME="${UBUNTU_SERIES}-server-cloudimg-${ARCH}.img"
DISK_SIZE="${SIBILLA_CLOUD_DISK:-10G}"
WORK="$(pwd)/work-cloud"
OUT="$(pwd)/out"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[sibilla-cloud] $*"; }
mkdir -p "$WORK" "$OUT"

# 1. Fetch the current cloud image, verified by checksum
fetch_image() {
  log "resolving the current ${UBUNTU_SERIES} cloud image"
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
  KVM=""
  if [[ -w /dev/kvm ]]; then KVM="-enable-kvm -cpu host"; fi
  log "baking (single boot with the install seed, log in work-cloud/bake.log)"
  # shellcheck disable=SC2086
  timeout 1800 qemu-system-x86_64 -m 2048 -smp 2 $KVM \
    -display none -serial "file:$WORK/bake.log" \
    -drive "file=$disk,format=qcow2,if=virtio" \
    -drive "file=$WORK/seed.iso,format=raw,if=virtio,readonly=on" \
    -netdev user,id=n0 -device virtio-net,netdev=n0 \
    -no-reboot
  if ! grep -q "SIBILLA_BAKE_OK" "$WORK/bake.log"; then
    echo "bake did not complete; log tail:" >&2
    tail -40 "$WORK/bake.log" >&2
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
