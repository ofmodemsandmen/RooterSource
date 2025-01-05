#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=ext-multimodem
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/ext-multimodem
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Optional Applications
  TITLE:=support for changing max modems
  PKGARCH:=all
endef

define Package/ext-multimodem/description
  Helper scripts to enable changing max modems
endef


define Build/Compile
endef

define Package/ext-multimodem/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,ext-multimodem))
