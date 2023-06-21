#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=h721
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/wififix
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Router Specific
  TITLE:=Install scripts for addon Wifi
  PKGARCH:=all
endef

define Package/wififix/description
  Helper scripts to install scripts for addon Wifi
endef


define Build/Compile
endef

define Package/wififix/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,wififix))
