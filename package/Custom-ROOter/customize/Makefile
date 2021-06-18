#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=customize
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/customize
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Custom Apps
  TITLE:=Added scripts for custom changes
  PKGARCH:=all
endef

define Package/customize/description
  Added scripts for custom changes
endef


define Build/Compile
endef

define Package/customize/install
	$(CP) ./files/* $(1)/


endef

$(eval $(call BuildPackage,customize))
