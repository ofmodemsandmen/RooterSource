#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-mesh-node
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-mesh-node
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+luci +ext-logo \
		+webconsole \
		+ca-bundle +ca-certificates \
		+luci-ssl +usbutils +openssl-util +irqbalance \
		+nano +picocom +wpad-mesh-openssl +wget
  TITLE:=ROOter support for Mesh Master
  PKGARCH:=all
endef

define Package/ext-mesh-node/description
  ROOter support for Mesh Master
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-mesh-node))
