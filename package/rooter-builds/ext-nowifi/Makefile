#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-nowifi
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-nowifi
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+luci +ext-rooter-basic +pingtest +ext-blacklist +ext-blockport \
  		+extramenu +ext-domain \
		+luci-app-ddns +ddns-scripts \
		+luci-app-rootervpn +ext-wireguard \
		+webconsole +bwmon +464xlat \
		+iptables-mod-hashlimit \
		+ca-bundle +ca-certificates +libustream-wolfssl \
		+luci-app-ksmbd +usb-storage \
		+ext-p910nd +luci-app-sqm +kmod-sched-cake +luci-app-nft-qos \
		+ext-command +ext-speedtest \
		+openvpn-easy-rsa +openvpn-openssl \
		+ext-extra +luci-app-wol \
		+usbmuxd +libusbmuxd-utils +libimobiledevice-utils +kmod-usb-net-ipheth \
		+qlog +luci-ssl +usbutils +openssl-util +ethtool +ext-splashconfig \
		+nano +picocom +wget +qfirehose
  TITLE:=ROOter support w/o MWan3 for nowifi
  PKGARCH:=all
endef

define Package/ext-nowifi/description
  Helper scripts to enable ROOter support for nowifi
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-nowifi))
