#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=mofi5500
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/mofi5500
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Router Specific
  TITLE:=Install scripts for MOFI 5500
  PKGARCH:=all
endef

define Package/mofi5500/description
  Helper scripts to install scripts for MOFI 5500
endef


define Build/Compile
endef

define Package/mofi5500/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,mofi5500))
