# Omarchy iMac 2019 speakers

Stock Linux on a 2019 iMac (`iMac19,1` / `iMac19,2`) shows a working analog
sink and will "play" YouTube with **no speaker sound**. The Cirrus CS8409
bridge is detected; the CS42L83 companion and speaker amps are not
initialized.

This installer wraps [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
as DKMS, including the Omarchy-specific fix of building against the kernel you
will reboot into (not `uname -r` if headers are newer).

Not an official Omarchy package. Proven on one `iMac19,2`.

## Install

On Omarchy / Arch:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/computeralex/omarchy-imac2019-audio/main/install.sh)
sudo reboot
```

Or clone and run:

```bash
git clone https://github.com/computeralex/omarchy-imac2019-audio.git
cd omarchy-imac2019-audio
bash install.sh
sudo reboot
```

Keep volume **low** on first play. The patched amps can be loud.

```bash
bash install.sh --uninstall   # back to stock (silent speakers)
bash install.sh --force       # skip the iMac 2019 hardware check
```

The script will ask for sudo or a graphical polkit prompt. It installs
`linux`, `linux-headers`, DKMS, and the patched CS8409 module for the kernel
you will reboot into.

## Headphones

The patched driver implements headphone plug/unplug via jack sense. PipeWire
should switch automatically. Wait a couple of seconds after plugging in before
starting playback; plug/unplug while already playing is the better-tested path.

Suspend/resume audio is a known weak spot of the upstream driver.

## After kernel updates

DKMS `AUTOINSTALL` should rebuild the module on `omarchy update` / `pacman -Syu`.
If speakers go silent again after an update, rerun `install.sh`.

## Hardware this was proven on

- iMac19,2 (21.5-inch 2019), CS8409 subsystem `106b:0f00`
- Omarchy, kernel 7.1.9-arch1-2

`--force` also allows other Apple CS8409 machines (`Vendor Id 0x10138409`,
subsystem `0x106b*`).

## Credits

- [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) — the actual codec/amp driver
- This repo is a thin Omarchy/Arch installer around that DKMS module, by Alex Mohr
