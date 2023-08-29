#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-mesh-master16
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-mesh-master16
  SECTION:=utils
  CATEGORY:=ROOter
  DEPENDS:=+ext-mesh-master \
		+luci-app-mwan3 +luci-app-dnsmasq-ipset
  TITLE:=ROOter support for Mesh Master
  PKGARCH:=all
endef

define Package/ext-mesh-master16/description
  ROOter support for Mesh Master
endef


define Build/Compile
endef

$(eval $(call BuildPackage,ext-mesh-master16))
