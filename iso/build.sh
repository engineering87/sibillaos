#!/usr/bin/env bash
# SibillaOS ISO builder (proof of concept)
# Builds a BIOS+UEFI bootable ISO based on Ubuntu 24.04 (noble) with autoinstall.
# Requires: debootstrap squashfs-tools xorriso mtools dosfstools
#           grub-pc-bin grub-efi-amd64-bin grub-common (run as root)
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
    cp "$deb" "$CHROOT/tmp/"
    if ! chroot "$CHROOT" dpkg -i "/tmp/$(basename "$deb")"; then
      chroot "$CHROOT" apt-get -f install -y
    fi
  done

  # Ollama (official script, inside the chroot)
  chroot "$CHROOT" bash -c 'curl -fsSL https://ollama.com/install.sh | sh'

  # llmfit (release binary; will be repackaged as a .deb for the MVP)
  chroot "$CHROOT" bash -c 'curl -fsSL https://llmfit.axjns.dev/install.sh | sh'

  # Branding
  install -D -m644 "$SCRIPT_DIR/../branding/wallpaper.png" \
    "$CHROOT/usr/share/backgrounds/sibillaos/wallpaper.png" 2>/dev/null || true
}

# 3. Bootloader: GRUB images for UEFI and BIOS, hybrid layout
build_boot() {
  log "building GRUB boot images"
  mkdir -p "$WORK/iso/boot/grub" "$WORK/iso/.disk"
  echo "SibillaOS $VERSION" > "$WORK/iso/.disk/info"

  # boot menu
  cat > "$WORK/iso/boot/grub/grub.cfg" <<'GRUBCFG'
set default=0
set timeout=5

# mirror the menu to a serial console when one exists (also used by CI)
if serial --unit=0 --speed=115200; then
  terminal_input --append serial
  terminal_output --append serial
fi

menuentry "Install SibillaOS (automated)" {
    echo "Loading SibillaOS kernel..."
    linux /casper/vmlinuz boot=casper autoinstall ds=nocloud\;s=/cdrom/nocloud/ console=tty0 console=ttyS0,115200n8 ---
    initrd /casper/initrd
}

menuentry "Try SibillaOS (live)" {
    echo "Loading SibillaOS kernel..."
    linux /casper/vmlinuz boot=casper quiet ---
    initrd /casper/initrd
}
GRUBCFG

  # embedded config: locate the ISO root by marker file, then load the menu
  cat > "$WORK/embedded.cfg" <<'EMBCFG'
search --set=root --file /.disk/info
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
EMBCFG

  # UEFI: standalone GRUB inside a FAT image (appended as a GPT partition)
  grub-mkstandalone --format=x86_64-efi \
    --output="$WORK/bootx64.efi" \
    --locales="" --fonts="" \
    "boot/grub/grub.cfg=$WORK/embedded.cfg"
  dd if=/dev/zero of="$WORK/efiboot.img" bs=1M count=8
  mkfs.vfat "$WORK/efiboot.img"
  mmd -i "$WORK/efiboot.img" ::/EFI ::/EFI/BOOT
  mcopy -i "$WORK/efiboot.img" "$WORK/bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI

  # BIOS: core image plus El Torito boot image.
  # No module restrictions: the embedded config needs search_fs_file and
  # the menu uses serial/echo; restricting the list broke the boot.
  grub-mkstandalone --format=i386-pc \
    --output="$WORK/core.img" \
    --locales="" --fonts="" \
    "boot/grub/grub.cfg=$WORK/embedded.cfg"
  cat /usr/lib/grub/i386-pc/cdboot.img "$WORK/core.img" \
    > "$WORK/iso/boot/grub/bios.img"
}

# 4. squashfs + hybrid ISO
build_iso() {
  log "creating squashfs"
  mkdir -p "$WORK/iso/casper" "$WORK/iso/nocloud"
  mksquashfs "$CHROOT" "$WORK/iso/casper/filesystem.squashfs" -noappend -comp xz

  cp "$CHROOT"/boot/vmlinuz-* "$WORK/iso/casper/vmlinuz"
  cp "$CHROOT"/boot/initrd.img-* "$WORK/iso/casper/initrd"

  # Autoinstall (NoCloud datasource)
  cp "$SCRIPT_DIR/autoinstall/user-data" "$SCRIPT_DIR/autoinstall/meta-data" "$WORK/iso/nocloud/"

  log "generating hybrid ISO (BIOS + UEFI)"
  xorriso -as mkisofs -r -V "SibillaOS $VERSION" \
    -o "$OUT/sibillaos-$VERSION-$ARCH.iso" \
    -J -joliet-long -l -iso-level 3 \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -partition_offset 16 \
    --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$WORK/efiboot.img" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c /boot.catalog \
    -b /boot/grub/bios.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    "$WORK/iso"
  log "ISO ready: $OUT/sibillaos-$VERSION-$ARCH.iso"
}

bootstrap
customize
build_boot
build_iso
