#Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=rpi3bp
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/rpi3bp
  SECTION:=utils
  CATEGORY:=ROOter
  SUBMENU:=Router Specific
  DEPENDS:=+kmod-brcmfmac
  TITLE:=Install scripts for RPI 3B+
  PKGARCH:=all
endef

define Package/rpi3bp/description
  Helper scripts to install scripts for RPI 3B+
endef


define Build/Compile
endef

$(eval $(call BuildPackage,rpi3bp))
