#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-rooter16
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-rooter16
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+ext-rooter-lite \
		+luci-app-mwan3 +luci-app-dnsmasq-ipset +ext-multimodem 
  TITLE:=ROOter support for 16meg and larger routers with MWan3
  PKGARCH:=all
endef

define Package/ext-rooter16/description
  Helper scripts to enable ROOter on 16meg and larger routers with MWan3
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-rooter16))
