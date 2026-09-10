#!/usr/bin/env bash
# Omarchy / Arch installer for 2019 iMac built-in speakers (CS8409 + CS42L83).
#
# Stock Linux detects the card and PipeWire will happily "play" into it, but the
# Apple speaker amps are never initialized, so YouTube looks like it is playing
# with no sound. This wraps davidjo/snd_hda_macbookpro as a DKMS module.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/computeralex/omarchy-imac2019-audio/main/install.sh | bash
#   bash install.sh
#   bash install.sh --force          # skip the iMac 2019 hardware check
#   bash install.sh --uninstall
#
# After install: reboot. Keep volume low on first play — the patched path can
# be much louder than the silent stock driver.
set -euo pipefail

DRIVER_REPO="${DRIVER_REPO:-https://github.com/davidjo/snd_hda_macbookpro.git}"
SRC_DIR="${SRC_DIR:-$HOME/.local/src/snd_hda_macbookpro}"
DKMS_NAME="snd_hda_macbookpro"
DKMS_VER="0.1"
FORCE=0
UNINSTALL=0

need_root() {
  if (( EUID == 0 )); then
    "$@"
  elif command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
    sudo "$@"
  elif [[ -t 0 ]]; then
    sudo "$@"
  else
    pkexec "$@"
  fi
}

arch_pkg_to_kver() {
  # pacman: 7.1.9.arch1-2  -> uname: 7.1.9-arch1-2
  local ver="$1"
  ver="${ver#linux }"
  echo "${ver/.arch/-arch}"
}

is_imac2019() {
  local product
  product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
  case "$product" in
    iMac19,1|iMac19,2) return 0 ;;
  esac
  return 1
}

is_apple_cs8409() {
  local cards codec
  for cards in /proc/asound/card*/codec#*; do
    [[ -e "$cards" ]] || continue
    codec="$(head -20 "$cards" || true)"
    if grep -q 'Vendor Id: 0x10138409' <<<"$codec" && grep -qi 'Subsystem Id: 0x106b' <<<"$codec"; then
      return 0
    fi
  done
  return 1
}

usage() {
  sed -n '2,20p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    --uninstall|-r|--remove) UNINSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [[ "$(uname -s)" != Linux ]]; then
  echo "This installer is for Linux." >&2
  exit 1
fi
if ! command -v pacman >/dev/null; then
  echo "This installer currently targets Arch / Omarchy (pacman)." >&2
  exit 1
fi

if (( UNINSTALL )); then
  echo "Removing $DKMS_NAME DKMS module..."
  if dkms status 2>/dev/null | grep -q "$DKMS_NAME"; then
    need_root dkms remove -m "$DKMS_NAME/$DKMS_VER" --all || true
  fi
  need_root rm -f "/usr/src/${DKMS_NAME}-${DKMS_VER}"
  echo "Removed. Reboot to reload the stock CS8409 module (speakers will go silent again)."
  exit 0
fi

if (( FORCE == 0 )); then
  if ! is_imac2019 && ! is_apple_cs8409; then
    echo "This does not look like a 2019 iMac with Apple CS8409 audio." >&2
    echo "DMI product: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)" >&2
    echo "Re-run with --force if you know this hardware needs the driver." >&2
    exit 1
  fi
fi

echo "Installing/upgrading linux, headers, and build tools..."
# --needed still upgrades linux if the repo is newer than the installed kernel.
# That is required: linux-headers often lands one point release ahead of the
# still-running kernel, and DKMS must build against the kernel you will reboot into.
need_root pacman -Sy --noconfirm --needed linux linux-headers wget dkms git gcc make patch

TARGET_KVER="$(arch_pkg_to_kver "$(pacman -Q linux | awk '{print $2}')")"
if [[ ! -d "/lib/modules/${TARGET_KVER}/build" ]]; then
  echo "Kernel headers for $TARGET_KVER are missing after install." >&2
  echo "Expected /lib/modules/${TARGET_KVER}/build" >&2
  exit 1
fi

echo "Target kernel for the module: $TARGET_KVER (running: $(uname -r))"

mkdir -p "$(dirname "$SRC_DIR")"
if [[ -d "$SRC_DIR/.git" ]]; then
  git -C "$SRC_DIR" fetch --depth 1 origin
  git -C "$SRC_DIR" reset --hard origin/HEAD
else
  git clone --depth 1 "$DRIVER_REPO" "$SRC_DIR"
fi

# DKMS otherwise runs `make` against `uname -r`, which is wrong when linux-headers
# is newer than the still-running kernel (common on Omarchy after pacman -Sy).
if grep -q '^MAKE="make"$' "$SRC_DIR/dkms.conf"; then
  sed -i 's/^MAKE="make"$/MAKE="make KERNELRELEASE=$kernelver"/' "$SRC_DIR/dkms.conf"
fi

need_root ln -sfn "$SRC_DIR" "/usr/src/${DKMS_NAME}-${DKMS_VER}"

echo "Building DKMS module $DKMS_NAME/$DKMS_VER for $TARGET_KVER..."
need_root dkms install -c "$SRC_DIR/dkms.conf" --force -m "$DKMS_NAME/$DKMS_VER" -k "$TARGET_KVER"

echo
echo "Installed:"
dkms status | grep "$DKMS_NAME" || true
find "/usr/lib/modules/${TARGET_KVER}" -name '*cs8409*' -print

echo
echo "Done. Reboot to load the Apple CS8409 speaker driver."
if [[ "$(uname -r)" != "$TARGET_KVER" ]]; then
  echo "This boot is still $(uname -r); after reboot you should land on $TARGET_KVER."
fi
echo
echo "First-boot notes:"
echo "  - Keep volume low. The patched amps can be loud."
echo "  - Headphones: jack sense is implemented; PipeWire should switch when you plug in."
echo "    If you plug in and immediately hit play, wait a couple of seconds."
echo "  - Suspend/resume audio is a known weak spot of this driver."
echo "  - Uninstall later with: bash $0 --uninstall"
