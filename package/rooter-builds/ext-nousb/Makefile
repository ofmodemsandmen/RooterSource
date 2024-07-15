#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-nousb
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-nousb
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+luci +ext-rooter-basic +pingtest +ext-blacklist +ext-blockport \
  		+extramenu +ext-domain \
		+luci-app-ddns +ddns-scripts \
		+luci-app-rootervpn +ext-wireguard \
		+webconsole +bwmon +464xlat \
		+iptables-mod-hashlimit \
		+ca-bundle +ca-certificates +libustream-wolfssl \
		+arc-storage \
		+luci-app-sqm +kmod-sched-cake +luci-app-nft-qos \
		+ext-command +ext-speedtest \
		+luci-app-hotspot +openvpn-easy-rsa +openvpn-openssl +luci-app-guestwifi \
		+ext-extra +luci-app-wol \
		+usbmuxd +libusbmuxd-utils +libimobiledevice-utils +kmod-usb-net-ipheth \
		+qlog +luci-ssl +usbutils +openssl-util +ethtool +ext-splashconfig \
		+nano +picocom +wget +qfirehose +ext-simplegps
  TITLE:=ROOter support w/o MWan3 for nowifi
  PKGARCH:=all
endef

define Package/ext-nousb/description
  Helper scripts to enable ROOter support for nowifi
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-nousb))
