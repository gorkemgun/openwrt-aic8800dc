# SPDX-License-Identifier: GPL-2.0-only
#
# AIC8800DC/DW USB Wi-Fi (TP-Link / Tenda / Mercusys "AX300" sticks) for OpenWrt.
# Driver source: https://github.com/Kiborgik/aic8800dc-linux-patched (pinned commit).

include $(TOPDIR)/rules.mk

PKG_NAME:=aic8800dc
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/Kiborgik/aic8800dc-linux-patched.git
PKG_SOURCE_DATE:=2026-11-06
PKG_SOURCE_VERSION:=127000a6f355286a4a7fb301e916413baf69356f
PKG_MIRROR_HASH:=27b9ff003b005421d2b2d9391974c07f43d0d7413e7fd69c61786fa03571fdff

PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define Package/aic8800dc-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=AIC8800DC/DW USB Wi-Fi firmware and per-vendor userconfig
endef

define Package/aic8800dc-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/aic8800DC
	$(CP) $(PKG_BUILD_DIR)/fw/aic8800DC/* $(1)/lib/firmware/aic8800DC/
endef

define KernelPackage/aic8800dc-usb
  SUBMENU:=Wireless Drivers
  TITLE:=AIC8800DC/DW USB Wi-Fi (TP-Link/Tenda/Mercusys AX300)
  DEPENDS:=+kmod-cfg80211 +kmod-usb-core +aic8800dc-firmware +aic8800-usb-modeswitch \
    +@DRIVER_11N_SUPPORT +@DRIVER_11AC_SUPPORT +@DRIVER_11AX_SUPPORT
  FILES:= \
	$(PKG_BUILD_DIR)/drivers/aic8800/aic_load_fw/aic_load_fw.ko \
	$(PKG_BUILD_DIR)/drivers/aic8800/aic8800_fdrv/aic8800_fdrv.ko
  AUTOLOAD:=$(call AutoProbe,aic_load_fw aic8800_fdrv)
endef

# The sticks enumerate as a driver CD (usb-storage) first; this ejects it.
define Package/aic8800-usb-modeswitch
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Switch AIC8800 USB adapters from storage (a69c:572x) to Wi-Fi mode
  DEPENDS:=+usb-modeswitch
  PKGARCH:=all
endef

define Package/aic8800-usb-modeswitch/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/usb $(1)/usr/share/aic8800
	$(INSTALL_DATA) ./files/aic8800-usb-mode.json $(1)/usr/share/aic8800/usb-mode.json
	$(INSTALL_DATA) ./files/aic8800-usb-mode.hotplug $(1)/etc/hotplug.d/usb/21-aic8800-mode
endef

NOSTDINC_FLAGS:= \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR) \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-include backport/autoconf.h \
	-include backport/backport.h \
	-DBUILD_OPENWRT

# cfg80211 comes from the mac80211 (backports) package and is newer than the kernel, so tell the
# driver which wireless API version it is built against (patch 040). Encoded like KERNEL_VERSION().
MAC80211_MAKEFILE:=$(firstword $(wildcard $(TOPDIR)/package/kernel/mac80211/Makefile $(TOPDIR)/package/feeds/*/mac80211/Makefile))
MAC80211_VER:=$(if $(MAC80211_MAKEFILE),$(shell sed -n 's/^PKG_VERSION:=\([0-9]*\)\.\([0-9]*\).*/\1 \2/p' $(MAC80211_MAKEFILE)))
WIRELESS_VERSION_CODE:=$(if $(word 2,$(MAC80211_VER)),$(shell echo $$(( $(word 1,$(MAC80211_VER)) * 65536 + $(word 2,$(MAC80211_VER)) * 256 ))),LINUX_VERSION_CODE)

# CFG80211_HDR: the driver Makefile probes cfg80211.h for API changes. OpenWrt's
# cfg80211 comes from backports, so point it at that header, not the kernel's.
define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) \
		M="$(PKG_BUILD_DIR)/drivers/aic8800" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		CFG80211_HDR="$(STAGING_DIR)/usr/include/mac80211/net/cfg80211.h" \
		AIC_WIRELESS_VERSION_CODE="$(WIRELESS_VERSION_CODE)" \
		modules
endef

$(eval $(call BuildPackage,aic8800dc-firmware))
$(eval $(call BuildPackage,aic8800-usb-modeswitch))
$(eval $(call KernelPackage,aic8800dc-usb))
