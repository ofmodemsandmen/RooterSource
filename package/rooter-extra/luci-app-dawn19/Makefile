 #Owned by DairyMan@Whirlpool
#
#Copyright GNU act.
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dawn19
PKG_VERSION:=1.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Created by DM/makefile by Cobia@whirlpool
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-dawn19
  SECTION:=luci
  CATEGORY:=LuCI
  DEPENDS:=+dawn19 +luci-compat +luci-lib-json
  SUBMENU:=3. Applications
  TITLE:=support for Dawn
  PKGARCH:=all
endef

define Package/luci-app-dawn19/description
  Helper scripts to enable Dawn
endef


define Build/Compile
endef

define Package/luci-app-dawn19/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,luci-app-dawn19))
