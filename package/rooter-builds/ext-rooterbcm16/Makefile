#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-rooterbcm16
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-rooterbcm16
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+luci +ext-rooter-basic \
		+luci-app-ddns +ddns-scripts +ddns-scripts_no-ip_com \
		+luci-app-rootervpn +ext-wireguard \
		+webconsole +bwmon +464xlat \
		+ext-theme +luci-theme-argon +argon-config \
		+luci-theme-tomato +ext-login \
		+ca-bundle +ca-certificates +libustream-openssl \
		+luci-app-ksmbd +usb-storage \
		+ext-p910nd +luci-app-sqm +kmod-sched-cake +luci-app-nft-qos \
		+ext-command +ext-speedtest +luci-app-guestwifi \
		+openvpn-easy-rsa +openvpn-openssl \
		+ext-extra +luci-app-wol \
		+usbmuxd +libusbmuxd-utils +libimobiledevice-utils +kmod-usb-net-ipheth \
		+nano +picocom +wpad +wget +qfirehose +luci-app-vpnbypass 
  TITLE:=ROOter support for 16meg and larger Broadcom routers w/o Hotspot Manager or MWan3
  PKGARCH:=all
endef

define Package/ext-rooterbcm16/description
  Helper scripts to enable ROOter on 16meg and larger Broadcom routers w/o Hotspot Manager or MWan3
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-rooterbcm16))
