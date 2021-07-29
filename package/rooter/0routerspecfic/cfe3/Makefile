#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=cfe3
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/cfe3
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Router Specific
  TITLE:=Install scripts for CF-E3
  PKGARCH:=all
endef

define Package/cfe3/description
  Helper scripts to install scripts for CF-E3
endef


define Build/Compile
endef

define Package/cfe3/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,cfe3))
