#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-huasifei16
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-huasifei16
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+luci +ext-rooter-basic +pingtest +ext-blacklist +ext-blockport \
  		+extramenu +bwallocate +ext-domain +ext-zerotier \
  		+luci-app-mwan3 +luci-app-dnsmasq-ipset \
		+luci-app-ddns +ddns-scripts \
		+luci-app-rootervpn +ext-wireguard \
		+webconsole +bwmon +464xlat \
		+iptables-mod-hashlimit \
		+ca-bundle +ca-certificates \
		+luci-app-ksmbd +usb-storage \
		+ext-p910nd +kmod-sched-cake +luci-app-nft-qos \
		+ext-command +ext-speedtest +luci-app-guestwifi \
		+openvpn-easy-rsa +openvpn-openssl \
		+ext-extra +luci-app-hotspot +luci-app-wol \
		+usbmuxd +libusbmuxd-utils +libimobiledevice-utils +kmod-usb-net-ipheth \
		+qlog +luci-ssl +usbutils +openssl-util +irqbalance +ext-splashconfig \
		+nano +picocom +wpad +wget +qfirehose  +ext-simplegps +ext-multimodem
  TITLE:=ROOter support w/o MWan3 for Huasifei
  PKGARCH:=all
endef

define Package/ext-huasifei16/description
  Helper scripts to enable ROOter support for Huasifei
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-huasifei16))
