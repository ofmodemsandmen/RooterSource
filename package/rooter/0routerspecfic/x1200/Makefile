#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=x1200
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/x1200
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Router Specific
  TITLE:=Install scripts for x1200
  PKGARCH:=all
endef

define Package/x1200/description
  Helper scripts to install scripts for x1200
endef


define Build/Compile
endef

define Package/x1200/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,x1200))
