#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-yamon3
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-yamon3
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Optional Applications
  TITLE:=Install YAMon 3 Bandwidth Monitor
  PKGARCH:=all
endef

define Package/ext-yamon3/description
  Helper scripts to install YAMon 3 Bandwidth Monitor on ROOter
endef


define Build/Compile
endef

define Package/ext-yamon3/install
	$(CP) ./files/* $(1)/


endef

$(eval $(call BuildPackage,ext-yamon3))
