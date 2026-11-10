#!/bin/sh
# Build the packages with the official OpenWrt SDK Docker image.
#   ./build-sdk.sh <sdk image tag> [output dir]      e.g. ./build-sdk.sh x86-64-v25.12.6
# The SDK tag must match the release (and target) running on the router: kmods are tied to its kernel.
set -eu
TAG="${1:?usage: $0 <sdk image tag, e.g. x86-64-v25.12.6> [output dir]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${2:-$HERE/out}"
OUT="$(cd "${2:-$HERE/out}" && pwd)"
chmod 0777 "$OUT"   # the SDK container writes as uid 1000

docker run --rm -e JOBS="$(nproc)" -v "$HERE/aic8800dc:/src/aic8800dc:ro" -v "$OUT:/out" "openwrt/sdk:$TAG" bash -euc '
	cd /builder
	# Only the base feed is needed (mac80211 for the cfg80211 backport headers, usbmode), at the commit the SDK was built from.
	rev=$(sed -n "s/^src-git --root=package base .*\^\([0-9a-f]*\)$/\1/p" feeds.conf.default)
	[ -n "$rev" ] || { echo "no base feed commit in feeds.conf.default"; exit 1; }
	echo "src-git --root=package base https://github.com/openwrt/openwrt.git^$rev" > feeds.conf
	./scripts/feeds update base >/dev/null
	./scripts/feeds install kmod-cfg80211 usb-modeswitch >/dev/null
	cp -r /src/aic8800dc package/
	PKGS="kmod-aic8800dc-usb aic8800dc-firmware aic8800-usb-modeswitch"
	{ echo "# CONFIG_ALL is not set"; echo "# CONFIG_ALL_KMODS is not set"; echo "# CONFIG_ALL_NONSHARED is not set"
	  echo "# CONFIG_SIGNED_PACKAGES is not set"; for p in $PKGS; do echo "CONFIG_PACKAGE_$p=m"; done; } > .config
	make defconfig >/dev/null 2>&1
	for p in $PKGS; do grep -qx "CONFIG_PACKAGE_$p=m" .config || { echo "could not select $p"; exit 1; }; done
	if ! make package/aic8800dc/compile -j"$JOBS" V=s > /out/build.log 2>&1; then
		grep -E " error:|Error [0-9]" /out/build.log | head -20; echo "see build.log"; exit 1
	fi
	for p in $PKGS; do
		f=$(find bin \( -name "$p-[0-9]*.apk" -o -name "${p}_[0-9]*.ipk" \) | head -1)
		[ -n "$f" ] || { echo "package file not found: $p"; exit 1; }
		cp "$f" /out/
	done
	ls -la /out
'
