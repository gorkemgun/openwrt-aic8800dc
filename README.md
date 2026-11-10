# openwrt-aic8800dc

OpenWrt packages for **AIC8800DC / AIC8800DW** USB Wi-Fi adapters: the cheap 2.4 GHz "AX300" Wi-Fi 6
sticks sold by TP-Link, Tenda, Mercusys, UGREEN and others. OpenWrt has no driver for them.

The driver is [Kiborgik/aic8800dc-linux-patched](https://github.com/Kiborgik/aic8800dc-linux-patched)
at a pinned commit; see its README for the list of supported USB IDs. This repository only adds the
OpenWrt packaging, a mode-switch hotplug script and a few patches.

| Package | Contents |
|---|---|
| `kmod-aic8800dc-usb` | `aic_load_fw.ko`, `aic8800_fdrv.ko` |
| `aic8800dc-firmware` | firmware and per-vendor TX power tables in `/lib/firmware/aic8800DC` |
| `aic8800-usb-modeswitch` | switches the stick from its driver-CD mode to Wi-Fi mode when plugged in |

## Status

Tested on one setup: **TP-Link AX300 (`3625:0110`), x86-64, OpenWrt 25.12.6**.

- Works: client mode (WPA2, HE), AP mode (WPA2), AP and client at the same time on the one radio,
  automatic mode switch at boot and on hotplug, signal / bitrate / station list in LuCI.
- Known gaps: TX power shows as 0 dBm; in AP mode the clients' signal shows as 0 dBm.
- Not tested: other adapters, other targets (CI only checks that they build), mesh, P2P, monitor
  mode, WPA3, long-term stability.
- **OpenWrt 24.10 packages are build-tested only.** They compile, but nobody has loaded them on a
  router yet. Reports welcome.
- Big-endian targets (e.g. `ath79`) are not built: the vendor driver has never been checked for
  endianness. You can try with `./build-sdk.sh ath79-generic-v<release>`.

## Install from a release

Releases are named `openwrt-<OpenWrt release>` and contain packages per target, prefixed with the
target name (e.g. `x86-64-kmod-aic8800dc-usb-…`). Kernel modules only load on the exact release and
target they were built for, so pick the files that match your router.

Copy the three files for your target to the router, then:

```sh
# OpenWrt 25.12 and later (apk)
apk add --allow-untrusted ./*aic8800*.apk

# OpenWrt 24.10 and earlier (opkg)
opkg install ./*aic8800*.ipk
```

The packages are not signed, hence `--allow-untrusted`. Plug the adapter in (or reboot); after a few
seconds `logread | grep aic8800` should show `switched to Wi-Fi mode` and a new radio appears under
*Network → Wireless*.

A sysupgrade removes packages installed this way; reinstall them for the new release, or build them
into your image.

## Build it yourself

With Docker, using the official SDK image for your release and target:

```sh
./build-sdk.sh x86-64-v25.12.6          # packages end up in ./out
```

In a full OpenWrt build tree or SDK, the repository can be used as a feed (I have not tested this
route myself):

```sh
echo "src-git aic8800dc https://github.com/gorkemgun/openwrt-aic8800dc.git" >> feeds.conf
./scripts/feeds update aic8800dc && ./scripts/feeds install kmod-aic8800dc-usb
```

To put them into an Image Builder image, copy the built packages into the Image Builder's
`packages/` directory and add `kmod-aic8800dc-usb` to `PACKAGES`.

## Mode switch

The adapters first enumerate as a USB mass-storage device holding the Windows driver
(`a69c:5721`–`5727`, `572a`, `572c`, `572f`). `aic8800-usb-modeswitch` waits for usb-storage to
finish scanning, sends a SCSI eject with `usbmode`, and retries after re-configuring the device if
the endpoints stalled. The stick then re-enumerates with its Wi-Fi ID.

If the chip stops answering after a failed firmware start, only unplugging it helps.

## Patches

- `010` detects the cfg80211 6.17 function signatures from the backports header instead of the
  kernel version (OpenWrt pairs an older kernel with a newer cfg80211).
- `020` fixes a deadlock when an interface is added through nl80211, which OpenWrt does on every
  `wifi up`.
- `030` makes `dump_station` work in client and AP mode, which LuCI needs for signal, bitrate and
  the station list.

- `040` lets the build say which cfg80211 version it targets (`AIC_WIRELESS_VERSION_CODE`), for
  the API changes between 6.7 and 6.12. Needed on OpenWrt 24.10 (kernel 6.6, cfg80211 6.12).
- `050` raises the stack-frame warning limit for one debugfs function so 32-bit MIPS targets build.

The first three are submitted upstream
([#48](https://github.com/Kiborgik/aic8800dc-linux-patched/pull/48),
[#49](https://github.com/Kiborgik/aic8800dc-linux-patched/pull/49),
[#50](https://github.com/Kiborgik/aic8800dc-linux-patched/pull/50)) and will be dropped here once merged.

## Why not the ImmortalWrt `aic8800` package

That package builds the radxa driver tree. With its current DC firmware my `3625:0110` stick stops
answering right after the firmware is started and stays dead until it is unplugged.

## License

The packaging in this repository is GPL-2.0-only (see `LICENSE`). The driver and firmware are
downloaded at build time and keep their own license; the patches follow the driver's.
