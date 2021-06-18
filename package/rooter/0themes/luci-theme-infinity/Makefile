#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-infinity
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-infinity
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Themes
  TITLE:=Install scripts for Infinity theme
  PKGARCH:=all
endef

define Package/luci-theme-infinity/description
  Helper scripts to install scripts for Infinity theme
endef


define Build/Compile
endef

define Package/luci-theme-infinity/install
	$(CP) ./files/* $(1)/


endef

$(eval $(call BuildPackage,luci-theme-infinity))
